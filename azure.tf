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

resource "azurerm_public_ip" "public_ip_1" {
  name                = "virtual_network_gateway_public_ip_1"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  # Public IP needs to be dynamic for the Virtual Network Gateway
  # Keep in mind that the IP address will be "dynamically generated" after
  # being attached to the Virtual Network Gateway below
  allocation_method = "Dynamic"
}

resource "azurerm_public_ip" "public_ip_2" {
  name                = "virtual_network_gateway_public_ip_2"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  # Public IP needs to be dynamic for the Virtual Network Gateway
  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "virtual_network_gateway" {
  name                = "virtual_network_gateway"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  # Configuration for high availability
  active_active = true
  # This might me expensive, check the prices  
  sku           = "VpnGw1"

  # Configuring the two previously created public IP Addresses
  ip_configuration {
    name                          = azurerm_public_ip.public_ip_1.name
    public_ip_address_id          = azurerm_public_ip.public_ip_1.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.subnet_gateway.id
  }

  ip_configuration {
    name                          = azurerm_public_ip.public_ip_2.name
    public_ip_address_id          = azurerm_public_ip.public_ip_2.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.subnet_gateway.id
  }
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

# Tunnel from Azure to AWS vpn_connection_1 (tunnel1)
resource "azurerm_local_network_gateway" "local_network_gateway_1_tunnel1" {
  name                = "local_network_gateway_1_tunnel1"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  # AWS VPN Connection public IP address
  gateway_address = aws_vpn_connection.vpn_connection_1.tunnel1_address

  address_space = [
    # AWS VPC CIDR
    aws_vpc.vpc.cidr_block
  ]
}

resource "azurerm_virtual_network_gateway_connection" "virtual_network_gateway_connection_1_tunnel1" {
  name                = "virtual_network_gateway_connection_1_tunnel1"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.virtual_network_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.local_network_gateway_1_tunnel1.id

  # AWS VPN Connection secret shared key
  shared_key = aws_vpn_connection.vpn_connection_1.tunnel1_preshared_key
}

# Tunnel from Azure to AWS vpn_connection_1 (tunnel2)
resource "azurerm_local_network_gateway" "local_network_gateway_1_tunnel2" {
  name                = "local_network_gateway_1_tunnel2"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  gateway_address = aws_vpn_connection.vpn_connection_1.tunnel2_address

  address_space = [
    aws_vpc.vpc.cidr_block
  ]
}

resource "azurerm_virtual_network_gateway_connection" "virtual_network_gateway_connection_1_tunnel2" {
  name                = "virtual_network_gateway_connection_1_tunnel2"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.virtual_network_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.local_network_gateway_1_tunnel2.id

  shared_key = aws_vpn_connection.vpn_connection_1.tunnel2_preshared_key
}

# Tunnel from Azure to AWS vpn_connection_2 (tunnel1)
resource "azurerm_local_network_gateway" "local_network_gateway_2_tunnel1" {
  name                = "local_network_gateway_2_tunnel1"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  gateway_address = aws_vpn_connection.vpn_connection_2.tunnel1_address

  address_space = [
    aws_vpc.vpc.cidr_block
  ]
}

resource "azurerm_virtual_network_gateway_connection" "virtual_network_gateway_connection_2_tunnel1" {
  name                = "virtual_network_gateway_connection_2_tunnel1"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.virtual_network_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.local_network_gateway_2_tunnel1.id

  shared_key = aws_vpn_connection.vpn_connection_2.tunnel1_preshared_key
}

# Tunnel from Azure to AWS vpn_connection_2 (tunnel2)
resource "azurerm_local_network_gateway" "local_network_gateway_2_tunnel2" {
  name                = "local_network_gateway_2_tunnel2"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  gateway_address = aws_vpn_connection.vpn_connection_2.tunnel2_address

  address_space = [
    aws_vpc.vpc.cidr_block
  ]
}

resource "azurerm_virtual_network_gateway_connection" "virtual_network_gateway_connection_2_tunnel2" {
  name                = "virtual_network_gateway_connection_2_tunnel2"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.virtual_network_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.local_network_gateway_2_tunnel2.id

  shared_key = aws_vpn_connection.vpn_connection_2.tunnel2_preshared_key
}
