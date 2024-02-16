resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_resource_group" "org" {
  name     = "rg-${random_string.random[0].result}"
  location = var.location
}

resource "random_string" "random" {
  count = 4

  length  = 7
  special = false
  numeric = false
  upper   = false
}

resource "random_string" "password" {
  length = 22
}

resource "azurerm_service_plan" "asp" {
  count               = 1
  name                = "asp-${random_string.random[count.index].result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_availability_set" "avail" {
  count               = 3
  name                = "avail-${random_string.random[count.index].result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  managed             = count.index % 2 == 0 ? true : false
}

resource "azurerm_mssql_server" "sql" {
  name                         = "sql${random_string.random[0].result}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = random_string.random[1].result
  administrator_login_password = random_string.password.result
  minimum_tls_version          = "1.2"
}

resource "azurerm_mssql_elasticpool" "sqlep" {
  name                = "sqlep${random_string.random[2].result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  server_name         = azurerm_mssql_server.sql.name
  license_type        = "LicenseIncluded"
  max_size_gb         = 4.8828125

  sku {
    name     = "BasicPool"
    tier     = "Basic"
    capacity = 50
  }

  per_database_settings {
    min_capacity = 5
    max_capacity = 5
  }
}

resource "azurerm_managed_disk" "disk" {
  count                = 4
  name                 = "disk-${random_string.random[count.index].result}"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "32"
}

resource "azurerm_public_ip" "pip" {
  count               = 4
  name                = "pip-${random_string.random[count.index].result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = count.index % 2 == 0 ? "Standard" : "Basic"
  allocation_method   = count.index % 2 == 0 ? "Static" : "Dynamic"
}

resource "azurerm_virtual_network" "vnet" {
  count               = 2
  name                = "vnet-${random_string.random[count.index].result}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "snet" {
  count                = 3
  name                 = "snet-${random_string.random[count.index].result}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet[1].name
  address_prefixes     = [cidrsubnet(azurerm_virtual_network.vnet[1].address_space[0], 8, count.index * 2)]
}

resource "azurerm_network_interface" "nic" {
  count               = 4
  name                = "nic-${random_string.random[count.index].result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet[1].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_security_group" "nsg" {
  count               = 3
  name                = "nsg-${random_string.random[count.index].result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_route_table" "rt" {
  name                = "rt-${random_string.random[3].result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_lb" "lbe" {
  name                = "lbe-${random_string.random[3].result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.pip[1].id
  }
}

resource "azurerm_frontdoor_firewall_policy" "waf" {
  name                = "waf${random_string.random[2].result}"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_traffic_manager_profile" "traf" {
  name                   = "traf-${random_string.random[1].result}"
  resource_group_name    = azurerm_resource_group.rg.name
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = random_string.random[1].result
    ttl           = 100
  }

  monitor_config {
    protocol = "HTTP"
    path     = "/"
    port     = 80
  }
}

resource "azurerm_application_gateway" "agw" {
  name                = "agw-${random_string.random[2].result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "ip-configuration"
    subnet_id = azurerm_subnet.snet[0].id
  }

  frontend_port {
    name = "feport"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "feip"
    public_ip_address_id = azurerm_public_ip.pip[2].id
  }

  backend_address_pool {
    name = "beap"
  }

  backend_http_settings {
    name                  = "be-htst"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "httplstn"
    frontend_ip_configuration_name = "feip"
    frontend_port_name             = "feport"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rqrt"
    priority                   = 2
    rule_type                  = "Basic"
    http_listener_name         = "httplstn"
    backend_address_pool_name  = "beap"
    backend_http_settings_name = "be-htst"
  }
}

resource "azurerm_ip_group" "ipg" {
  name                = "ipg-ipgroup-${random_string.random[0].result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "privdns" {
  for_each            = toset(["privatelink.azurecr.io", "privatelink.blob.core.windows.net", "privatelink.database.windows.net"])
  name                = each.value
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "privdnslinks" {
  name                  = "to-${azurerm_virtual_network.vnet[1].name}"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = "privatelink.azurecr.io"
  virtual_network_id    = azurerm_virtual_network.vnet[1].id
  registration_enabled  = true
}

resource "azurerm_automation_account" "aa" {
  name                = "aa-${random_string.random[0].result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"
}

resource "azurerm_private_endpoint" "pep" {
  count               = 1
  name                = "pep-${random_string.random[count.index].result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.snet[1].id

  private_service_connection {
    name                           = "psc-${azurerm_automation_account.aa.name}"
    private_connection_resource_id = azurerm_automation_account.aa.id
    subresource_names              = ["Webhook"]
    is_manual_connection           = false
  }
}

resource "azapi_resource_action" "deleteaa" {
  type        = "Microsoft.Automation/automationAccounts@2023-11-01"
  resource_id = azurerm_automation_account.aa.id
  method      = "DELETE"

  depends_on = [
    azurerm_private_endpoint.pep
  ]
}
