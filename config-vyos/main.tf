terraform {
  required_providers {
    vyos = {
      source = "thomasfinstad/vyos-rolling"
    }
  }
}

provider "vyos" {
  endpoint = "https://${var.vyos_management_ip}"
  api_key  = var.vyos_api_key
  certificate = {
    disable_verify = true
  }
  overwrite_existing_resources_on_create = true
}


resource "vyos_interfaces_ethernet" "lan" {
  identifier = {
    ethernet = "eth0"
  }
  address     = [var.vyos_lan_cidr]
  description = "Internal LAN for Talos Nodes"
}

resource "vyos_interfaces_ethernet" "wan" {
  identifier = {
    ethernet = "eth1"
  }
  description = "External WAN"
  address     = var.vyos_wan_static_ip != null ? [var.vyos_wan_static_ip, "dhcpv6"] : ["dhcp", "dhcpv6"]
}

resource "vyos_nat_source_rule" "masquerade" {
  identifier = {
    rule = 100
  }
  source = {
    address = "${join(".", slice(split(".", var.vyos_lan_cidr), 0, 3))}.0/24"
  }
  outbound_interface = {
    name = "eth1"
  }
  translation = {
    address = "masquerade"
  }
}

resource "vyos_protocols_static_route" "default_ipv4" {
  count = var.vyos_wan_gateway != null ? 1 : 0
  identifier = {
    route = "0.0.0.0/0"
  }
}

resource "vyos_protocols_static_route_next_hop" "default_gw" {
  count = var.vyos_wan_gateway != null ? 1 : 0
  identifier = {
    route    = "0.0.0.0/0"
    next_hop = var.vyos_wan_gateway
  }
  depends_on = [vyos_protocols_static_route.default_ipv4]
}

resource "vyos_system" "base" {
  count       = var.vyos_wan_gateway != null ? 1 : 0
  name_server = ["1.1.1.1", "8.8.8.8"]
}

resource "vyos_service_dhcp_server" "dhcp" {
  listen_interface = ["eth0"]
  depends_on       = [vyos_service_dhcp_server_shared_network_name.lan]
}

resource "vyos_service_dhcp_server_shared_network_name" "lan" {
  identifier = {
    shared_network_name = "LAN_POOL"
  }
  subnet = {
    "${join(".", slice(split(".", var.vyos_lan_cidr), 0, 3))}.0/24" = {
      subnet_id = 1
      option = {
        default_router = split("/", var.vyos_lan_cidr)[0]
        name_server    = ["1.1.1.1", "8.8.8.8"]
      }
      range = {
        "0" = {
          start = "${join(".", slice(split(".", var.vyos_lan_cidr), 0, 3))}.100"
          stop  = "${join(".", slice(split(".", var.vyos_lan_cidr), 0, 3))}.200"
        }
      }
    }
  }
}


resource "vyos_service_router_advert_interface" "lan_ra" {
  identifier = {
    interface = "eth0"
  }
  managed_flag      = false
  other_config_flag = true
  name_server       = ["2606:4700:4700::1111", "2001:4860:4860::8888"]
}
resource "vyos_container_network" "tailscale" {
  count = var.enable_tailscale ? 1 : 0
  identifier = {
    network = "tailscale"
  }
  prefix = ["10.255.0.0/24"]
}

resource "null_resource" "tailscale_prep" {
  count = var.enable_tailscale ? 1 : 0

  connection {
    type     = "ssh"
    user     = "vyos"
    password = "vyos" # Default VyOS password
    host     = var.vyos_management_ip
  }

  provisioner "file" {
    source      = "${path.module}/tailscale-pull.sh"
    destination = "/tmp/tailscale-pull.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/tailscale-pull.sh",
      "/tmp/tailscale-pull.sh"
    ]
  }

  depends_on = [vyos_container_network.tailscale]
}


resource "vyos_container_name" "tailscale" {
  count = var.enable_tailscale ? 1 : 0
  identifier = {
    name = "tailscale"
  }
  image = "tailscale/tailscale:latest"
  network = {
    "tailscale" = {}
  }
  capability = ["net-admin", "net-raw"]
  restart    = "always"
  depends_on = [null_resource.tailscale_prep]
}

resource "vyos_container_name_device" "tailscale_tun" {
  count = var.enable_tailscale ? 1 : 0
  identifier = {
    name   = "tailscale"
    device = "tun"
  }
  source      = "/dev/net/tun"
  destination = "/dev/net/tun"
  depends_on  = [vyos_container_name.tailscale]
}

resource "vyos_container_name_environment" "tailscale_env" {
  for_each = var.enable_tailscale ? {
    "TS_AUTHKEY"    = var.tailscale_auth_key
    "TS_ROUTES"     = var.tailscale_routes
    "TS_STATE_DIR"  = "/var/lib/tailscale"
    "TS_USERSPACE"  = "false"
    "TS_EXTRA_ARGS" = "--advertise-exit-node"
  } : {}
  identifier = {
    name        = "tailscale"
    environment = each.key
  }
  value      = each.value
  depends_on = [vyos_container_name.tailscale]
}

resource "vyos_container_name_volume" "tailscale_volumes" {
  for_each = var.enable_tailscale ? {
    "state" = {
      source      = "/config/tailscale"
      destination = "/var/lib/tailscale"
    }
  } : {}
  identifier = {
    name   = "tailscale"
    volume = each.key
  }
  source      = each.value.source
  destination = each.value.destination
  depends_on  = [vyos_container_name.tailscale]
}
