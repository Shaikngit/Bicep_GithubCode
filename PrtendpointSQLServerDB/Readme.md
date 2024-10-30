# Bicep Deployment Script

This repository contains a Bicep script for deploying Prviate endpoint for SQL Server Database


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

az deployment group create --resource-group <resourcegroupname> --template-file main.bicep --query properties.outputs.publicIpAddress.value
```

## Input 

- Resource Group Name
- Location
- VM Admin Username
- VM Admin Password
- SQL Admin Username
- SQL Admin Password
- Public IP Address of your machine to allow RDP

## Output

- Public IP Address of the VM to connect via RDP

## Access the SQL Database Server via Private Endpoint

Access the SQL Database server privately from the VM. To connect to the SQL Database server from the VM by using the private endpoint, do the following:

1. On the Remote Desktop of `myVM{uniqueid}`, open PowerShell.
2. Run the following command:
   ```powershell
   nslookup sqlserver{uniqueid}.database.windows.net
   ```
   You'll receive a message that's similar to this one:
   ```
   Server:  UnKnown
   Address:  168.63.129.16
   Non-authoritative answer:
   Name:    sqlserver.privatelink.database.windows.net
   Address:  10.0.0.5
   Aliases:  sqlserver.database.windows.net
   ```
3. Install SQL Server Management Studio.
4. On the Connect to Server pane, do the following:
   - For Server type, select Database Engine.
   - For Server name, select `sqlserver{uniqueid}.database.windows.net`.
   - For Username, enter the username that was provided earlier.
   - For Password, enter the password that was provided earlier.
   - For Remember password, select Yes.
   - Select Connect.
5. On the left pane, select Databases. Optionally, you can create or query information from `sample-db`.
6. Close the Remote Desktop connection to `myVM{uniqueid}`.

## Clean up deployment

To remove the resources that were created as part of this deployment, use the following command:

```Terminal
az group delete --name <resourcegroupname> --yes --no-wait
```
