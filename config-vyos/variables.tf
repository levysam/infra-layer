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

variable "vyos_wan_static_ip" {
  type    = string
  default = null
}

variable "vyos_wan_gateway" {
  type    = string
  default = null
}


variable "wan_interface" {
  default = "starlink"
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
