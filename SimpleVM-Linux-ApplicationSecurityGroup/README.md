---
description: This template shows how to put together the pieces to secure workloads using NSGs with Application Security Groups. It will deploy a Linux VM running NGINX and through the usage of Applicaton Security Groups on Network Security Groups we will allow access to ports 22 and 80 to a VM assigned to Application Security Group called webServersAsg.
page_type: sample
products:
- azure
- azure-resource-manager
urlFragment: application-security-group
languages:
- json
---
# Application Security Groups

This template shows how to work with Application Security Groups using templates. It assigns a VM to the Application Security Group and assigns this Application Security group to two security rules on Network Security Group, one that allows SSH and another one that allows HTTP using the Destination Application Security Group Id property of the security rule.

It deploys the following items:
1. Application Security Group
2. Network Security with two Security Rules, both using destinationApplicationSecurityGroups attribute
3. Virtual Network with one Subnet assigned to this NSG.
4. Network Interface assigned to Application Security Group, through its ID (notice that more than one can be assigned)
5. Centos 6.9 Linux Web server with NGINX installed through Custom Script Extension for Linux

## The script install_nginx.sh is for installing and configuring Nginx on a CentOS/RHEL Based system

While deploying the template, you will be asked to provide the following parameters:

- `adminUsername`: The username for the Virtual Machine
- `adminPassword`: The password for the Virtual Machine
- `scriptURI`: The URI of the script to be executed on the VM to install Ngnix, you should have install_nginx.sh file in blob storage with proper SAS token



For more information about Application Security Groups, please refer to:

[Network Security Groups under Network Security document](https://docs.microsoft.com/azure/virtual-network/security-overview#application-security-groupshttps://docs.microsoft.com/azure/virtual-network/security-overview)

[Filter network traffic with a network security group using PowerShell](https://docs.microsoft.com/azure/virtual-network/tutorial-filter-network-traffic)

[Filter network traffic with a network security group using the Azure CLI](https://docs.microsoft.com/azure/virtual-network/tutorial-filter-network-traffic-cli)

`Tags: Microsoft.Network/applicationSecurityGroups, Microsoft.Network/networkSecurityGroups, Microsoft.Network/virtualNetworks, Microsoft.Network/publicIPAddresses, Microsoft.Network/networkInterfaces, Microsoft.Compute/virtualMachines, Microsoft.Compute/virtualMachines/extensions, CustomScript`
