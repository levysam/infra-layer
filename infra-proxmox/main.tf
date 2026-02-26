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
  datastore_id = "local"
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
EOF
    file_name = "vyos-bootstrap.yaml"
  }
}

resource "proxmox_virtual_environment_file" "vyos_image" {
  node_name    = var.proxmox_node
  datastore_id = "local"
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
  datastore_id = "local"
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

resource "proxmox_virtual_environment_file" "talos_cp_config" {
  node_name    = var.proxmox_node
  datastore_id = "local"
  content_type = "snippets"

  source_raw {
    file_name = "talos-cp-config.yaml"
    data      = var.enable_proxmox_csi ? replace(file(var.talos_cp_config_local_path), "    inlineManifests: []", "    inlineManifests:\n${local.proxmox_csi_secret_manifest}") : file(var.talos_cp_config_local_path)
  }
}

resource "proxmox_virtual_environment_file" "talos_worker_config" {
  node_name    = var.proxmox_node
  datastore_id = "local"
  content_type = "snippets"

  source_file {
    path = var.talos_worker_config_local_path
  }
}

resource "proxmox_virtual_environment_network_linux_bridge" "vmbr1" {
  node_name = var.proxmox_node
  name      = "vmbr1"
  comment   = "LAN bridge for VyOS and Talos"
}

module "talos_nodes" {
  source = "../proxmox"
  providers = {
    proxmox = proxmox
  }

  nodes            = var.talos_nodes
  proxmox_node     = var.proxmox_node
  template_name    = "talos-template"
  image_file_id    = proxmox_virtual_environment_file.talos_image.id
  cp_config_id     = proxmox_virtual_environment_file.talos_cp_config.id
  worker_config_id = proxmox_virtual_environment_file.talos_worker_config.id
  gateway          = var.vyos_management_ip
  network_bridge   = proxmox_virtual_environment_network_linux_bridge.vmbr1.name

  depends_on = [proxmox_virtual_environment_network_linux_bridge.vmbr1]
}

module "vyos_router" {
  source = "../vyos"
  providers = {
    proxmox = proxmox
  }

  proxmox_node         = var.proxmox_node
  vmid                 = 1000
  name                 = "vyos-router"
  storage_id           = var.vyos_storage_id
  disk_size            = var.vyos_disk_size
  iso_path             = proxmox_virtual_environment_file.vyos_image.id
  lan_bridge           = proxmox_virtual_environment_network_linux_bridge.vmbr1.name
  use_pci_passthrough  = var.vyos_use_pci_passthrough
  pci_passthrough_id   = var.vyos_pci_passthrough_id
  vyos_management_ip   = var.vyos_management_ip
  lan_cidr             = var.vyos_lan_cidr
  bootstrap_snippet_id = proxmox_virtual_environment_file.vyos_bootstrap.id

  depends_on = [proxmox_virtual_environment_network_linux_bridge.vmbr1, proxmox_virtual_environment_file.vyos_bootstrap]
}

output "vyos_ip" {
  value = module.vyos_router.vyos_ip
}
