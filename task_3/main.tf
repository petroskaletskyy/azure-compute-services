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
  name     = "LB-RG"
  location = "West Europe"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "LB-VNET"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "LB-SUBNET"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "LB-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
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
  name                = "LB-NIC-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "LB-NIC-internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Public IP
resource "azurerm_public_ip" "lb-public-ip" {
  name                = "LB-PUBLIC-IP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Load Balancer
resource "azurerm_lb" "lb" {
  name                = "basic-LB"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"

  frontend_ip_configuration {
    name                 = "LB-Frontend"
    public_ip_address_id = azurerm_public_ip.lb-public-ip.id
  }
}

# Backend LB Pool
resource "azurerm_lb_backend_address_pool" "lb-pool" {
  name            = "Backend-LB-Pool"
  loadbalancer_id = azurerm_lb.lb.id
}

# LB Probe
resource "azurerm_lb_probe" "lb-probe" {
  name            = "HTTP-Probe"
  loadbalancer_id = azurerm_lb.lb.id
  protocol        = "Http"
  port            = 80
  request_path    = "/"
}

# LB Rule
resource "azurerm_lb_rule" "lb-rule" {
  name                           = "HTTP-Rule"
  loadbalancer_id                = azurerm_lb.lb.id
  frontend_ip_configuration_name = azurerm_lb.lb.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb-pool.id]
  probe_id                       = azurerm_lb_probe.lb-probe.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
}

# Manage SSH Public Key
resource "azurerm_ssh_public_key" "ssh_key" {
  name                = "Linux-VM-ssh-key"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "West Europe"
  public_key          = file("~/.ssh/Linux-VM_key.pub")
}

# Availability Set
resource "azurerm_availability_set" "availability_set" {
  name                = "LB-AVSET"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  count               = 2
  name                = "VM-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  availability_set_id = azurerm_availability_set.availability_set.id
  size                = "Standard_B1s"
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.nic[count.index].id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = azurerm_ssh_public_key.ssh_key.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
                #!/bin/bash
                sudo apt-get update
                sudo apt-get install -y nginx
                HOSTNAME=$(hostname)
                IP_ADDRESS=$(hostname -I | awk '{print $1}')
                echo "<html>" > /var/www/html/index.html
                echo "<body>" >> /var/www/html/index.html
                echo "<p><h1>Hostname: $HOSTNAME</h1></p>" >> /var/www/html/index.html
                echo "<p><h1>IP Address: $IP_ADDRESS</h1></p>" >> /var/www/html/index.html
                echo "</body>" >> /var/www/html/index.html
                echo "</html>" >> /var/www/html/index.html
                EOF
  )

}

# Network Interface Backend Address Pool Association
resource "azurerm_network_interface_backend_address_pool_association" "backend-pool-lb-assoc" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.nic[count.index].id
  ip_configuration_name   = "LB-NIC-internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb-pool.id
}

output "public_ip_address_id" {
  value = azurerm_public_ip.lb-public-ip.ip_address
}