# Define the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "My-VMSS-LB-RG"
  location = "West Europe"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "My-VMSS-LB-VNET"
  address_space       = ["172.16.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "My-VMSS-LB-SUBNET"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["172.16.0.0/24"]
}

# Public IP for Load Balancer
resource "azurerm_public_ip" "publicip" {
  name                = "My-VMSS-LB-PublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

# Load Balancer
resource "azurerm_lb" "lb" {
  name                = "My-VMSS-LB"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.publicip.id
  }
}

# Backend Address Pool
resource "azurerm_lb_backend_address_pool" "pool" {
  name            = "My-VMSS-LB-BackendPool"
  loadbalancer_id = azurerm_lb.lb.id
}

# Health Probe
resource "azurerm_lb_probe" "probe" {
  name            = "My-VMSS-LB-Probe"
  loadbalancer_id = azurerm_lb.lb.id
  protocol        = "Http"
  port            = 80
  request_path    = "/"
}

# Load Balancing Rule
resource "azurerm_lb_rule" "rule" {
  name                           = "My-VMSS-LB-Rule"
  loadbalancer_id                = azurerm_lb.lb.id
  frontend_ip_configuration_name = azurerm_lb.lb.frontend_ip_configuration[0].name
  probe_id                       = azurerm_lb_probe.probe.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.pool.id]
}

#Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "My-VMSS-LB-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Interface
resource "azurerm_network_interface" "nic" {
  count               = 2
  name                = "My-VMSS-LB-NIC-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

}

# Virtual Machine Scale Set
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "My-VMSS-LB-VMSS"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_B1s"
  upgrade_mode        = "Manual"
  instances           = 2
  admin_username      = "azureuser"
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/Linux-VM_key.pub")
  }
  
  custom_data = filebase64("script.sh")

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "My-VMSS-LB-NIC"
    primary = true

    ip_configuration {
      name                                   = "internal"
      subnet_id                              = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids = [ azurerm_lb_backend_address_pool.pool.id ]
    }
  }

  single_placement_group = true
}

output "public_ip" {
  value = azurerm_public_ip.publicip.ip_address
}