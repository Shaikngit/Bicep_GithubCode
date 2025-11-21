# Simple Windows VM Deployment Lab 🖥️

## Overview

This lab demonstrates the deployment of a **Windows Server VM** on Azure with customizable configuration options. The template supports both custom and marketplace images, flexible VM sizing (Standard vs Overlake), and secure networking with RDP access control.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Azure Resource Group                      │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Virtual Network (clientVNET)                   ││
│  │                   10.0.0.0/16                               ││
│  │                                                             ││
│  │  ┌─────────────────────────────────────────────────────┐   ││
│  │  │              Default Subnet                          │   ││
│  │  │               10.0.0.0/24                           │   ││
│  │  │                                                     │   ││
│  │  │  ┌─────────────────────────────────────────────┐   │   ││
│  │  │  │             Windows VM                       │   │   ││
│  │  │  │         (myVm)                              │   │   ││
│  │  │  │  • Windows Server 2019 Datacenter          │   │   ││
│  │  │  │  • Standard_D2s_v4/v5                     │   │   ││
│  │  │  │  • Private IP: 10.0.0.x                   │   │   ││
│  │  │  └─────────────────────────────────────────────┘   │   ││
│  │  │                      │                              │   ││
│  │  └──────────────────────┼──────────────────────────────┘   ││
│  └───────────────────────────┼───────────────────────────────────┘│
│                              │                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Network Security Group                         ││
│  │                     (myNsg)                                 ││
│  │                                                             ││
│  │  📋 Inbound Rules:                                         ││
│  │  • Allow RDP (3389) from specified source IP              ││
│  │  • Priority: 1000                                          ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Public IP Address                              ││
│  │                 (myPublicIp)                                ││
│  │               Dynamic allocation                            ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘

External Access: Internet ──► Public IP ──► NSG (Port 3389) ──► VM
```

### Key Components

- **Virtual Network**: Isolated network environment with /16 address space
- **Windows VM**: Configurable Windows Server instance with flexible sizing
- **Network Security Group**: Secured RDP access from specified source IP
- **Public IP**: Dynamic public IP for external connectivity
- **Custom Image Support**: Option to use custom VM images from Compute Gallery

## 🔧 Prerequisites

- Azure CLI installed and configured
- Azure Bicep CLI extension
- Valid Azure subscription with VM deployment permissions
- Source IP address for secure RDP access

## 🚀 Quick Start

### 1. Clone and Navigate
```powershell
cd C:\Bicep_GithubCode\SimpleVM-Windows
```

### 2. Deploy the Lab
```powershell
# Create resource group
az group create --name "rg-simple-vm-lab" --location "East US"

# Deploy with default marketplace image
az deployment group create \
  --resource-group "rg-simple-vm-lab" \
  --template-file main.bicep \
  --parameters adminUsername="azureuser" \
               adminPassword="YourSecurePassword123!" \
               allowedRdpSourceAddress="YOUR.PUBLIC.IP.ADDRESS/32" \
               vmSizeOption="Non-Overlake" \
               useCustomImage="No"
```

### 3. Deploy with Custom Image
```powershell
az deployment group create \
  --resource-group "rg-simple-vm-lab" \
  --template-file main.bicep \
  --parameters adminUsername="azureuser" \
               adminPassword="YourSecurePassword123!" \
               allowedRdpSourceAddress="YOUR.PUBLIC.IP.ADDRESS/32" \
               vmSizeOption="Overlake" \
               useCustomImage="Yes"
