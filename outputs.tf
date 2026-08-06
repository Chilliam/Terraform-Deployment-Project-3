output "lb_public_ip" {
  value = azurerm_public_ip.lb_pip.ip_address
}

output "data_vm_private_ip" {
  value = azurerm_network_interface.data_nic.ip_configuration[0].private_ip_address
}