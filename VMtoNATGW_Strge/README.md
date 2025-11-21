# 🔗 VM with NAT Gateway and Storage Account

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.network%2Fnat-gateway%2Fazuredeploy.json)

## 🎯 Overview

This Bicep template deploys a client virtual machine with NAT Gateway for outbound internet connectivity and a Storage Account for data storage. This architecture demonstrates secure outbound connectivity management and cloud storage integration patterns.

## 🏛️ Architecture

```
    Internet
        |
        ▼
    ┌───────────┐
    │NAT Gateway│
    │Public IP  │
    └─────┬─────┘
          |
    ┌─────▼─────────────────────────────────────┐
    │        Virtual Network           │
    │        (10.0.0.0/16)            │
    │                                 │
    │  ┌─────────────────────────────┐ │
    │  │       Client Subnet         │ │
    │  │      (10.0.0.0/24)         │ │
    │  │                             │ │
    │  │    ┌─────────────────────┐  │ │
    │  │    │   Client VM     │  │ │
    │  │    │ (Private IP)    │  │ │
    │  │    └─────────────────────┘  │ │
    │  └─────────────────────────────┘ │
    └─────────────────────────────────────┘
                    │
                    ▼ (Storage Access)
          ┌──────────────────────────┐
          │   Storage Account    │
          │ • Blob Storage      │
          │ • File Shares       │
          │ • Tables/Queues     │
          └──────────────────────────┘
```

## 📋 Features

- **NAT Gateway**: Managed outbound internet connectivity
- **Client VM**: Windows virtual machine for testing and workloads
- **Storage Account**: General-purpose v2 storage with multiple services
- **Secure Networking**: Private VM with controlled outbound access
- **Modular Design**: Separate Bicep modules for client VM and storage
- **Custom Images Support**: Flexible VM deployment options
- **Network Security**: NSG with appropriate rules for client access

## 🔧 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| adminUsername | string | - | Administrator username for VM |
| adminPassword | securestring | - | Administrator password for VM |
| vmSizeOption | string | Non-Overlake | VM size option (Overlake/Non-Overlake) |
| location | string | resourceGroup().location | Azure region for deployment |
| useCustomImage | string | No | Use custom VM image (Yes/No) |
| customImageResourceId | string | - | Resource ID of custom image |

## 🚀 Quick Deploy

### Azure CLI
```bash
# Create resource group
az group create --name rg-vm-natgw-storage --location eastus

# Deploy template
az deployment group create \
  --resource-group rg-vm-natgw-storage \
  --template-file main.bicep \
  --parameters adminUsername="azureuser" \
               adminPassword="SecureP@ssw0rd123!"
```

### PowerShell
```powershell
# Create resource group
New-AzResourceGroup -Name "rg-vm-natgw-storage" -Location "East US"

# Deploy template
New-AzResourceGroupDeployment `
  -ResourceGroupName "rg-vm-natgw-storage" `
  -TemplateFile "main.bicep" `
  -adminUsername "azureuser" `
  -adminPassword (ConvertTo-SecureString "SecureP@ssw0rd123!" -AsPlainText -Force)
```

## 🧪 Testing & Validation

### 1. Connect to Client VM
```bash
# RDP to client VM (if public IP configured)
# Or use Azure Bastion for secure access
```

### 2. Test Outbound Connectivity
```powershell
# From Client VM, test internet connectivity through NAT Gateway
Test-NetConnection -ComputerName "8.8.8.8" -Port 53

# Check public IP (should show NAT Gateway IP)
Invoke-RestMethod -Uri "http://ifconfig.me/ip"
```

### 3. Test Storage Account Access
```powershell
# Install Azure PowerShell module
Install-Module -Name Az -Force

# Connect to Azure
Connect-AzAccount

# Test storage operations
$storageContext = New-AzStorageContext -StorageAccountName "<storage-name>" -UseConnectedAccount
New-AzStorageContainer -Name "test" -Context $storageContext
```

## 🔒 Security Features

- ✅ NAT Gateway provides secure outbound connectivity
- ✅ No public IP on client VM (optional)
- ✅ Network Security Groups for traffic control
- ✅ Storage Account with access controls
- ✅ Private networking architecture
- ✅ Managed identity support for storage access

## 🏷️ Resource Tags

All resources are tagged with:
- Project: VM-NAT-Gateway-Storage
- Environment: Demo
- Architecture: Client-NAT-Storage

## 💰 Cost Optimization

- **NAT Gateway**: ~$32/month + data processing
- **Virtual Machine**: Variable based on size
- **Storage Account**: Pay-as-you-use
- **Public IP**: ~$4/month (Standard)
- **Network**: No additional charges for VNet

## 📊 Monitoring

Monitor your deployment:
- NAT Gateway data processing metrics
- VM performance and availability
- Storage Account transaction metrics
- Network Security Group flow logs

## 🔧 Customization

### Storage Configuration
- Configure different storage tiers (Hot/Cool/Archive)
- Add private endpoints for storage services
- Implement lifecycle management policies

### Network Enhancements
- Add Azure Bastion for secure management
- Configure additional subnets for multi-tier architecture
- Implement Azure Firewall for advanced filtering

## 🚨 Troubleshooting

### NAT Gateway Issues
```bash
# Check NAT Gateway association
az network vnet subnet show --name <subnet> --vnet-name <vnet> --resource-group <rg>

# Verify NAT Gateway configuration
az network nat gateway show --name <nat-gw-name> --resource-group <rg>
```

### Storage Access Problems
```powershell
# Check storage account access
Get-AzStorageAccount -ResourceGroupName <rg> -Name <storage-name>

# Verify network access rules
Get-AzStorageAccountNetworkRuleSet -ResourceGroupName <rg> -AccountName <storage-name>
```

## 📚 Related Resources

- [Azure NAT Gateway Documentation](https://docs.microsoft.com/azure/virtual-network/nat-gateway/)
- [Azure Storage Account Documentation](https://docs.microsoft.com/azure/storage/)
- [Virtual Network Documentation](https://docs.microsoft.com/azure/virtual-network/)

---

*This template demonstrates outbound connectivity patterns and storage integration for cloud workloads.*