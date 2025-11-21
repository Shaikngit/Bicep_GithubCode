# 🌐 Public Load Balancer with IPv6 Support

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.network%2Floadbalancer-standard-create%2Fazuredeploy.json)

## 🎯 Overview

This Bicep template deploys a Standard Public Load Balancer with dual-stack IPv4/IPv6 support, backend virtual machines, and comprehensive network infrastructure. This architecture demonstrates modern networking capabilities for global applications requiring both IPv4 and IPv6 connectivity.

## 🏗️ Architecture

```
    Internet (IPv4 + IPv6)
           │
           ▼
    ┌──────────────────────┐
    │  Public Load Balancer │
    │   • IPv4 Frontend     │
    │   • IPv6 Frontend     │
    │   • Standard SKU      │
    └──────────┬───────────┘
               │
    ┌──────────▼─────────────────────────────────────────────────────────────────┐
    │          Virtual Network                         │
    │        (Dual Stack)                              │
    │  • IPv4: 10.0.0.0/16                           │
    │  • IPv6: ace:cab:deca::/48                      │
    │                                                  │
    │  ┌─────────────────────────────────────────────────────────────────────┐ │
    │  │            Subnet                           │ │
    │  │  • IPv4: 10.0.0.0/24                       │ │
    │  │  • IPv6: ace:cab:deca:deed::/64             │ │
    │  │                                             │ │
    │  │  ┌─────────────┐ ┌─────────────┐           │ │
    │  │  │  Backend    │ │  Backend    │           │ │
    │  │  │    VM 1     │ │    VM 2     │           │ │
    │  │  │ IPv4 + IPv6 │ │ IPv4 + IPv6 │           │ │
    │  │  └─────────────┘ └─────────────┘           │ │
    │  │           │               │                 │ │
    │  │           └───────┬───────┘                 │ │
    │  │                   │                         │ │
    │  │         ┌─────────▼─────────┐              │ │
    │  │         │    Test VM         │              │ │
    │  │         │  (Client Testing)  │              │ │
    │  │         └────────────────────┘              │ │
    │  └─────────────────────────────────────────────────────────────────────┘ │
    └────────────────────────────────────────────────────────────────────────────┘
                           │
                           ▼
               ┌───────────────────────┐
               │     Storage Account     │
               │   • IPv4 Accessible     │
               │   • Standard LRS        │
               └───────────────────────┘
```

## 📋 Features

- **Dual-Stack Networking**: IPv4 and IPv6 support throughout the infrastructure
- **Standard Public Load Balancer**: High availability with multiple frontends
- **Backend VMs**: Windows VMs with dual-stack network configuration
- **Health Probes**: HTTP health monitoring on port 80
- **Test VM**: Client VM for connectivity validation
- **Storage Integration**: Storage account for application data
- **Network Security**: NSG with rules for both IP versions
- **Custom Images**: Support for custom VM images

## 🔧 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| adminUsername | string | - | Administrator username for VMs |
| adminPassword | securestring | - | Administrator password for VMs |
| location | string | resourceGroup().location | Azure region for deployment |
| testVmName | string | TestVM | Name of the test virtual machine |
| vmSizeOption | string | Non-Overlake | VM size option (Overlake/Non-Overlake) |
| useCustomImage | string | No | Use custom VM image (Yes/No) |
| customImageResourceId | string | - | Resource ID of custom image |

## 🚀 Quick Deploy

### Azure CLI
```bash
# Create resource group
az group create --name rg-lb-ipv6 --location eastus

# Deploy template
az deployment group create \
  --resource-group rg-lb-ipv6 \
  --template-file main.bicep \
  --parameters adminUsername="azureuser" \
               adminPassword="SecureP@ssw0rd123!"
```

### PowerShell
```powershell
# Create resource group
New-AzResourceGroup -Name "rg-lb-ipv6" -Location "East US"

# Deploy template
New-AzResourceGroupDeployment `
  -ResourceGroupName "rg-lb-ipv6" `
  -TemplateFile "main.bicep" `
  -adminUsername "azureuser" `
  -adminPassword (ConvertTo-SecureString "SecureP@ssw0rd123!" -AsPlainText -Force)
```

## 🧪 Testing & Validation

### 1. Test IPv4 Connectivity
```bash
# Test IPv4 load balancer
curl http://<ipv4-lb-ip>

# Multiple requests to test load distribution
for i in {1..10}; do curl http://<ipv4-lb-ip>; done
```

### 2. Test IPv6 Connectivity
```bash
# Test IPv6 load balancer (requires IPv6-enabled client)
curl -6 http://[<ipv6-lb-ip>]

# Test from IPv6-capable network
ping6 <ipv6-lb-ip>
```

