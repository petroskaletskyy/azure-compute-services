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

# Create a Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "Linux-VM-with-nginx-RG"
  location = "West Europe"
}

# Create a Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "Linux-VM-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "Linux-VM-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.100.0/24"]
}

# Create a Network Security Group (NSG)
resource "azurerm_network_security_group" "nsg" {
  name                = "Linux-VM-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Allow SSH (Port 22)
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP (Port 80)
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create a Public IP Address
resource "azurerm_public_ip" "public_ip" {
  name                = "Linux-VM-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create a Network Interface
resource "azurerm_network_interface" "nic" {
  name                = "Linux-VM-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Manage SSH Public Key
resource "azurerm_ssh_public_key" "ssh_key" {
  name                = "Linux-VM-ssh-key"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "West Europe"
  public_key          = file("~/.ssh/Linux-VM_key.pub")
}

# Create a Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "Linux-VM-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]
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
  custom_data = filebase64("custom_data.sh")
}

# Output the Public IP Address
output "public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}
