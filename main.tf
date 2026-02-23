terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
    routeros = {
      source  = "terraform-routeros/routeros"
      version = "1.62.0"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
}

provider "routeros" {
  hosturl  = var.routeros_hosturl
  username = var.routeros_username
  password = var.routeros_password
  insecure = true
}

module "talos_nodes" {
  source = "./proxmox"

  nodes          = var.talos_nodes
  proxmox_node   = var.proxmox_node
  template_name  = "talos-template"
  os_iso         = var.talos_os_iso
  seed_1         = var.talos_seed_1
  seed_2         = var.talos_seed_2
  gateway        = "192.168.10.1"
  network_bridge = "vmbr0"
}

#module "network_config" {
#  source = "./routeros"

#  wan_interface  = var.wan_interface
#  bgp_asn_router = var.bgp_asn_router

#  dns_records = {
#    "cp.homelab.local" = ["192.168.10.100"]
#    (var.talos_controlplane_dns_name) = [
#      for name, node in var.talos_nodes : coalesce(node.ip_address, "192.168.10.${node.vmid}") if node.is_control
#    ]
#  }

#  bgp_peers = {
#    for name, node in var.talos_nodes : name => {
#      remote_address = coalesce(node.ip_address, "192.168.10.${node.vmid}")
#      remote_asn     = var.bgp_asn_k8s
#    }
#  }
#}

variable "proxmox_api_url" {}
variable "proxmox_user" {}
variable "proxmox_password" {}
variable "proxmox_node" {}
variable "routeros_hosturl" {}
variable "routeros_username" {}
variable "routeros_password" {}

variable "talos_os_iso" {
  description = "Path to Talos OS ISO"
  type        = string
  default     = null
}

variable "talos_seed_1" {
  description = "Path to first seed ISO"
  type        = string
  default     = null
}

variable "talos_seed_2" {
  description = "Path to second seed ISO"
  type        = string
  default     = null
}

variable "talos_nodes" {
  description = "Map of Talos nodes configuration"
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


variable "wan_interface" {
  type = string
}

variable "bgp_asn_router" {
  type = number
}

variable "bgp_asn_k8s" {
  type = number
}

variable "talos_controlplane_dns_name" {
  description = "DNS name for the Talos control plane"
  type        = string
  default     = "controlplane.local"
}