```

## 📋 Configuration Parameters

| Parameter | Type | Options | Description |
|-----------|------|---------|-------------|
| `adminUsername` | string | - | Local administrator username |
| `adminPassword` | securestring | - | Strong password (12+ characters) |
| `allowedRdpSourceAddress` | string | IP/CIDR | Source IP allowed for RDP access |
| `location` | string | Azure regions | Deployment region (defaults to RG location) |
| `vmSizeOption` | string | `Overlake` \| `Non-Overlake` | VM size category selection |
| `useCustomImage` | string | `Yes` \| `No` | Use custom gallery image vs marketplace |
| `customImageResourceId` | string | Gallery image ID | Custom image resource identifier |

### VM Size Options

| Option | VM Size | vCPUs | RAM | Temp Storage | Use Case |
|--------|---------|-------|-----|--------------|----------|
| **Non-Overlake** | Standard_D2s_v4 | 2 | 8 GB | 16 GB SSD | General purpose workloads |
| **Overlake** | Standard_D2s_v5 | 2 | 8 GB | 16 GB SSD | Latest generation, optimized performance |

## 🔐 Security Features

✅ **Network Isolation**
- Dedicated virtual network with private subnet
- Network Security Group with minimal required rules
- Source IP restriction for RDP access

✅ **Access Control**
- Admin credentials required for deployment
- Public IP with controlled inbound rules
- No unnecessary ports exposed

✅ **Best Practices**
- Dynamic public IP allocation
- Secure parameter handling for passwords
- Resource naming conventions

## 📊 Resource Overview

| Resource Type | Name | Purpose | Configuration |
|---------------|------|---------|---------------|
| Virtual Network | clientVNET | Network isolation | 10.0.0.0/16 |
| Subnet | default | VM placement | 10.0.0.0/24 |
| Network Security Group | myNsg | Traffic filtering | RDP rule only |
| Public IP | myPublicIp | External access | Dynamic allocation |
| Network Interface | myNic | VM connectivity | Auto-assigned private IP |
| Virtual Machine | myVm | Compute workload | Windows Server 2019 |

## 🧪 Testing & Validation

### 1. Verify Deployment
```powershell
# Check VM status
az vm show --resource-group "rg-simple-vm-lab" --name "myVm" --query "provisioningState"

# Get public IP address
az network public-ip show --resource-group "rg-simple-vm-lab" --name "myPublicIp" --query "ipAddress" --output tsv
```

### 2. Connect via RDP
1. Obtain the public IP from deployment output or Azure portal
2. Use Remote Desktop Connection with:
   - **Computer**: `PUBLIC_IP_ADDRESS`
   - **Username**: `[adminUsername]`
   - **Password**: `[adminPassword]`

### 3. Verify Network Configuration
```cmd
# Inside the VM, check network settings
ipconfig /all
ping 8.8.8.8
```

## 🧹 Cleanup

### Remove All Resources
```powershell
# Delete the entire resource group (removes all resources)
az group delete --name "rg-simple-vm-lab" --yes --no-wait
```

### Verify Cleanup
```powershell
# Confirm resource group deletion
az group list --query "[?name=='rg-simple-vm-lab']"
```

## 💡 Customization Examples

### Deploy with Custom Location
```powershell
az deployment group create \
  --resource-group "rg-simple-vm-lab" \
  --template-file main.bicep \
  --parameters location="West US 2" \
               adminUsername="azureuser" \
               adminPassword="YourSecurePassword123!" \
               allowedRdpSourceAddress="203.0.113.0/24"
```

### Deploy for Development Team Access
```powershell
az deployment group create \
  --resource-group "rg-simple-vm-lab" \
  --template-file main.bicep \
  --parameters adminUsername="devadmin" \
               adminPassword="DevTeamSecure456!" \
               allowedRdpSourceAddress="192.168.1.0/24" \
               vmSizeOption="Overlake"
```

## 🚨 Important Notes

⚠️ **Security Considerations**
- Always restrict `allowedRdpSourceAddress` to your specific IP or network
- Use strong passwords (12+ characters, mixed case, numbers, symbols)
- Consider using Azure Bastion for enhanced security in production

💰 **Cost Management**
- VM runs continuously and incurs charges while deployed
- Use `az vm deallocate` to stop charges when not in use
- Delete resources when lab is complete to avoid ongoing costs

🔄 **Automation Ready**
- Template supports CI/CD pipeline integration
- Parameters can be stored in Azure Key Vault
- Easily modified for multiple environment deployments

---

**Need help?** Check the deployment output for connection details or review the Azure portal for resource status.
