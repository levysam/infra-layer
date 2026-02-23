terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

resource "proxmox_vm_qemu" "talos_node" {
  for_each = var.nodes

  name        = each.key
  target_node = var.proxmox_node
  vmid        = each.value.vmid

  clone = var.os_iso == null ? var.template_name : null

  agent    = 0
  os_type  = "l26"
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"
  boot     = "order=ide2;scsi0"
  memory   = each.value.ram

  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "host"
  }

  disks {
    scsi {
      scsi0 {
        disk {
          size     = "${each.value.disk_size}G"
          storage  = each.value.storage_id
          iothread = true
        }
      }
    }

    ide {
      # OS CDROM if iso is set
      dynamic "ide2" {
        for_each = var.os_iso != null ? [1] : []
        content {
          cdrom {
            iso = var.os_iso
          }
        }
      }

      # Seed 1 (Control Plane)
      dynamic "ide0" {
        for_each = (var.seed_1 != null && each.value.is_control) ? [1] : []
        content {
          cdrom {
            iso = var.seed_1
          }
        }
      }

      # Seed 2 (Worker Nodes)
      dynamic "ide1" {
        for_each = (var.seed_2 != null && !each.value.is_control) ? [1] : []
        content {
          cdrom {
            iso = var.seed_2
          }
        }
      }

      ide3 {
        cloudinit {
          storage = each.value.storage_id
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  ipconfig0 = each.value.ip_address == null ? "ip=dhcp" : "ip=${each.value.ip_address}/24,gw=${var.gateway}"
}
