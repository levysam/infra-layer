terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.70.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  username = var.proxmox_user
  password = var.proxmox_password
  insecure = true

  ssh {
    agent    = true
    password = var.proxmox_password
    node {
      name    = var.proxmox_node
      address = var.proxmox_ssh_address
    }
  }
}

resource "proxmox_virtual_environment_file" "vyos_bootstrap" {
  node_name    = var.proxmox_node
  datastore_id = var.proxmox_snippet_datastore
  content_type = "snippets"

  source_raw {
    data      = <<EOF
write_files:
  - path: /config/scripts/prep-tailscale.sh
    owner: root:vyattacfg
    permissions: '0755'
    content: |
      source /opt/vyatta/etc/functions/script-template
      mkdir -p /config/tailscale
      if ! run show container image | grep -q "tailscale/tailscale"; then
        run add container image tailscale/tailscale:latest
      fi
vyos_config_commands:
  - set service monitoring qemu-guest-agent
  - set service ntp server 0.pool.ntp.org
  - set service monitoring qemu-guest-agent
  - set service ntp server 0.pool.ntp.org
  - set service https api keys id terraform key 'jhab'
  - set service https api
  - set interfaces ethernet eth0 address fd00:10::1/64
  - set service dhcpv6-server shared-network-name LAN_IPv6 subnet fd00:10::/64 address-range start fd00:10::100 stop fd00:10::200
  - set service dhcpv6-server shared-network-name LAN_IPv6 subnet fd00:10::/64 name-server 2606:4700:4700::1111
  - set service router-advert interface eth0 prefix fd00:10::/64
  - set service router-advert interface eth0 managed-flag
  - set service router-advert interface eth0 other-config-flag
  - set system login user vyos authentication public-keys levy type ssh-rsa
  - set system login user vyos authentication public-keys levy key '${split(" ", var.proxmox_ssh_public_key)[1]}'
EOF
    file_name = "vyos-bootstrap.yaml"
  }
}

resource "proxmox_virtual_environment_file" "vyos_image" {
  node_name    = var.proxmox_node
  datastore_id = var.proxmox_iso_datastore
  content_type = "iso"

  source_file {
    path = var.vyos_iso_path
  }

  lifecycle {
    ignore_changes = [
      source_file,
      overwrite
    ]
  }
}

resource "proxmox_virtual_environment_file" "talos_image" {
  node_name    = var.proxmox_node
  datastore_id = var.proxmox_iso_datastore
  content_type = "iso"

  source_file {
    path = var.talos_image_local_path
  }

  lifecycle {
    ignore_changes = [
      source_file,
      overwrite
    ]
  }
}

locals {
  cp_config_docs     = split("---", file(var.talos_cp_config_local_path))
  worker_config_docs = split("---", file(var.talos_worker_config_local_path))

  # Final YAML for each node (using raw file content to avoid corruption)
  node_yaml = {
    for name, node in var.talos_nodes : name => replace(
      replace(
        replace(
          node.is_control ? local.cp_config_docs[0] : local.worker_config_docs[0],
          "$${REGION}", var.proxmox_region
        ),
        "$${ZONE}", var.proxmox_node
      ),
      "$${HOSTNAME}", name
    )
  }

  final_node_yaml = {
    for name, node in var.talos_nodes : name => var.enable_proxmox_csi && node.is_control ? replace(
      local.node_yaml[name],
      "    inlineManifests: []",
      "    inlineManifests:\n${local.proxmox_csi_secret_manifest}"
    ) : local.node_yaml[name]
  }
}

resource "proxmox_virtual_environment_file" "talos_node_config" {
  for_each = var.talos_nodes

  node_name    = var.proxmox_node
  datastore_id = var.proxmox_snippet_datastore
  content_type = "snippets"

  source_raw {
    file_name = "talos-${each.key}-config.yaml"
    data      = local.final_node_yaml[each.key]
  }
}

resource "proxmox_virtual_environment_network_linux_bridge" "lan_bridge" {
  node_name = var.proxmox_node
  name      = var.proxmox_lan_bridge
  comment   = "LAN bridge for VyOS and Talos"
}

module "talos_nodes" {
  source = "../proxmox"
  providers = {
    proxmox = proxmox
  }

  nodes = {
    for name, node in var.talos_nodes : name => merge(node, {
      config_id = proxmox_virtual_environment_file.talos_node_config[name].id
    })
  }

  proxmox_node          = var.proxmox_node
  proxmox_vm_datastore  = var.proxmox_vm_datastore
  proxmox_scsi_hardware = var.proxmox_scsi_hardware
  template_name         = var.talos_template_name
  image_file_id         = proxmox_virtual_environment_file.talos_image.id
  gateway               = var.vyos_management_ip
  network_bridge        = proxmox_virtual_environment_network_linux_bridge.lan_bridge.name

  depends_on = [proxmox_virtual_environment_network_linux_bridge.lan_bridge]
}

module "vyos_router" {
  source = "../vyos"
  providers = {
    proxmox = proxmox
  }

  proxmox_node          = var.proxmox_node
  proxmox_scsi_hardware = var.proxmox_scsi_hardware
  vmid                  = 1000
  name                  = "vyos-router"
  storage_id            = var.vyos_storage_id
  disk_size             = var.vyos_disk_size
  iso_path              = proxmox_virtual_environment_file.vyos_image.id
  lan_bridge            = proxmox_virtual_environment_network_linux_bridge.lan_bridge.name
  wan_bridge            = var.proxmox_wan_bridge
  use_pci_passthrough   = var.vyos_use_pci_passthrough
  pci_passthrough_id    = var.vyos_pci_passthrough_id
  vyos_management_ip    = var.vyos_management_ip
  lan_cidr              = var.vyos_lan_cidr
  bootstrap_snippet_id  = proxmox_virtual_environment_file.vyos_bootstrap.id

  depends_on = [proxmox_virtual_environment_network_linux_bridge.lan_bridge, proxmox_virtual_environment_file.vyos_bootstrap]
}

output "vyos_ip" {
  value = module.vyos_router.vyos_ip
}
