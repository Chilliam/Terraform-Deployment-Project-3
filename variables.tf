variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "environment_name" {
  description = "Environment name used in resource naming"
  type        = string
}

variable "admin_username" {
  description = "Admin username for both VMs"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key content for VM authentication"
  type        = string
  sensitive   = true
}