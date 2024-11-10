# Bicep Deployment Script

This repository contains a Bicep script for deploying a lab setup to check how Private endpoint polcies work.

The lab setup consists of the following resources:

Client VM - Windows Server 2019 Datacenter
SQL Server VM - Windows Server 2019 Datacenter
Azure Private Endpoint for SQL Server VM
Azure Private DNS Zone
Azure Private DNS Link

This deployment script creates three VNETs - one for the client VM, one for the SQL Server VM, and one for the private endpoint.

when the deployment is completed, you can connect to the client VM and try to connect to the SQL Server VM using the private IP address. You can also try to connect to the SQL Server VM using the private endpoint.

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
