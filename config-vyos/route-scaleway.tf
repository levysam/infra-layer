// =============================================================================
// Static route — peer Scaleway via WG tunnel
// =============================================================================
// VyOS NÃO cria rota implícita pelo allowed_ips no peer (diferente de
// wg-quick). Sem isso, ping/traceroute pra 10.200.255.1 cai no default
// gateway (eth1) e nunca volta. Esta rota força o tráfego pelo wg1.

resource "vyos_protocols_static_route" "scaleway_peer" {
  count = var.enable_scaleway_wg ? 1 : 0

  identifier = {
    route = "${var.scaleway_wg_tunnel_ip}/32"
  }

  description = "scaleway-wg-peer"
}

resource "vyos_protocols_static_route_interface" "scaleway_peer" {
  count = var.enable_scaleway_wg ? 1 : 0

  identifier = {
    route     = "${var.scaleway_wg_tunnel_ip}/32"
    interface = var.scaleway_wg_interface
  }

  depends_on = [vyos_protocols_static_route.scaleway_peer]
}
