terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_vm" "talos_node" {
  for_each = var.nodes

  name      = each.key
  node_name = var.proxmox_node
  vm_id     = each.value.vmid

  agent {
    enabled = false # Talos doesn't use the standard QEMU agent for management
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.ram
  }

  scsi_hardware = var.proxmox_scsi_hardware

  disk {
    datastore_id = var.proxmox_vm_datastore
    file_id      = var.image_file_id # Talos .img or .iso
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = each.value.disk_size
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.proxmox_vm_datastore
    ip_config {
      ipv4 {
        address = each.value.ip_address == null ? "dhcp" : "${each.value.ip_address}/24"
        gateway = each.value.ip_address == null ? null : var.gateway
      }
    }
    user_data_file_id = each.value.config_id
  }

  operating_system {
    type = "l26" # Linux 2.6+
  }

  lifecycle {
    ignore_changes = [
      initialization,
    ]
  }
}

