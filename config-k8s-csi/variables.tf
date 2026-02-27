variable "kubeconfig_path" {
  type        = string
  description = "Path to the Talos generated kubeconfig file"
  default     = "~/.kube/config"
}

variable "cilium_bgp_lb_cidr" {
  type        = string
  description = "The CIDR block to use for BGP LoadBalancer IPs"
  default     = "192.168.20.0/24"
}
variable "proxmox_csi_storage_pool" {
  type        = string
  description = "Name of the Proxmox Storage Pool to use for dynamic PVC provisioning (e.g. local-zfs, local-lvm)"
  default     = "local-zfs"
}
