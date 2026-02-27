
output "proxmox_api_url" {
  value = var.proxmox_api_url
}

output "proxmox_csi_api_url" {
  value = var.proxmox_csi_api_url != null ? var.proxmox_csi_api_url : var.proxmox_api_url
}

output "proxmox_csi_token_id" {
  value = var.enable_proxmox_csi ? proxmox_virtual_environment_user_token.csi_token[0].id : null
}

output "proxmox_csi_token_secret" {
  value     = var.enable_proxmox_csi ? split("=", proxmox_virtual_environment_user_token.csi_token[0].value)[1] : null
  sensitive = true
}

output "proxmox_node" {
  value = var.proxmox_node
}

output "proxmox_region" {
  value = var.proxmox_region
}
