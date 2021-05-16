terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "hdi" {
  name     = "rg-hdinsight"
  location = "eastus"
}

resource "azurerm_storage_account" "hdi" {
  name                     = "storhdi${random_string.unique.result}"
  resource_group_name      = azurerm_resource_group.hdi.name
  location                 = azurerm_resource_group.hdi.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "hdi" {
  name                  = "hdinsight"
  storage_account_name  = azurerm_storage_account.hdi.name
  container_access_type = "private"
}

resource "azurerm_hdinsight_hadoop_cluster" "hdi" {
  name                = "hdicluster${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.hdi.name
  location            = azurerm_resource_group.hdi.location
  cluster_version     = "3.6"
  tier                = "Standard"

  component_version {
    hadoop = "2.7"
  }

  gateway {
    enabled  = true
    username = "acctestusrgw"
    password = "TerrAform123!"
  }

  storage_account {
    storage_container_id = azurerm_storage_container.hdi.id
    storage_account_key  = azurerm_storage_account.hdi.primary_access_key
    is_default           = true
  }

  roles {
    head_node {
      vm_size            = "Standard_E2_V3"
      username           = "acctestusrvm"
      password           = "AccTestvdSC4daf986!"
      subnet_id          = azurerm_subnet.hdi.id
      virtual_network_id = azurerm_virtual_network.hdi.id
    }

    worker_node {
      vm_size               = "Standard_E2_V3"
      username              = "acctestusrvm"
      password              = "AccTestvdSC4daf986!"
      target_instance_count = 1
      subnet_id             = azurerm_subnet.hdi.id
      virtual_network_id    = azurerm_virtual_network.hdi.id
    }

    zookeeper_node {
      vm_size            = "Standard_A2_V2"
      username           = "acctestusrvm"
      password           = "AccTestvdSC4daf986!"
      subnet_id          = azurerm_subnet.hdi.id
      virtual_network_id = azurerm_virtual_network.hdi.id
    }
  }
}

resource "azurerm_virtual_network" "hdi" {
  name                = "vnethdi"
  resource_group_name = azurerm_resource_group.hdi.name
  location            = azurerm_resource_group.hdi.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "hdi" {
  name                 = "subnethdi"
  resource_group_name  = azurerm_resource_group.hdi.name
  virtual_network_name = azurerm_virtual_network.hdi.name
  address_prefixes     = ["10.0.0.0/24"]

}

resource "azurerm_network_security_group" "hdi" {
  name                = "hdinsight_security_group"
  location            = azurerm_resource_group.hdi.location
  resource_group_name = azurerm_resource_group.hdi.name
}

resource "azurerm_network_security_rule" "rule-required443-incoming" {
  name                        = "Required_HDInsight_Host_IPs_Port_443"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = ["168.61.49.99", "23.99.5.239", "168.61.48.131", "138.91.141.162"]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.hdi.name
  network_security_group_name = azurerm_network_security_group.hdi.name
}

resource "azurerm_network_security_rule" "rule-required53-incoming" {
  name                        = "Required_HDInsight_Host_IPs_Port_53"
  priority                    = 400
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "168.63.129.16"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.hdi.name
  network_security_group_name = azurerm_network_security_group.hdi.name
}

resource "azurerm_network_security_rule" "rule-servicetag-incoming" {
  name                        = "Required_HDInsight_ServiceTag"
  priority                    = 500
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "HDInsight"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.hdi.name
  network_security_group_name = azurerm_network_security_group.hdi.name
}

resource "azurerm_network_security_rule" "rule-virtualnetwork-outgoing" {
  name                        = "AllowVnetOutBound"
  priority                    = 500
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.hdi.name
  network_security_group_name = azurerm_network_security_group.hdi.name
}

resource "azurerm_network_security_rule" "rule-allowed-ports-outgoing" {
  name                        = "AllowedOutBoundPorts"
  priority                    = 400
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["1-21", "23-2221", "2223-65535"]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.hdi.name
  network_security_group_name = azurerm_network_security_group.hdi.name
}

resource "azurerm_network_security_rule" "rule-deny-all" {
  name                        = "DenyAllOutBound"
  priority                    = 1000
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.hdi.name
  network_security_group_name = azurerm_network_security_group.hdi.name
}

resource "azurerm_subnet_network_security_group_association" "hdi" {
  subnet_id                 = azurerm_subnet.hdi.id
  network_security_group_id = azurerm_network_security_group.hdi.id
}
