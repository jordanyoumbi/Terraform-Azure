# Configure the Microsoft Azure Provider (Conso interne 2, microsoft.onmicrosoft.com)
provider "azurerm" {
  subscription_id = "${var.AzureSubscriptionID}"
  client_id       = "${var.AzureClientID}"
  client_secret   = "${var.AzureClientSecret}"
  tenant_id       = "${var.AzureTenantID}"
}

# creation d'un reseau dans le ressource groupe
 
resource "azurerm_virtual_network" "network" {
  name                = "productionNetwork"
  address_space       = "${var.AdresseReseau}"
  location            = "${var.location}"
  resource_group_name = "${var.AzureResourceGroup}"
}

resource "azurerm_subnet" "subnet1" {
    depends_on = ["azurerm_virtual_network.network"]
    name           = "Monsubnet"
    resource_group_name = "${var.AzureResourceGroup}"
    virtual_network_name = "${azurerm_virtual_network.network.name}"
    address_prefix = "${var.AdressePrefix}"
  }

#on creer une adresse public

resource "azurerm_public_ip" "adressepub" {
    count = "${var.count}"
    name = "terraformtestip.${var.count}"
    location = "${var.location}"
    resource_group_name = "${var.AzureResourceGroup}"
    public_ip_address_allocation = "dynamic"

    tags {
        environment = "TerraformDemo"
    }
}


#ici on creer une interface reseau

resource "azurerm_network_interface" "face" {
    count = "${var.count}"
    name = "${upper(var.VM_name)}-NIC-${format(var.count_format, var.count_offset + count.index + 1)}"
    location = "${var.location}"
    resource_group_name = "${var.AzureResourceGroup}"

    ip_configuration {
        name = "${upper(var.VM_name)}-NIC-${format(var.count_format, var.count_offset + count.index + 1) }"
        subnet_id = "${azurerm_subnet.subnet1.id}"
        private_ip_address_allocation = "Dynamic"
#        private_ip_address = "${var.PrivateIP}"
#        public_ip_address_id = "${var.public_ip_address_ids[count.index]}"
    }
}

output "NomIPPublic" {
	value= "${azurerm_public_ip.adressepub.name}"
}

output "MyID" {
        value= ["${azurerm_public_ip.adressepub.ip_address}"]
}


# ici on creer un compte de stockage

resource "azurerm_storage_account" "test" {
#  count = "${var.count}"
  name                ="${var.AccountName}"
  resource_group_name = "${var.AzureResourceGroup}"
  location            = "${var.location}"
  account_type        = "Standard_LRS"

  tags {
    environment = "staging"
  }
}

# ici on va creer un container de stockage dans notre machine virtuelle

resource "azurerm_storage_container" "test" {
  count = "${var.count}"
  name                  = "${lower(var.VM_name)}${lower(var.DiskName)}${format(var.count_format, var.count_offset + count.index + 1)}"
  resource_group_name   = "${var.AzureResourceGroup}"
  storage_account_name  = "${azurerm_storage_account.test.name}"
  container_access_type = "private"
}

output "StorageName" {
  value = "${azurerm_storage_account.test.name}"
}

# creation d'un machine virtuelle ubuntu
resource "azurerm_virtual_machine" "mavm" {
    count = "${var.count}"
    name = "${var.VM_name}-${format(var.count_format, var.count_offset + count.index +1)}"
    location = "${var.lacation}"
    resource_group_name = "${var.AzureResourceGroup}"
    network_interface_ids = ["${element(azurerm_network_interface.face.*.id, count.index)}"]
    vm_size = "Standard_A0"

        storage_image_reference {
        publisher = "canonical"
        offer = "UbuntuServer"
        sku = "16.04-LTS"
	version = "latest"
    }

    storage_os_disk {
        name = "${lower(var.VM_name)}-${lower(var.DiskName)}-${format(var.count_format, var.count_offset + count.index + 1)}"
       vhd_uri ="${azurerm_storage_account.test.primary_blob_endpoint}${element(azurerm_storage_container.test.*.name, count.index + 1)}/${var.os_disk_name}.vhd"
        caching = "ReadWrite"
        create_option = "FromImage"
    }

      os_profile {
        computer_name = "devoteam"
        admin_username = "${var.admin_username}"
        admin_password = "${var.admin_password}"
    }

       os_profile_linux_config {
        disable_password_authentication = false
     }

    tags {
        environment = "staging"
    }
}

output "blob_endpoint" {
  value = "${azurerm_storage_account.test.primary_blob_endpoint}"
}
