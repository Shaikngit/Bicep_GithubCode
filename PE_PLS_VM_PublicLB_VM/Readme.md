# 🌐 Private Endpoint with Private Link Service and Public Load Balancer

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.network%2Fprivate-link-service%2Fazuredeploy.json)

## 🎯 Overview

This Bicep template demonstrates Azure Private Link Service (PLS) connected to a Public Load Balancer with backend VMs, and a Private Endpoint in a separate virtual network for consuming the service. This architecture enables secure, private connectivity to publicly accessible services while maintaining network isolation.

## 🏛️ Architecture

```
      Internet
         │
         ▼
    ┌──────────────┐
    │Public LB IP│
    └──────┬───────┘
         │
         ▼
┌─────────────────────────────────────────┐
│        Service Provider VNet            │
│         (10.0.0.0/16)                  │
│                                         │
│  ┌─────────────────────────────────────┐ │
│  │    Frontend Subnet                 │ │
│  │     (10.0.1.0/24)                 │ │
│  │                                   │ │
│  │  ┌─────────────────────────────────┐│ │
│  │  │   Private Link Service      ││ │
│  │  └─────────────────────────────────┘│ │
│  │              │                    │ │
│  └──────────────┼────────────────────┘ │
│                 │                       │
│  ┌──────────────▼────────────────────┐ │
│  │    Backend Subnet                │ │
│  │     (10.0.2.0/24)                │ │
│  │                                  │ │
│  │  ┌─────────────────────────────────┐ │ │
│  │  │    Public Load Balancer     │ │ │
│  │  └─────────────┬───────────────┘ │ │
│  │                │                 │ │
│  │        ┌───────┴──┬──────┐       │ │
│  │        ▼          ▼      ▼       │ │
│  │    [Backend VM1]   [Backend VM2] │ │
│  └──────────────────────────────────┘ │
└─────────────────────────────────────────┘
                      │
                      ▼ (Private Connection)
┌─────────────────────────────────────────┐
│        Consumer VNet                    │
│         (10.0.0.0/24)                  │
│                                         │
│  ┌─────────────────────────────────────┐ │
│  │    Consumer Subnet                │ │
│  │                                   │ │
│  │  ┌─────────────────────────────────┐│ │
│  │  │    Private Endpoint         ││ │
│  │  └─────────────────────────────────┘│ │
│  │              │                    │ │
│  │              ▼                    │ │
│  │        [Consumer VM]              │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## 📋 Features

- **Private Link Service (PLS)**: Exposes public load balancer through private connectivity
- **Public Load Balancer**: Internet-facing load balancer with Standard SKU
- **Private Endpoint**: Consumes PLS from separate virtual network
- **Cross-VNet Connectivity**: Secure communication without VNet peering
- **Windows VMs**: Service provider and consumer virtual machines
- **Dual Access Pattern**: Public internet + private endpoint access
- **Custom Images Support**: Flexible VM deployment options
- **High Availability**: Load balancing with health probes

## 🔧 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| vmAdminUsername | string | - | Administrator username for VMs |
| vmAdminPassword | securestring | - | Administrator password for VMs |
| vmSizeOption | string | Non-Overlake | VM size option (Overlake/Non-Overlake) |
| location | string | resourceGroup().location | Azure region for deployment |
| useCustomImage | string | No | Use custom VM image (Yes/No) |
| customImageResourceId | string | - | Resource ID of custom image |
| allowedRdpSourceAddress | string | - | Source IP/CIDR for RDP access |

## 🚀 Quick Deploy

### Azure CLI
```bash
# Create resource group
az group create --name rg-pls-public --location southeastasia

# Deploy template
az deployment group create \
  --resource-group rg-pls-public \
  --template-file main.bicep \
  --parameters vmAdminUsername="azureuser" \
               vmAdminPassword="SecureP@ssw0rd123!" \
               allowedRdpSourceAddress="0.0.0.0/0"
```

### PowerShell
```powershell
# Create resource group
New-AzResourceGroup -Name "rg-pls-public" -Location "East US"

# Deploy template
New-AzResourceGroupDeployment `
  -ResourceGroupName "rg-pls-public" `
  -TemplateFile "main.bicep" `
  -vmAdminUsername "azureuser" `
  -vmAdminPassword (ConvertTo-SecureString "SecureP@ssw0rd123!" -AsPlainText -Force) `
  -allowedRdpSourceAddress "0.0.0.0/0"
```

## 🧪 Testing & Validation

### 1. Test Public Load Balancer Access
```bash
# Test public load balancer from internet
curl http://<public-lb-ip>

# Multiple requests to test load distribution
for i in {1..10}; do curl http://<public-lb-ip>; done
```

### 2. Test Private Endpoint Access
```powershell
# RDP to consumer VM
# Test private endpoint connectivity
Test-NetConnection -ComputerName <private-endpoint-ip> -Port 80

# Test HTTP through private endpoint
Invoke-WebRequest -Uri "http://<private-endpoint-ip>"
```

