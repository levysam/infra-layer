output "vm_id" {
  value = { for name, vm in proxmox_virtual_environment_vm.talos_node : name => vm.id }
}

output "vm_ips" {
  value = { for name, vm in proxmox_virtual_environment_vm.talos_node : name => vm.ipv4_addresses[1] if vm.ipv4_addresses != null && length(vm.ipv4_addresses) > 1 }
}
