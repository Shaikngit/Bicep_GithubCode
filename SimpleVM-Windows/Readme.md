# Bicep Deployment Script

This repository contains a Bicep script for deploying Simple Azure VM.

OS - Windows Server 2012 R2 Datacenter

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

az deployment group create --resource-group <resourcegroupname> --template-file main.bicep --parameters useCustomImage=Yes
```

## Input 

- Resource Group Name
- Location
- Admin Username
- Admin Password
- Public IP Address of your machine to allow RDP

## Output

- Public IP Address of the VM to connect via RDP

## Clean up deployment

To remove the resources that were created as part of this deployment, use the following command:

```Terminal
az group delete --name <resourcegroupname> --yes --no-wait
```