### 3. Compare Access Patterns
```powershell
# From Consumer VM, compare response times
Measure-Command { Invoke-WebRequest -Uri "http://<public-lb-ip>" }
Measure-Command { Invoke-WebRequest -Uri "http://<private-endpoint-ip>" }
```

## 🔒 Security Features

- ✅ Dual access pattern (public + private)
- ✅ Private Link Service for secure connectivity
- ✅ Network isolation between provider and consumer
- ✅ Public Load Balancer with DDoS protection
- ✅ Network Security Groups for traffic control
- ✅ Configurable RDP source restrictions
- ✅ Private endpoint traffic bypasses internet

## 🏷️ Resource Tags

All resources are tagged with:
- Project: Private-Link-Public-LB
- Environment: Demo
- Architecture: PLS-PE-PublicLB

## 💰 Cost Optimization

- **Public Load Balancer**: ~$18/month (Standard)
- **Private Link Service**: No additional charges
- **Private Endpoint**: ~$7.30/month
- **Public IPs**: ~$4/month per IP
- **VMs**: Variable based on size selection
- **Data Processing**: Pay per GB processed

## 📊 Monitoring

Monitor your dual-access deployment:
- Public Load Balancer availability and throughput
- Private Link Service connection count
- Private Endpoint connection status
- VM backend pool health
- Network latency comparison (public vs private)

## 🔧 Customization

### Multiple Access Patterns
- Configure additional private endpoints for different consumers
- Add Application Gateway for advanced routing
- Implement Azure Front Door for global load balancing

## 🚨 Troubleshooting

### Public Load Balancer Issues
```bash
# Check public IP configuration
az network public-ip show --name <public-ip-name> --resource-group <rg>

# Verify load balancer rules
az network lb show --name <lb-name> --resource-group <rg>
```

### Private Endpoint Connectivity
```powershell
# Test private endpoint DNS resolution
nslookup <private-endpoint-fqdn>

# Check private endpoint status
Get-AzPrivateEndpointConnection
```

## 🔄 Access Pattern Comparison

| Access Type | Route | Security | Performance | Use Case |
|-------------|--------|-----------|-------------|----------|
| **Public LB** | Internet → Public IP → VMs | DDoS Protection, NSG | Variable latency | External clients |
| **Private Endpoint** | VNet → Private IP → VMs | Private backbone | Lower latency | Internal/partner access |

## 📚 Related Resources

- [Azure Private Link Service Documentation](https://docs.microsoft.com/azure/private-link/private-link-service-overview)
- [Azure Load Balancer Documentation](https://docs.microsoft.com/azure/load-balancer/)
- [Private Endpoint Documentation](https://docs.microsoft.com/azure/private-link/private-endpoint-overview)

---

*This template demonstrates hybrid connectivity patterns combining public internet access with private, secure connectivity for different consumer types.* 

## File Structure

- `main.bicep`: The main Bicep script that defines the infrastructure.
  
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
To deploy the resources with custom image defined in the `main.bicep` file, use the following command:

```Terminal 

az deployment group create --resource-group peplspublicshaiknlab --template-file main.bicep --parameters useCustomImage=Yes
```

## Input 

- Admin Username
- Admin Password
- Public IP Address of your machine to allow RDP

## Output

- Public IP Address of the VM to connect via RDP

## Clean up deployment

To remove the resources that were created as part of this deployment, use the following command:

```Terminal
az group delete --name <resourcegroupname> --yes --no-wait
```

## Notes

Multiple Azure resources are defined in the Bicep file:

- Microsoft.Network/virtualNetworks: There's one virtual network for each virtual machine.
- Microsoft.Network/loadBalancers: The load balancer that exposes the virtual machines that host the service.
- Microsoft.Network/networkInterfaces: There are two network interfaces, one for each virtual machine.
- Microsoft.Compute/virtualMachines: There are two virtual machines, one that hosts the service and one that tests the connection to the private endpoint.
- Microsoft.Compute/virtualMachines/extensions: The extension that installs a web server.
- Microsoft.Network/privateLinkServices: The private link service to expose the service.
- Microsoft.Network/publicIpAddresses: There is a public IP address for the test virtual machine.
- Microsoft.Network/privateendpoints: The private endpoint to access the service.

## Connect 

## Connect to a VM from the Internet

There are two VMs in this lab: mySvcVm{uniqueid} and myCnsmrvm{uniqueid}. You'll connect to myCnsmrvm{uniqueid} from the internet and access the HTTP service privately from the VM. mySvcVm{uniqueid} hosts the HTTP service which is behind the private link service and exposed through the private endpoint. myCnsmrvm{uniqueid} is used to access the HTTP service privately.

Connect to the VM `myCnsmrvm{uniqueid}` from the internet as follows:

Access the http service privately from the VM
## Access the HTTP Service Privately from the VM

Here's how to connect to the HTTP service from the VM by using the private endpoint:
Go to the Remote Desktop of myConsumerVm{uniqueid}.
Open a browser, and enter the private endpoint address: http://10.0.0.5/.
The default IIS page appears.
