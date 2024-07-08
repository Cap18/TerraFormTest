### Terraform Configuration
#### `main.tf`

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "rg-microservice-production"
  location = "Italy North"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-microservice"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "public" {
  name                 = "subnet-public"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "private" {
  name                 = "subnet-private"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "public" {
  name                = "nsg-public"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow_http_inbound"
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

resource "azurerm_network_security_group" "private" {
  name                = "nsg-private"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_network_security_rule" "allow_vnet_inbound" {
  name                        = "allow_vnet_inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.private.name
}

resource "azurerm_public_ip" "app_gateway" {
  name                = "pip-app-gateway"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "app_gateway" {
  name                = "app-gateway"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.public.id
  }

  frontend_port {
    name = "frontendPort"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appGatewayFrontendIpConfig"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }

  backend_address_pool {
    name = "appGatewayBackendPool"
  }

  backend_http_settings {
    name                  = "appGatewayBackendHttpSettings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "appGatewayHttpListener"
    frontend_ip_configuration_name = "appGatewayFrontendIpConfig"
    frontend_port_name             = "frontendPort"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rule1"
    rule_type                  = "Basic"
    priority                   =  9
    http_listener_name         = "appGatewayHttpListener"
    backend_address_pool_name  = "appGatewayBackendPool"
    backend_http_settings_name = "appGatewayBackendHttpSettings"
  }
}

resource "azurerm_virtual_machine_scale_set" "app_vmss" {
  name                = "vmss-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  upgrade_policy_mode = "Automatic"

  sku {
    name     = "Standard_DS1_v2"
    tier     = "Standard"
    capacity = 2
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_profile_os_disk {
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name_prefix = "appvm"
    admin_username       = "adminuser"
    admin_password       = "P@ssw0rd123!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  network_profile {
    name    = "networkprofile"
    primary = true

    ip_configuration {
      name      = "ipconfig"
      subnet_id = azurerm_subnet.private.id
      primary   = true
    }
  }

}

resource "azurerm_sql_server" "main" {
  name                         = "sqlserver-terr"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd123!"

  tags = {
    environment = "production"
  }
}

resource "azurerm_sql_database" "main" {
  name                = "sqldb-terr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  server_name         = azurerm_sql_server.main.name
  edition             = "Standard"
  requested_service_objective_name = "S1"

  tags = {
    environment = "production"
  }
}

resource "azurerm_storage_account" "log_storage" {
  name                     = "logterrstorageapp"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "production"
  }
}

resource "azurerm_monitor_log_profile" "main" {
  name = "logprofile"

  storage_account_id = azurerm_storage_account.log_storage.id
  retention_policy {
    enabled = true
    days    = 30
  }

  categories = [
    "Write",
    "Delete",
    "Action",
  ]

  locations = [azurerm_resource_group.main.location]
}

data "azurerm_client_config" "terratest" {}

resource "azurerm_role_assignment" "log_storage_assignment" {
  scope              = azurerm_storage_account.log_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id       = data.azurerm_client_config.terratest.object_id
}
