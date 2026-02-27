variable "kubeconfig_path" {
  type        = string
  description = "Path to the Talos generated kubeconfig file"
  default     = "~/.kube/config"
}

variable "proxmox_csi_storage_pool" {
  type        = string
  description = "Name of the Proxmox Storage Pool to use for dynamic PVC provisioning (e.g. local-zfs, local-lvm)"
  default     = "local-zfs"
}
