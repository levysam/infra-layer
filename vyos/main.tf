terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_vm" "vyos" {
  name      = var.name
  node_name = var.proxmox_node
  vm_id     = var.vmid

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  scsi_hardware = var.proxmox_scsi_hardware

  disk {
    datastore_id = var.storage_id
    file_id      = var.iso_path
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = var.disk_size
  }

  network_device {
    bridge = var.lan_bridge
    model  = "virtio"
  }

  dynamic "network_device" {
    for_each = var.use_pci_passthrough ? [] : [1]
    content {
      bridge = var.wan_bridge
      model  = "virtio"
    }
  }

  dynamic "hostpci" {
    for_each = var.use_pci_passthrough ? [1] : []
    content {
      device  = "hostpci0"
      mapping = var.pci_passthrough_id
      pcie    = true
    }
  }

  initialization {
    datastore_id = var.storage_id
    ip_config {
      ipv4 {
        address = var.lan_cidr
      }
    }
    ip_config {
      ipv4 {
        address = can(regex("/", var.vyos_management_ip)) ? var.vyos_management_ip : "${var.vyos_management_ip}/24"
      }
    }
    user_data_file_id = var.bootstrap_snippet_id
  }

  lifecycle {
    ignore_changes = [
      initialization,
    ]
  }
}

output "vyos_ip" {
  value = try(proxmox_virtual_environment_vm.vyos.ipv4_addresses[2][0], "Booting...")
}
