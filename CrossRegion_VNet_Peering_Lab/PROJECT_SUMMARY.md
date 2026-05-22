# Cross-Region VNet Peering Lab - Project Summary

## 📁 File Structure

```
CrossRegion_VNet_Peering_Lab/
├── main.bicep
├── deploy.ps1
├── validate.ps1
├── cleanup.ps1
├── PROJECT_SUMMARY.md
└── Readme.md
```

## 📊 Project Overview

| Item | Value |
|------|-------|
| Name | Cross-Region VNet Peering Lab |
| Description | Deploys EastUS2 and WestUS2 VNets with bidirectional peering and one VM in each region |
| Use Case | Validate VM-to-VM private connectivity across peered VNets in two regions |
| Complexity | ⭐⭐⭐ |
| Deployment Time | 15-25 minutes |

## 🎯 Key Features
- ✅ EastUS2 and WestUS2 regional topology
- ✅ Bidirectional VNet peering
- ✅ One Linux VM in each region
- ✅ Overlake VM sizing mode enabled by default
- ✅ Bastion-based secure VM access
- ✅ Password or SSH key authentication support
- ✅ Validation and cleanup automation scripts

## 🚀 Quick Start Commands

```powershell
cd CrossRegion_VNet_Peering_Lab

# Validate
.\validate.ps1

# Deploy with default Overlake sizing
.\deploy.ps1 -AdminUsername "azureuser" -AdminPasswordOrKey "P@ssw0rd1234!"

# Deploy with SSH key authentication
.\deploy.ps1 -AdminUsername "azureuser" -AuthenticationType "sshPublicKey" -AdminPasswordOrKey "ssh-rsa AAAA..."

# Cleanup
.\cleanup.ps1 -ResourceGroupName "rg-crossregion-vnet-peering-lab"
```

## 🔧 Technical Specifications

- Virtual Networks:
  - `crpeer-vnet-east` in `eastus2` with `10.10.0.0/16`
  - `crpeer-vnet-west` in `westus2` with `10.20.0.0/16`
- Subnets:
  - Workload subnets: `/24`
  - Bastion subnets: `/26`
- VM configuration:
  - Default size: `Standard_D2s_v5` (Overlake mode)
  - OS: Ubuntu 22.04 LTS
- Security:
  - NSG rules for SSH and peer VNet traffic
  - Private IP VM-to-VM connectivity via peering

## 🎨 Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│ Azure Resource Group: rg-crossregion-vnet-peering-lab                   │
│                                                                          │
│   ┌─────────────────────────────────┐      ┌──────────────────────────┐  │
│   │ EastUS2                         │      │ WestUS2                  │  │
│   │ VNet: crpeer-vnet-east          │◄────►│ VNet: crpeer-vnet-west   │  │
│   │ CIDR: 10.10.0.0/16              │Peer  │ CIDR: 10.20.0.0/16       │  │
│   │ Subnet: 10.10.1.0/24            │      │ Subnet: 10.20.1.0/24     │  │
│   │ VM: crpeer-vm-east              │      │ VM: crpeer-vm-west       │  │
│   │ VM Size: Standard_D2s_v5        │      │ VM Size: Standard_D2s_v5 │  │
│   │ Bastion: crpeer-bastion-east    │      │ Bastion: crpeer-bastion-west│ │
│   └─────────────────────────────────┘      └──────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```
