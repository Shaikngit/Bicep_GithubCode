# Azure Public Load Balancer with Backend VMs Lab 🌐

## Overview

This lab demonstrates a **complete Azure Public Load Balancer deployment** with backend virtual machines, NAT Gateway for outbound connectivity, and Azure Bastion for secure management. The template creates an internet-facing load balancing solution with high availability, secure network access, and proper traffic distribution from the internet to backend services.

## 🏗️ Architecture

```
                              Internet
                                 │
                                 ▼
            ┌─────────────────────────────────────────────────┐
            │           Public Load Balancer                   │
            │             (lb-public)                          │
            │        Frontend IP: Public                       │
            │         Backend Pool: VMs                        │
            └─────────────────────────────────────────────────┘
                                 │
                                 ▼
            ┌─────────────────────────────────────────────────┐
            │            Azure Bastion                         │
            │         (AzureBastionSubnet)                     │
            │             10.0.2.0/24                          │
            └─────────────────────────────────────────────────┘
                                 │
┌─────────────────────────────────────────────────────────────────────┐
│                    Virtual Network (lb-vnet)                       │
│                         10.0.0.0/16                               │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │               Backend Subnet                                │   │
│  │                10.0.0.0/24                                  │   │
│  │                                                             │   │
│  │  ┌─────────────────┐              ┌─────────────────┐      │   │
│  │  │  BackendVM1     │              │  BackendVM2     │      │   │
│  │  │                 │              │                 │      │   │
│  │  │ • Windows Server│              │ • Windows Server│      │   │
│  │  │ • IIS Installed │              │ • IIS Installed │      │   │
│  │  │ • Private IP    │              │ • Private IP    │      │   │
│  │  │ • Health Check  │              │ • Health Check  │      │   │
│  │  └─────────────────┘              └─────────────────┘      │   │
│  │                     │              │                       │   │
│  │  ┌─────────────────┐              │                       │   │
│  │  │    TestVM       │              │                       │   │
│  │  │                 │              │                       │   │
│  │  │ • Client VM     │──────────────┘                       │   │
│  │  │ • Load Balancer │                                       │   │
│  │  │   Testing       │                                       │   │
│  │  └─────────────────┘                                       │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                             │                                      │
│                             ▼                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                  NAT Gateway                                │   │
│  │              (lb-nat-gateway)                               │   │
│  │                                                             │   │
│  │  • Outbound internet connectivity                          │   │
│  │  • Static public IP                                        │   │
│  │  • SNAT for backend VMs                                    │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
                         Internet

Inbound Flow: Internet ──► Public LB ──► Backend VMs
Outbound Flow: Backend VMs ──► NAT Gateway ──► Internet
Management: Azure Bastion ──► All VMs (RDP)
```

### Key Components

- **Public Load Balancer**: Internet-facing load balancing with public IP
- **Backend VMs**: Two Windows Server VMs with IIS web servers
- **NAT Gateway**: Dedicated outbound internet connectivity
- **Azure Bastion**: Secure RDP access without exposing VMs to internet
- **Test VM**: Client VM for load balancer testing and validation
- **High Availability**: Multi-VM backend pool with health probes

## 🔧 Prerequisites

- Azure CLI installed and configured
- Azure Bicep CLI extension
- Valid Azure subscription with Load Balancer permissions
- Understanding of public load balancing concepts

## 🚀 Quick Start

### 1. Clone and Navigate
```powershell
cd C:\Bicep_GithubCode\Simple_Pub_LB
```

### 2. Deploy the Lab

```powershell
# Create resource group
az group create --name "rg-pub-lb-lab" --location "East US"

# Deploy Public Load Balancer with backend VMs
az deployment group create \
  --resource-group "rg-pub-lb-lab" \
  --template-file main.bicep \
  --parameters adminUsername="azureuser" \
               adminPassword="ComplexPassword123!" \
               vmNamePrefix="BackendVM" \
               vmSizeOption="Overlake" \
               testVmName="TestVM" \
               useCustomImage="No"
```

### 3. Verify Deployment
```powershell
# Check Load Balancer status
az network lb show \
  --resource-group "rg-pub-lb-lab" \
  --name "lb-public" \
  --query "provisioningState"

# Get Load Balancer public IP
az network public-ip show \
  --resource-group "rg-pub-lb-lab" \
  --name "lbPublicIP" \
  --query "ipAddress" \
  --output tsv
```

