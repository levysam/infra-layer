# Base BGP Configuration
resource "vyos_protocols_bgp" "metallb_bgp" {
  count = var.enable_bgp ? 1 : 0

  system_as = var.vyos_asn
}

# Peer Group for MetalLB (Kubernetes Nodes) with Address Families
resource "vyos_protocols_bgp_peer_group" "metallb_group" {
  count = var.enable_bgp ? 1 : 0

  identifier = {
    peer_group = "METALLB"
  }
  remote_as = var.metallb_asn

  address_family = {
    ipv4_unicast = {}
    ipv6_unicast = {}
  }

  depends_on = [vyos_protocols_bgp.metallb_bgp]
}

# Dynamic Listening Range (Any node in the subnet can establish a session)
resource "vyos_protocols_bgp_listen_range" "metallb_subnet" {
  count = var.enable_bgp ? 1 : 0

  identifier = {
    range = var.metallb_peer_subnet
  }

  peer_group = vyos_protocols_bgp_peer_group.metallb_group[0].identifier.peer_group

  depends_on = [vyos_protocols_bgp_peer_group.metallb_group]
}
