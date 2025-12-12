# Bicep Deployment Script

This repository contains a Bicep script for deploying a simple Windows VM and a simple storage account in the same region, with **managed identity integration** for secure storage access.

The lab setup consists of the following resources:

- **Client VM** - Windows Server 2019 Datacenter with:
  - Public IP for internet access (to install Azure CLI)
  - System-Assigned Managed Identity
- **Storage Account** - Standard_LRS with blob container
- **RBAC Role Assignment** - Storage Blob Data Contributor role granted to VM's managed identity

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Resource Group                        │
│                                                          │
│  ┌──────────────┐        RBAC         ┌──────────────┐  │
│  │   Windows VM │ ──────────────────► │   Storage    │  │
│  │  (Managed ID)│  Storage Blob Data  │   Account    │  │
│  │              │    Contributor      │              │  │
│  └──────────────┘                     └──────────────┘  │
│         │                                                │
│    Public IP                                             │
│    (for Azure CLI install)                               │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## File Structure

- `main.bicep`: The main Bicep script that defines the infrastructure.
- `simplewindows/client.bicep`: VM with managed identity and public IP.
- `simplestorage/storage.bicep`: Storage account with blob container.


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

- Bastion Name
- VM Name
- VM Private IP
- VM Public IP
- VM Principal ID (Managed Identity)
- Storage Account Name
- Storage Blob Endpoint
- Container Name

## Post-Deployment: Accessing Storage from VM

After deployment, connect to the VM via Bastion and run the following commands:

### 1. Install Azure CLI (if not already installed)

```powershell
# Download and install Azure CLI
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -ArgumentList '/I AzureCLI.msi /quiet' -Wait
# Restart PowerShell to use az commands
```

### 2. Login with Managed Identity

```powershell
az login --identity --allow-no-subscriptions
```

### 3. Upload files to Storage

```powershell
# Upload a single file
"Hello from Azure!" | Out-File test.txt
az storage blob upload --account-name <storage-account-name> --container-name folder --name test.txt --file "test.txt" --auth-mode login

# Upload multiple files (batch)
az storage blob upload-batch --source "C:\MyFolder" --destination "folder" --account-name <storage-account-name> --auth-mode login
```

> **Note**: The `--auth-mode login` flag tells Azure CLI to use the managed identity for authentication instead of storage keys.

## Clean up deployment

To remove the resources that were created as part of this deployment, use the following command:

```Terminal
az group delete --name <resourcegroupname> --yes --no-wait
```
