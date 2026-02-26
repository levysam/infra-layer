variable "proxmox_api_url" {}
variable "proxmox_user" {}
variable "proxmox_password" {}
variable "proxmox_node" {}
variable "proxmox_ssh_address" {}

variable "proxmox_csi_api_url" {
  type        = string
  description = "Specific API URL to use for the CSI plugin if different from proxmox_api_url"
  default     = null
}

variable "vyos_storage_id" {
  type = string
}

variable "vyos_disk_size" {
  type    = number
  default = 10
}

variable "vyos_iso_path" {
  type = string
}

variable "vyos_management_ip" {
  type = string
}

variable "vyos_lan_cidr" {
  type    = string
  default = "192.168.10.1/24"
}

variable "vyos_use_pci_passthrough" {
  type    = bool
  default = false
}

variable "vyos_pci_passthrough_id" {
  type    = string
  default = null
}

variable "vyos_api_key" {
  type      = string
  sensitive = true
}

variable "talos_nodes" {
  type = map(object({
    cores      = number
    vmid       = number
    ram        = number
    disk_size  = number
    storage_id = string
    is_control = bool
    ip_address = optional(string)
  }))
}

variable "talos_image_local_path" {
  type        = string
  description = "Local path to the Talos ISO/Image"
}

variable "talos_cp_config_local_path" {
  type        = string
  description = "Local path to the Talos controlplane.yaml"
}

variable "talos_worker_config_local_path" {
  type        = string
  description = "Local path to the Talos worker.yaml"
}

variable "talos_controlplane_dns_name" {
  default = "controlplane.local"
}

variable "enable_proxmox_csi" {
  type    = bool
  default = false
}
