provider "azurerm" {
  version = "2.1.0"
  features {}

  # IMPORTANT!
  # For simplicity, we are not setting up "proper" access through environment variables
  # Insert your access credentials here
  subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  tenant_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  client_secret   = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  client_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}

# And not configuring a Terraform remote state
terraform {}

resource "azurerm_resource_group" "resource_group" {
  name     = "resource_group"
  location = "westeurope"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space       = ["10.0.0.0/16"]
}

# The subnet where the Virtual Machine will live
resource "azurerm_subnet" "subnet_1" {
  name                 = "subnet_1"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefix       = "10.0.1.0/24"
}

# The subnet where the VPN tunnel will live
resource "azurerm_subnet" "subnet_gateway" {
  # The name "GatewaySubnet" is mandatory
  # Only one "GatewaySubnet" is allowed per vNet
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefix       = "10.0.2.0/24"
}
