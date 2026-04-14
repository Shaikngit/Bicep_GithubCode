# VM behind NAT Gateway - Project Summary

## 📁 Complete File Structure

```
VM_NATGateway/
├── main.bicep                 # Main Bicep template — VM + NAT Gateway
├── deploy.ps1                 # PowerShell deployment script
├── validate.ps1               # Template validation script
├── cleanup.ps1                # Resource cleanup automation
├── PROJECT_SUMMARY.md         # This project structure overview
└── Readme.md                  # Quick-start documentation
```

## 📊 Project Overview

| Field | Value |
|-------|-------|
| **Name** | VM_NATGateway |
| **Description** | Linux VM behind a NAT Gateway for controlled outbound internet access |
| **Use Case** | Secure outbound connectivity without exposing VM with a public IP |
| **Complexity** | ⭐⭐ |
| **Deployment Time** | ~5-10 minutes |

## 🎯 Key Features

✅ **NAT Gateway for Outbound Traffic**
- Standard SKU NAT Gateway with static public IP
- All outbound internet traffic from the VM routes through the NAT Gateway
- Predictable outbound IP address for firewall allow-listing

✅ **No Public IP on VM**
- VM has no direct public IP — reduced attack surface
- Inbound SSH access requires Azure Bastion or a jump box
- Outbound-only internet access through NAT Gateway

✅ **Network Security**
- Network Security Group with SSH inbound rule
- NSG associated with the subnet
- VNet isolation with controlled traffic flow

✅ **Flexible Linux VM**
- Ubuntu 20.04 or 22.04 LTS support
- SSH key or password authentication
- Overlake (v5) and Non-Overlake (v4) VM sizing options
- Trusted Launch security profile

✅ **Enterprise Ready**
- Standard SKU public IP for NAT Gateway
- Configurable idle timeout
- Scalable architecture (add more VMs to the same subnet)

## 🚀 Quick Start Commands

```powershell
# Navigate to project directory
cd C:\Bicep_GithubCode\VM_NATGateway

# Validate template (recommended first)
.\validate.ps1

# Deploy with password authentication
.\deploy.ps1 -AdminUsername "azureuser" `
             -AdminPasswordOrKey "YourStrongP@ssw0rd!" `
             -VmSizeOption "Non-Overlake"

# Deploy with SSH key authentication
.\deploy.ps1 -AdminUsername "azureuser" `
             -AdminPasswordOrKey "ssh-rsa AAAA..." `
             -AuthenticationType "sshPublicKey"

# Clean up when done
.\cleanup.ps1 -ResourceGroupName "rg-vm-natgateway"
```

## 🔧 Technical Specifications

| Resource | Details |
|----------|---------|
| **Virtual Machine** | Ubuntu 22.04 LTS, Standard_D2s_v4/v5, no public IP |
| **NAT Gateway** | Standard SKU, 4-min idle timeout, 1 public IP |
| **Public IP** | Standard SKU, Static allocation (for NAT GW only) |
| **Virtual Network** | 10.0.0.0/16 address space |
| **Subnet** | 10.0.0.0/24, associated with NAT Gateway and NSG |
| **NSG** | SSH (port 22) inbound allowed |

## 🎨 Architecture Diagram

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
│  │  │  ┌──────┴──────────────────────────────────────┐   │   │   │
│  │  │  │  NSG (SecGroupNet)                          │   │   │   │
│  │  │  │  • Allow SSH (22) Inbound                   │   │   │   │
│  │  │  └─────────────────────────────────────────────┘   │   │   │
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
└──────────────────────────────────────────────────────────────────┘

Outbound Flow: VM ──► Subnet ──► NAT Gateway ──► Public IP ──► Internet
Inbound SSH:   Requires Azure Bastion or jump box (no direct public IP on VM)
```
