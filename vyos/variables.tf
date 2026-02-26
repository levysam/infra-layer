variable "proxmox_node" {
  type = string
}

variable "vmid" {
  type = number
}

variable "name" {
  type    = string
  default = "vyos-router"
}

variable "memory" {
  type    = number
  default = 2048
}

variable "cores" {
  type    = number
  default = 2
}

variable "storage_id" {
  type = string
}

variable "disk_size" {
  type    = number
  default = 10
}

variable "iso_path" {
  type        = string
  description = "Path to VyOS ISO"
}

variable "lan_bridge" {
  type        = string
  description = "Bridge for LAN (e.g. vmbr1)"
}

variable "bootstrap_snippet_id" {
  type        = string
  description = "ID of the Cloud-Init snippet for bootstrapping"
  default     = null
}

variable "lan_cidr" {
  type        = string
  default     = "192.168.10.1/24"
  description = "CIDR for the internal LAN network"
}


variable "vyos_management_ip" {
  type        = string
  description = "Management IP for VyOS API calls"
}

variable "use_pci_passthrough" {
  type        = bool
  default     = false
  description = "Toggle between PCI Passthrough and Bridge for WAN"
}

variable "wan_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Bridge for WAN (used if use_pci_passthrough is false)"
}

variable "pci_passthrough_id" {
  type        = string
  default     = null
  description = "PCI ID for WAN passthrough (used if use_pci_passthrough is true)"
}

