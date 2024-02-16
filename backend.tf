terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.92.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "1.12.0"
    }
  }
  required_version = ">=1.2.9"
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

provider "azapi" {}
