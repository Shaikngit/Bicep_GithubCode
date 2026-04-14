# 🏗️ VM behind NAT Gateway

## 🎯 Overview

This lab deploys a **Linux Virtual Machine behind a NAT Gateway** on Azure. The VM has no public IP of its own — all outbound internet traffic is routed through the NAT Gateway, providing a predictable, static outbound IP address. This is a common pattern for securing outbound connectivity while reducing the VM's attack surface.

## 🏛️ Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                 Azure Resource Group (rg-vm-natgateway)          │
│                                                                  │
│  ┌───────────────────────────────┐    ┌───────────────────────┐  │
│  │   NAT Gateway                 │    │   Public IP           │  │
│  │   (natGateway)                │◄───│   (natGatewayPublicIP)│  │
│  │   Standard SKU                │    │   Standard / Static   │  │
│  └──────────────┬────────────────┘    └───────────────────────┘  │
│                 │                                                 │
│  ┌──────────────┼────────────────────────────────────────────┐   │
│  │  Virtual Network (vNet) — 10.0.0.0/16                     │   │
│  │  ┌──────────┼─────────────────────────────────────────┐   │   │
│  │  │  Subnet (10.0.0.0/24) ◄── NAT Gateway associated  │   │   │
│  │  │                                                     │   │   │
│  │  │  ┌─────────────────────────────────────────────┐   │   │   │
│  │  │  │  Linux VM (natgwVM)                         │   │   │   │
│  │  │  │  • Ubuntu 22.04 LTS                         │   │   │   │
│  │  │  │  • No Public IP                             │   │   │   │
│  │  │  │  • Private IP: 10.0.0.x                     │   │   │   │
│  │  │  │  • Outbound → NAT Gateway → Internet        │   │   │   │
│  │  │  └─────────────────────────────────────────────┘   │   │   │
│  │  └────────────────────────────────────────────────────┘   │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │  NSG (SecGroupNet)                                        │   │
│  │  • Allow SSH (22) Inbound                                 │   │
│  └───────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘

Outbound: VM ──► Subnet ──► NAT Gateway ──► Public IP ──► Internet
```

### Key Components

- **Linux VM**: Ubuntu LTS with no public IP — only private connectivity
- **NAT Gateway**: Standard SKU providing SNAT for outbound internet access
- **Public IP**: Standard SKU, static allocation, attached to NAT Gateway
- **Virtual Network**: Isolated 10.0.0.0/16 address space
- **Subnet**: 10.0.0.0/24 with NAT Gateway and NSG association
- **NSG**: SSH (port 22) inbound rule

## 📋 Features

- NAT Gateway for predictable outbound IP (firewall allow-listing)
- No public IP on the VM — reduced attack surface
- SSH key or password authentication support
- Trusted Launch security profile
- Overlake (v5) or Non-Overlake (v4) VM size options
- Ubuntu 20.04 or 22.04 LTS
- Configurable network addressing

## 🔧 Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `adminUsername` | string | — | Administrator username |
| `authenticationType` | string | `password` | `sshPublicKey` or `password` |
| `adminPasswordOrKey` | securestring | — | Password or SSH public key |
| `vmName` | string | `natgwVM` | Virtual machine name |
| `virtualNetworkName` | string | `vNet` | VNet name |
| `subnetName` | string | `Subnet` | Subnet name |
| `networkSecurityGroupName` | string | `SecGroupNet` | NSG name |
| `natGatewayName` | string | `natGateway` | NAT Gateway name |
| `natGatewayPublicIPName` | string | `natGatewayPublicIP` | NAT GW public IP name |
| `vmSizeOption` | string | `Non-Overlake` | `Overlake` or `Non-Overlake` |
| `ubuntuOSVersion` | string | `Ubuntu-2204` | `Ubuntu-2004` or `Ubuntu-2204` |
| `securityType` | string | `TrustedLaunch` | `Standard` or `TrustedLaunch` |
| `vNetAddressPrefix` | string | `10.0.0.0/16` | VNet CIDR |
| `vNetSubnetAddressPrefix` | string | `10.0.0.0/24` | Subnet CIDR |
| `location` | string | `resourceGroup().location` | Azure region |

## 🚀 Quick Deploy

### 1. Navigate to the project
```powershell
cd C:\Bicep_GithubCode\VM_NATGateway
```

### 2. Validate the template
```powershell
.\validate.ps1
```

### 3. Deploy with password
```powershell
.\deploy.ps1 -AdminUsername "azureuser" -AdminPasswordOrKey "YourStrongP@ssw0rd!"
```

### 4. Deploy with SSH key
```powershell
.\deploy.ps1 -AdminUsername "azureuser" `
             -AdminPasswordOrKey "$(Get-Content ~/.ssh/id_rsa.pub)" `
             -AuthenticationType "sshPublicKey"
```

### 5. Clean up
```powershell
.\cleanup.ps1 -ResourceGroupName "rg-vm-natgateway"
```

## 🧪 Testing

After deployment, verify the NAT Gateway is working:

1. **Access the VM** — Use Azure Bastion or a jump box in the same VNet (the VM has no public IP):
   ```bash
   # From a jump box or via Bastion serial console
   ssh azureuser@10.0.0.4
   ```

2. **Verify outbound IP** — From the VM, check the outbound IP matches the NAT Gateway public IP:
   ```bash
   curl -s ifconfig.me
   ```
   The returned IP should match the NAT Gateway's public IP shown in deployment outputs.

3. **Verify no public IP on VM** — In the Azure portal, confirm the VM's NIC has no public IP associated.

4. **Test outbound connectivity** — From the VM:
   ```bash
   curl -s https://www.microsoft.com -o /dev/null -w "%{http_code}"
   # Should return 200
   ```

## 💰 Estimated Cost

| Resource | Estimated Monthly Cost |
|----------|----------------------|
| Linux VM (Standard_D2s_v4) | ~$30.00 |
| NAT Gateway (Standard) | ~$4.50 + data processing |
| Public IP (Standard, Static) | ~$3.60 |
| Managed Disk (Standard LRS) | ~$1.50 |
| **Total** | **~$40/month** |

> Costs are approximate for the `southeastasia` region. Actual costs may vary.

## 📚 References

- [Azure NAT Gateway documentation](https://learn.microsoft.com/en-us/azure/nat-gateway/nat-overview)
- [NAT Gateway and VM — Tutorial](https://learn.microsoft.com/en-us/azure/nat-gateway/tutorial-create-nat-gateway-portal)
- [Azure Virtual Network](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
- [Network Security Groups](https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview)
- [Linux VMs on Azure](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/overview)