## 📋 Configuration Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `adminUsername` | string | - | Administrator username for all VMs |
| `adminPassword` | securestring | - | Strong password for VM access |
| `vmNamePrefix` | string | `BackendVM` | Prefix for backend VM names |
| `vmSizeOption` | string | - | `Overlake` or `Non-Overlake` VM sizing |
| `testVmName` | string | `TestVM` | Name for the test/client VM |
| `useCustomImage` | string | `No` | Use custom gallery image or marketplace |

### Network Configuration

| Component | Address Space | Purpose |
|-----------|---------------|---------|
| **Virtual Network** | 10.0.0.0/16 | Complete network isolation |
| **Backend Subnet** | 10.0.0.0/24 | Backend VMs placement |
| **Bastion Subnet** | 10.0.2.0/24 | Azure Bastion for management |

## 🔐 Security Features

✅ **Network Security Groups**
- HTTP/HTTPS traffic management (ports 80/443)
- RDP access control (port 3389) 
- Inbound rule prioritization
- Backend VM isolation

✅ **Azure Bastion Integration**
- Secure RDP access without public IPs
- Dedicated bastion subnet
- Managed security for administrative access
- No exposed management ports

✅ **Load Balancer Security**
- Health probe monitoring
- Automatic failover capabilities
- Backend pool isolation
- Public IP with controlled access

✅ **NAT Gateway Benefits**
- Dedicated outbound IP addresses
- Improved security for outbound connections
- Better SNAT port management
- Reduced risk of port exhaustion

## 📊 Resource Overview

| Resource Type | Name | Purpose | Configuration |
|---------------|------|---------|---------------|
| Public Load Balancer | lb-public | Internet traffic distribution | Standard SKU |
| Public IP | lbPublicIP | Load balancer frontend | Static allocation |
| Backend VMs | BackendVM1, BackendVM2 | Web servers | Windows Server + IIS |
| Test VM | TestVM | Load balancer testing | Client machine |
| NAT Gateway | lb-nat-gateway | Outbound connectivity | Static public IP |
| Azure Bastion | bastion-host | Secure management | Dedicated subnet |

## 🧪 Testing & Validation

### 1. Web Application Testing
```powershell
# Get Load Balancer public IP
$lbIP = az network public-ip show --resource-group "rg-pub-lb-lab" --name "lbPublicIP" --query "ipAddress" --output tsv

# Test web application
curl http://$lbIP
```

### 2. Load Balancing Verification
```powershell
# Test multiple requests to verify distribution
for ($i=1; $i -le 20; $i++) {
    $response = Invoke-WebRequest -Uri "http://$lbIP" -UseBasicParsing
    Write-Host "Request $i - Response from: $($response.Content.Substring(0,50))"
    Start-Sleep 1
}
```

### 3. Health Probe Testing
```powershell
# Check backend pool health
az network lb show \
  --resource-group "rg-pub-lb-lab" \
  --name "lb-public" \
  --query "backendAddressPools[0].backendIPConfigurations[*].{Name:id,State:provisioningState}"
```

## 🧹 Cleanup

### Remove All Resources
```powershell
# Delete the entire resource group
az group delete --name "rg-pub-lb-lab" --yes --no-wait
```

## 💰 Cost Optimization Tips

💡 **Development Environment**
- Use Basic SKU load balancer for testing
- Stop VMs when not in use
- Consider spot VMs for non-production workloads

💡 **Production Considerations**
- Use Standard SKU for production workloads
- Implement autoscaling for backend VMs
- Monitor and optimize health probe frequency
- Consider Reserved Instances for predictable workloads

## 🚨 Important Notes

⚠️ **Security Considerations**
- Load balancer exposes services to the internet
- Implement proper WAF rules if serving web content
- Monitor failed connection attempts
- Use HTTPS for production applications

💰 **Cost Management**
- Load Balancer Standard SKU has fixed costs
- NAT Gateway charges for data processed
- Monitor data transfer costs
- Azure Bastion has hourly charges

---

**🎯 Lab Objective**: Deploy internet-facing load balancing infrastructure with enterprise-grade security and learn public load balancing patterns.

