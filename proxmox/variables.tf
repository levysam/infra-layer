variable "nodes" {
  description = "Map of Talos nodes configuration"
  type = map(object({
    cores      = number
    vmid       = number
    ram        = number
    disk_size  = number
    storage_id = string
    is_control = bool
    ip_address = optional(string)
    config_id  = string
  }))
}

variable "proxmox_node" {
  type = string
}

variable "template_name" {
  type    = string
  default = "talos-template"
}

variable "image_file_id" {
  type        = string
  description = "Talos image file ID (e.g. from proxmox_virtual_environment_file)"
}

variable "gateway" {
  type        = string
  description = "Default gateway for the nodes"
}

variable "network_bridge" {
  type    = string
  default = "vmbr1"
}

variable "proxmox_scsi_hardware" {
  type    = string
  default = "virtio-scsi-single"
}

variable "proxmox_vm_datastore" {
  type    = string
  default = "local"
}

