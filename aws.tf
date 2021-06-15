provider "aws" {
  version    = "2.55.0"
  # IMPORTANT!
  # Setup your correct region, access_key and secret_key
  # Again, we are not focusing on credentials best practices here
  region     = "eu-west-1"
  access_key = ""
  secret_key = ""
}

resource "aws_vpc" "vpc" {
  cidr_block = "192.168.0.0/16"

  tags = {
    Name = "vpc"
  }
}

# The subnet where the Virtual Machine will live
resource "aws_subnet" "subnet_1" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "192.168.1.0/24"

  tags = {
    Name = "subnet_1"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "internet_gateway"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "route_table"
  }
}

# Enabling the resources from subnet_1 to access the Internet
# So we can access it later via SSH
resource "aws_route" "subnet_1_exit_route" {
  route_table_id         = aws_route_table.route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.route_table.id
}

data "azurerm_public_ip" "azure_public_ip_1" {
  # That neat name interpolation
  # The end result is _exactly_ the name of Azure's public IP
  name                = "${azurerm_virtual_network_gateway.virtual_network_gateway.name}_public_ip_1"
  resource_group_name = azurerm_resource_group.resource_group.name
}

data "azurerm_public_ip" "azure_public_ip_2" {
  name                = "${azurerm_virtual_network_gateway.virtual_network_gateway.name}_public_ip_2"
  resource_group_name = azurerm_resource_group.resource_group.name
}

resource "aws_customer_gateway" "customer_gateway_1" {
  bgp_asn = 65000

  # Using the previously fetched Azure's public IP
  ip_address = data.azurerm_public_ip.azure_public_ip_1.ip_address
  type       = "ipsec.1"

  tags = {
    Name = "customer_gateway_1"
  }
}

resource "aws_customer_gateway" "customer_gateway_2" {
  bgp_asn = 65000

  ip_address = data.azurerm_public_ip.azure_public_ip_2.ip_address
  type       = "ipsec.1"

  tags = {
    Name = "customer_gateway_2"
  }
}

resource "aws_vpn_gateway" "vpn_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "vpn_gateway"
  }
}

# We will use information from this piece to finish the Azure configuration on the next Step
resource "aws_vpn_connection" "vpn_connection_1" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gateway.id
  customer_gateway_id = aws_customer_gateway.customer_gateway_1.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name = "vpn_connection_1"
  }
}

# We will use information from this piece to finish the Azure configuration on the next Step
resource "aws_vpn_connection" "vpn_connection_2" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gateway.id
  customer_gateway_id = aws_customer_gateway.customer_gateway_2.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name = "vpn_connection_2"
  }
}

resource "aws_vpn_connection_route" "vpn_connection_route_1" {
  # Azure's vnet CIDR
  destination_cidr_block = azurerm_virtual_network.vnet.address_space[0]
  vpn_connection_id      = aws_vpn_connection.vpn_connection_1.id
}

resource "aws_vpn_connection_route" "vpn_connection_route_2" {
  # Azure's vnet CIDR
  destination_cidr_block = azurerm_virtual_network.vnet.address_space[0]
  vpn_connection_id      = aws_vpn_connection.vpn_connection_2.id
}

# The route teaching where to go to get to Azure's CIDR
resource "aws_route" "route_to_azure" {
  route_table_id = aws_route_table.route_table.id

  # Azure's vnet CIDR
  destination_cidr_block = azurerm_virtual_network.vnet.address_space[0]
  gateway_id             = aws_vpn_gateway.vpn_gateway.id
}
