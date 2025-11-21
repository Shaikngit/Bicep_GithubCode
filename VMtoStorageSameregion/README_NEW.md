# 💾 VM with Storage Account (Same Region)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.storage%2Fstorage-account-create%2Fazuredeploy.json)

## 🎯 Overview

This Bicep template deploys a Windows virtual machine with a Storage Account in the same Azure region, demonstrating optimal data locality, reduced latency, and cost-effective storage patterns. This architecture is ideal for applications requiring fast local storage access.

## 🏗️ Architecture

```
    ┌─────────────────────────────────────────────────────────────┐
    │                 Azure Region (Same)                        │
    │                                                             │
    │  ┌───────────────────────────────────────────────────────┐ │
    │  │            Virtual Network                              │ │
    │  │           (10.0.0.0/16)                                │ │
    │  │                                                         │ │
    │  │  ┌─────────────────────────────────────────────────────┐│ │
    │  │  │                Subnet                               ││ │
    │  │  │             (10.0.0.0/24)                          ││ │
    │  │  │                                                     ││ │
    │  │  │    ┌─────────────────────────────────────────────┐ ││ │
    │  │  │    │            Windows VM                      │ ││ │
    │  │  │    │         • RDP Access                       │ ││ │
    │  │  │    │         • Custom/Default Images             │ ││ │
    │  │  │    │         • Configurable Sizing              │ ││ │
    │  │  │    └─────────────────────────────────────────────┘ ││ │
    │  │  │                     │                               ││ │
    │  │  │                     ▼ (High-Speed Local Access)    ││ │
    │  │  │    ┌─────────────────────────────────────────────┐ ││ │
    │  │  │    │          Storage Account                    │ ││ │
    │  │  │    │       • Blob Storage                        │ ││ │
    │  │  │    │       • File Shares                         │ ││ │
    │  │  │    │       • Tables & Queues                     │ ││ │
    │  │  │    │       • Same Region = Low Latency           │ ││ │
    │  │  │    └─────────────────────────────────────────────┘ ││ │
    │  │  └─────────────────────────────────────────────────────┘│ │
    │  └───────────────────────────────────────────────────────┘ │
    └─────────────────────────────────────────────────────────────┘
                           │
                   (Optional Internet Access)
                           │
                           ▼
                   ┌─────────────────────┐
                   │      Internet       │
                   └─────────────────────┘
```

## 📋 Features

- **Same-Region Deployment**: VM and Storage in identical region for optimal performance
- **Windows Virtual Machine**: Configurable Windows VM with flexible sizing
- **Storage Account**: General-purpose v2 storage with multiple services
- **Low Latency Access**: Regional co-location for high-speed data access
- **Modular Design**: Separate modules for VM and storage components
- **Custom Image Support**: Use custom or marketplace VM images
- **Network Security**: NSG with configurable access rules
- **Cost Optimization**: Regional deployment reduces data transfer costs

## 🔧 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| location | string | resourceGroup().location | Azure region for deployment |
| adminpassword | securestring | - | Administrator password for VM |
| adminusername | string | - | Administrator username for VM |
| allowedRdpSourceAddress | string | - | Source IP/CIDR for RDP access |
| vmSizeOption | string | Non-Overlake | VM size option (Overlake/Non-Overlake) |
| useCustomImage | string | No | Use custom VM image (Yes/No) |

## 🚀 Quick Deploy

### Azure CLI
```bash
# Create resource group
az group create --name rg-vm-storage-region --location eastus

# Deploy template
az deployment group create \
  --resource-group rg-vm-storage-region \
  --template-file main.bicep \
  --parameters adminusername="azureuser" \
               adminpassword="SecureP@ssw0rd123!" \
               allowedRdpSourceAddress="0.0.0.0/0"
```

### PowerShell
```powershell
# Create resource group
New-AzResourceGroup -Name "rg-vm-storage-region" -Location "East US"

# Deploy template
New-AzResourceGroupDeployment `
  -ResourceGroupName "rg-vm-storage-region" `
  -TemplateFile "main.bicep" `
  -adminusername "azureuser" `
  -adminpassword (ConvertTo-SecureString "SecureP@ssw0rd123!" -AsPlainText -Force) `
  -allowedRdpSourceAddress "0.0.0.0/0"
```

## 🧪 Testing & Validation

### 1. Connect to Windows VM
```bash
# RDP to the VM using public IP
# Use Windows Remote Desktop Connection
# Credentials: adminusername / adminpassword
```

### 2. Test Storage Performance
```powershell
# From VM, install Azure PowerShell
Install-Module -Name Az -Force

