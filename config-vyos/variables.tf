variable "vyos_management_ip" {
  type = string
}

variable "vyos_api_key" {
  type      = string
  sensitive = true
}

variable "vyos_lan_cidr" {
  type    = string
  default = "192.168.10.1/24"
}

variable "vyos_bgp_lb_cidr" {
  type    = string
  default = "192.168.20.1/24"
}

variable "vyos_wan_static_ip" {
  type    = string
  default = null
}

variable "vyos_wan_gateway" {
  type    = string
  default = null
}


variable "enable_tailscale" {
  type    = bool
  default = false
}

variable "tailscale_auth_key" {
  type      = string
  sensitive = true
  default   = null
}

variable "tailscale_routes" {
  description = "Comma-separated list of CIDRs to advertise via Tailscale exit node"
  type        = string
  default     = "192.168.10.0/24"
}

variable "enable_bgp" {
  description = "Enable BGP on VyOS for MetalLB"
  type        = bool
  default     = false
}

variable "vyos_asn" {
  description = "Autonomous System Number for VyOS"
  type        = number
  default     = 64512
}

variable "metallb_asn" {
  description = "Autonomous System Number for MetalLB"
  type        = number
  default     = 64513
}

variable "metallb_peer_subnet" {
  description = "The subnet containing the MetalLB BGP peers (e.g., the Kubernetes Node LAN network)"
  type        = string
  default     = "192.168.10.0/24"
}

# -----------------------------------------------------------------------------
// WireGuard tunnel pro Scaleway edge (yes365 mail).
// On-prem é initiator (NAT traversal via persistent_keepalive).
# -----------------------------------------------------------------------------

variable "enable_scaleway_wg" {
  description = "Ativar WG tunnel pro Scaleway edge"
  type        = bool
  default     = false
}

variable "scaleway_wg_interface" {
  description = "Nome da interface WG"
  type        = string
  default     = "wg-scaleway"
}

variable "scaleway_wg_port" {
  description = "Porta UDP WG"
  type        = number
  default     = 51820
}

variable "scaleway_wg_private_key" {
  description = "Private key do on-prem (sensitive)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "scaleway_wg_public_key" {
  description = "Public key do peer Scaleway"
  type        = string
  default     = ""
}

variable "scaleway_wg_endpoint_ip" {
  description = "IP público do VyOS Scaleway (listener)"
  type        = string
  default     = ""
}

variable "scaleway_wg_tunnel_ip" {
  description = "IP do Scaleway no tunnel WG"
  type        = string
  default     = "10.200.255.1"
}

variable "scaleway_wg_onprem_tunnel_ip" {
  description = "IP do on-prem no tunnel WG"
  type        = string
  default     = "10.200.255.2"
}
