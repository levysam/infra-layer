output "vm_info" {
  description = "Map of created VMs and their details"
  value = {
    for k, v in proxmox_vm_qemu.talos_node : k => {
      id  = v.vmid
      ip  = v.default_ipv4_address
      mac = try(v.network[0].macaddr, "")
    }
  }
}
