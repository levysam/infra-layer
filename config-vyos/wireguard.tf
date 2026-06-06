// =============================================================================
// WireGuard tunnel — On-prem VyOS ↔ Scaleway edge
// =============================================================================
// On-prem é INITIATOR (atrás de NAT do MikroTik). Scaleway é LISTENER em
// 51.158.98.55:51820 com SG já liberando UDP/51820 inbound.
// persistent_keepalive de 25s mantém a sessão aberta pelo NAT.
//
// Caminho: tráfego inbound mail.yes365.au -> 51.15.142.204:25 chega no
// Scaleway, DNAT pra 192.168.20.59:25, sai pelo wg0 com next-hop 10.200.255.2
// (este peer), entra aqui via wg-scaleway, segue pela rota BGP do Cilium
// pro pod Stalwart no Talos navride.

resource "vyos_interfaces_wireguard" "scaleway" {
  count = var.enable_scaleway_wg ? 1 : 0

  identifier = {
    wireguard = var.scaleway_wg_interface
  }

  description = "WG tunnel to Scaleway edge (yes365 mail)"
  address     = ["${var.scaleway_wg_onprem_tunnel_ip}/32"]
  # Porta local (initiator) — 51820 está em uso pelo Tailscale aqui, usa 51821.
  port        = var.scaleway_wg_local_port
  private_key = var.scaleway_wg_private_key
}

resource "vyos_interfaces_wireguard_peer" "scaleway" {
  count = var.enable_scaleway_wg ? 1 : 0

  identifier = {
    wireguard = var.scaleway_wg_interface
    peer      = "scaleway"
  }

  public_key = var.scaleway_wg_public_key
  address    = var.scaleway_wg_endpoint_ip
  port       = var.scaleway_wg_port

  allowed_ips = ["${var.scaleway_wg_tunnel_ip}/32"]

  persistent_keepalive = 25

  depends_on = [vyos_interfaces_wireguard.scaleway]
}
