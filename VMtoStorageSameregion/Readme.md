# Bicep Deployment Script

This repository contains a Bicep script for deploying a simple windows vm and a simple storage account in same region.

The lab setup consists of the following resources:

Client VM - Windows Server 2019 Datacenter
Storage Account - Standard_LRS

## File Structure

- `main.bicep`: The main Bicep script that defines the infrastructure.


## Prerequisites

- VS Code installed
- Azure CLI installed
- Bicep Extension installed in VS Code

## Deployment

To deploy the resources defined in the `main.bicep` file, use the following command:

```Terminal

az group create --name <resourcegroupname> --location <location>

az deployment group create --resource-group <resourcegroupname> --template-file main.bicep 

```
To deploy the VM resources in the `main.bicep` with custom image use the following command:

```Terminal 

az deployment group create --resource-group <resourcegroupname> --template-file main.bicep --parameters useCustomImage=Yes 

```

## Input 

- Resource Group Name
- Location
- Admin Username
- Admin Password
- Public IP Address of your machine to allow RDP

## Output

- None

## Clean up deployment

To remove the resources that were created as part of this deployment, use the following command:

```Terminal
az group delete --name <resourcegroupname> --yes --no-wait
```
