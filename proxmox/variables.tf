variable "nodes" {
  description = "Map of nodes to create, with their specific configurations"
  type = map(object({
    vmid       = number
    ram        = number
    disk_size  = number
    storage_id = string
    is_control = bool
    cores      = optional(number, 2)
    ip_address = optional(string)
  }))
}

variable "proxmox_node" {
  description = "The Proxmox node to deploy VMs on"
  type        = string
}

variable "template_name" {
  description = "Name of the VM template to clone"
  type        = string
}

variable "network_bridge" {
  description = "Network bridge interface"
  type        = string
  default     = "vmbr0"
}

variable "gateway" {
  description = "Network gateway"
  type        = string
}

variable "os_iso" {
  description = "Path to the OS ISO image (e.g. local:iso/talos.iso)"
  type        = string
  default     = null
}

variable "seed_1" {
  description = "Path to the first seed ISO image"
  type        = string
  default     = null
}

variable "seed_2" {
  description = "Path to the second seed ISO image"
  type        = string
  default     = null
}

# Calculated IPs provided by root module or assumed logic? 
# For this refactor, we will allow defining IP in the map OR keep the simple logic if possible.
# But 'is_control' suggests we might want static IPs. 
# Let's add 'ip' to the map for maximum control as requested.
variable "ip_base" {
  description = "Network prefix (e.g. 192.168.10.) used if ip is not provided (simple increment)"
  type        = string
  default     = "192.168.10."
}
