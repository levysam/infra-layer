variable "dns_records" {
  description = "Map of DNS names to lists of IP addresses for static entries"
  type        = map(list(string))
  default     = {}
}

variable "local_asn" {
  description = "Local ASN for BGP"
  type        = string
  default     = "65000"
}

variable "bgp_peers" {
  description = "Map of BGP peers configuration"
  type = map(object({
    remote_address = string
    remote_asn     = string
  }))
  default = {}
}

variable "wan_interface" {
  description = "WAN interface name (e.g. ether1)"
  type        = string
  default     = "ether1"
}

variable "bgp_asn_router" {
  description = "Router ASN - alternative to local_asn if preferred"
  type        = number
  default     = null
}
