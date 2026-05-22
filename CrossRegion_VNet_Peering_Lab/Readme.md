# 🏗️ Cross-Region VNet Peering Lab (EastUS2 ↔ WestUS2)

## 🎯 Overview
This lab deploys two VNets in different Azure regions, peers them bidirectionally, and places one Linux VM in each VNet. It is designed to validate private VM-to-VM connectivity across regions using VNet peering while keeping the VMs private. The default VM sizing mode is Overlake to align with your requirement for Overlake-capable VMs on both sides.

## 🏛️ Architecture

┌─────────────────────────────────────────────────────────────────────┐
│ Resource Group: rg-crossregion-vnet-peering-lab                    │
│                                                                     │
│  ┌───────────────────────────────┐      ┌──────────────────────────┐ │
│  │ EastUS2                       │      │ WestUS2                  │ │
│  │ VNet: 10.10.0.0/16            │◄────►│ VNet: 10.20.0.0/16       │ │
│  │ Subnet: 10.10.1.0/24          │Peer  │ Subnet: 10.20.1.0/24     │ │
│  │ VM: crpeer-vm-east            │      │ VM: crpeer-vm-west       │ │
│  │ SKU: Standard_D2s_v5 (default)│      │ SKU: Standard_D2s_v5     │ │
│  │ Bastion: crpeer-bastion-east  │      │ Bastion: crpeer-bastion-west│ │
│  └───────────────────────────────┘      └──────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘

### Components
- East VNet and West VNet with non-overlapping CIDRs
- Bidirectional VNet peering with virtual network access enabled
- One private Linux VM per region
- Azure Bastion in each region for secure VM access
- NSGs with rules to allow SSH and cross-VNet test traffic

## 📋 Features
- Cross-region peering between EastUS2 and WestUS2
- Overlake-capable VM sizing enabled by default
- Password or SSH key authentication
- Private connectivity testing using VM private IPs
- Clean deployment/validation/cleanup script workflow

## 🔧 Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| adminUsername | string | n/a | VM administrator username |
| adminPasswordOrKey | secure string | n/a | Password or SSH key based on authenticationType |
| authenticationType | string | password | VM authentication method (password or sshPublicKey) |
| resourcePrefix | string | crpeer | Resource naming prefix |
| ubuntuOSVersion | string | Ubuntu-2204 | Ubuntu image version |
| eastRegion | string | eastus2 | Region for first VNet/VM |
| westRegion | string | westus2 | Region for second VNet/VM |

## 🚀 Quick Deploy
1. Open PowerShell in this folder.
2. Validate the template.
3. Deploy resources.

```powershell
cd CrossRegion_VNet_Peering_Lab

# Validate before deployment
.\validate.ps1

# Deploy with password auth
.\deploy.ps1 -AdminUsername "azureuser" -AdminPasswordOrKey "P@ssw0rd1234!"

# Deploy with SSH public key auth
.\deploy.ps1 -AdminUsername "azureuser" -AuthenticationType "sshPublicKey" -AdminPasswordOrKey "ssh-rsa AAAA..."
```

## 🧪 Testing
1. In Azure Portal, connect to `crpeer-vm-east` using `crpeer-bastion-east`.
2. Get `crpeer-vm-west` private IP and run:

```bash
ping -c 4 <west-vm-private-ip>
ssh azureuser@<west-vm-private-ip>
```

3. Repeat from West to East:

```bash
ping -c 4 <east-vm-private-ip>
ssh azureuser@<east-vm-private-ip>
```

## 💰 Estimated Cost
- 2x Linux VMs (D2s_v5): ~$120-$180/month
- 2x Azure Bastion Basic: ~$280/month
- Networking and data transfer: variable
- Estimated total: ~$420-$520/month

## 📚 References
- https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview
- https://learn.microsoft.com/azure/bastion/bastion-overview
- https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/dsv5-series