# Connect to Azure
Connect-AzAccount

# Test storage operations
$storageAccount = Get-AzStorageAccount -ResourceGroupName "<rg>" -Name "<storage-name>"
$ctx = $storageAccount.Context

# Create test container and upload file
New-AzStorageContainer -Name "test" -Context $ctx
Set-AzStorageBlobContent -File "C:\test.txt" -Container "test" -Blob "test.txt" -Context $ctx
```

### 3. Measure Latency
```powershell
# Test network latency to storage
Test-NetConnection -ComputerName "<storage-account>.blob.core.windows.net" -Port 443

# Measure storage operation performance
Measure-Command { 
    # Storage operation here
    Get-AzStorageBlob -Container "test" -Context $ctx
}
```

### 4. Verify Regional Co-location
```powershell
# Check VM location
$vm = Get-AzVM -ResourceGroupName "<rg>" -Name "<vm-name>"
Write-Host "VM Location: $($vm.Location)"

# Check storage account location
Write-Host "Storage Location: $($storageAccount.Location)"
```

## 🔒 Security Features

- ✅ Regional network isolation
- ✅ Network Security Groups for VM access
- ✅ Storage account firewall rules
- ✅ Configurable RDP access restrictions
- ✅ Windows Firewall protection
- ✅ Azure RBAC for storage access
- ✅ Encrypted storage at rest

## 🏷️ Resource Tags

All resources are tagged with:
- Project: VM-Storage-Same-Region
- Environment: Demo
- Pattern: Regional-Colocation

## 💰 Cost Benefits

### Same-Region Advantages
- **No Data Transfer Charges**: Between VM and Storage
- **Reduced Latency**: Faster application performance
- **Lower Egress Costs**: Minimal outbound data charges
- **Optimized Pricing**: Regional pricing consistency

### Monthly Cost Estimates (East US)
- **Windows VM**: Variable based on size selection
- **Storage Account**: Pay-as-you-use pricing
- **Data Transfer**: $0 (same region)
- **Public IP**: ~$4/month (if enabled)

## 📊 Performance Benefits

### Latency Comparison
| Scenario | Typical Latency | Use Case |
|----------|----------------|----------|
| **Same Region** | 1-5ms | Real-time applications |
| Cross-Region | 50-200ms | Disaster recovery |
| Cross-Continent | 150-300ms | Global distribution |

### Throughput Optimization
- Maximum bandwidth between VM and Storage
- No internet routing overhead
- Consistent performance characteristics

## 📊 Monitoring

### Key Metrics
- Storage account transaction metrics
- VM performance counters
- Network latency measurements
- Storage operation success rates
- Cost analysis and optimization

### Performance Monitoring
```powershell
# Monitor storage metrics
Get-AzMetric -ResourceId $storageAccount.Id -MetricName "Transactions"

# Check VM performance
Get-Counter "\Processor(_Total)\% Processor Time"
Get-Counter "\Memory\Available MBytes"
```

## 🔧 Customization

### Storage Configuration
- Configure different performance tiers
- Set up lifecycle management policies
- Implement geo-redundancy for disaster recovery
- Add private endpoints for enhanced security

### VM Configuration
- Scale VM size based on workload requirements
- Add data disks for application data
- Configure auto-shutdown for cost optimization
- Implement backup policies

## 🚨 Troubleshooting

### Storage Access Issues
```powershell
# Check storage account status
Get-AzStorageAccount -ResourceGroupName "<rg>" -Name "<storage-name>"

# Verify network access
Test-NetConnection -ComputerName "<storage-name>.blob.core.windows.net" -Port 443

# Check firewall rules
Get-AzStorageAccountNetworkRuleSet -ResourceGroupName "<rg>" -AccountName "<storage-name>"
```

### Performance Issues
```powershell
# Check VM performance
Get-Counter "\Processor(_Total)\% Processor Time"
Get-Counter "\Network Interface(*)\Bytes Total/sec"

# Monitor storage operations
# Use Azure Monitor for detailed metrics
```

## 📚 Related Resources

- [Azure Storage Account Documentation](https://docs.microsoft.com/azure/storage/)
- [Windows VM Documentation](https://docs.microsoft.com/azure/virtual-machines/windows/)
- [Azure Regions and Availability Zones](https://docs.microsoft.com/azure/availability-zones/az-overview)
- [Storage Performance Best Practices](https://docs.microsoft.com/azure/storage/common/storage-performance-checklist)

---

*This template demonstrates optimal regional deployment patterns for high-performance applications requiring fast storage access.*