### 3. Validate Backend VMs
```powershell
# RDP to test VM and verify backend connectivity
# Test both IPv4 and IPv6 addresses of backend VMs
Test-NetConnection -ComputerName <backend-vm-ipv4> -Port 80
Test-NetConnection -ComputerName <backend-vm-ipv6> -Port 80
```

### 4. Network Configuration Validation
```powershell
# From backend VMs, check network configuration
ipconfig /all

# Verify IPv6 configuration
netsh interface ipv6 show config
```

## 🔒 Security Features

- ✅ Standard Load Balancer with DDoS protection
- ✅ Network Security Groups for both IPv4 and IPv6
- ✅ Dual-stack security rules and policies
- ✅ Private backend VM communication
- ✅ Health probes for backend monitoring
- ✅ Windows Firewall on all VMs
- ✅ Configurable access restrictions

## 🏷️ Resource Tags

All resources are tagged with:
- Project: Public-LB-IPv6
- Environment: Demo
- Network: Dual-Stack
- Protocol: IPv4-IPv6

## 💰 Cost Optimization

- **Standard Load Balancer**: ~$18/month + data processing
- **Virtual Machines**: Variable based on size selection
- **IPv6 Public IPs**: Same cost as IPv4 public IPs
- **Storage Account**: Pay-as-you-use pricing
- **Bandwidth**: No additional charges for IPv6 traffic

## 📊 IPv4 vs IPv6 Comparison

| Feature | IPv4 | IPv6 | Benefits |
|---------|------|------|----------|
| **Address Space** | 32-bit (limited) | 128-bit (virtually unlimited) | Future scalability |
| **Performance** | Mature routing | Modern, efficient | Reduced NAT overhead |
| **Security** | Retrofit security | Built-in IPSec | Enhanced security |
| **Adoption** | Universal | Growing rapidly | Global accessibility |

## 📊 Monitoring

Monitor your dual-stack deployment:
- Load Balancer metrics for both IP versions
- Backend pool health across IPv4/IPv6
- Network throughput and latency comparison
- IPv6 adoption and usage patterns

## 🔧 Customization

### IPv6 Configuration
```bicep
// Configure additional IPv6 subnets
// Implement IPv6 routing policies
// Add IPv6-specific security rules
```

### Load Balancer Enhancements
- Configure session affinity for both IP versions
- Add multiple backend pools for different services
- Implement cross-region load balancing

### Security Hardening
- IPv6-specific Network Security Group rules
- Dual-stack Azure Firewall integration
- IPv6 threat protection policies

## 🚨 Troubleshooting

### IPv4 Connectivity Issues
```bash
# Standard IPv4 troubleshooting
ping <ipv4-lb-ip>
traceroute <ipv4-lb-ip>
```

### IPv6 Connectivity Issues
```bash
# IPv6-specific troubleshooting
ping6 <ipv6-lb-ip>
traceroute6 <ipv6-lb-ip>

# Check IPv6 configuration
ip -6 addr show
ip -6 route show
```

### Load Balancer Issues
```bash
# Check load balancer configuration
az network lb show --name <lb-name> --resource-group <rg>

# Verify backend pool health
az network lb probe show --lb-name <lb-name> --name <probe-name> --resource-group <rg>
```

### Network Configuration
```powershell
# Windows IPv6 troubleshooting
netsh interface ipv6 show config
netsh interface ipv6 show route

# Test dual-stack connectivity
Test-NetConnection -ComputerName <target> -Port 80 -InformationLevel Detailed
```

## 🌍 IPv6 Benefits for Global Applications

### Performance Advantages
- **Reduced Latency**: Direct routing without NAT
- **Better Performance**: Native end-to-end connectivity
- **Improved Scalability**: Unlimited address space

### Future Readiness
- **Mobile Networks**: IPv6-first mobile carriers
- **IoT Integration**: Native IPv6 support for IoT devices
- **Global Reach**: Access to IPv6-only networks

## 📚 Related Resources

- [Azure Load Balancer IPv6 Documentation](https://docs.microsoft.com/azure/load-balancer/load-balancer-ipv6-overview)
- [IPv6 for Azure Virtual Network](https://docs.microsoft.com/azure/virtual-network/ipv6-overview)
- [Dual-stack IPv4/IPv6 Applications](https://docs.microsoft.com/azure/virtual-network/ipv6-dual-stack-standard-load-balancer)
- [IPv6 Security Best Practices](https://docs.microsoft.com/azure/security/fundamentals/network-best-practices)

---

*This template demonstrates modern dual-stack networking capabilities essential for global applications and future-ready infrastructure.*