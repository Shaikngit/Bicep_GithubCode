# 🔗 Private Endpoint with Private Link Service and Internal Load Balancer

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.network%2Fprivate-endpoint-private-link-service%2Fazuredeploy.json)

## 🎯 Overview

This Bicep template demonstrates Azure Private Link Service (PLS) connected to an Internal Load Balancer with backend VMs, and a Private Endpoint in a separate virtual network for consuming the private service. This architecture enables secure, private connectivity across virtual networks without internet exposure.

## 🏛️ Architecture

```
    ┌─────────────────────────────────────────┐
    │        Service Provider VNet            │
    │         (10.0.0.0/16)                  │
    │                                         │
    │  ┌───────────────────────────────────┐  │
    │  │    Frontend Subnet                │  │
    │  │     (10.0.1.0/24)                 │  │
    │  │                                   │  │
    │  │  ┌─────────────────────────────┐  │  │
    │  │  │   Private Link Service      │  │  │
    │  │  └─────────────────────────────┘  │  │
    │  │              │                    │  │
    │  └──────────────┼────────────────────┘  │
    │                 │                       │
    │  ┌──────────────▼────────────────────┐  │
    │  │    Backend Subnet                │  │
    │  │     (10.0.2.0/24)                │  │
    │  │                                  │  │
    │  │  ┌─────────────────────────────┐ │  │
    │  │  │   Internal Load Balancer   │ │  │
    │  │  └─────────────┬───────────────┘ │  │
    │  │                │                 │  │
    │  │        ┌───────┴─────────┐       │  │
    │  │        ▼                 ▼       │  │
    │  │    [Backend VM1]   [Backend VM2] │  │
    │  └──────────────────────────────────┘  │
    └─────────────────────────────────────────┘
                      │
                      ▼ (Private Connection)
    ┌─────────────────────────────────────────┐
    │        Consumer VNet                    │
    │         (10.0.0.0/24)                  │
    │                                         │
    │  ┌───────────────────────────────────┐  │
    │  │    Consumer Subnet                │  │
    │  │                                   │  │
    │  │  ┌─────────────────────────────┐  │  │
    │  │  │    Private Endpoint         │  │  │
    │  │  └─────────────────────────────┘  │  │
    │  │              │                    │  │
    │  │              ▼                    │  │
    │  │        [Consumer VM]              │  │
    │  └───────────────────────────────────┘  │
    └─────────────────────────────────────────┘
```

## 📋 Features

- **Private Link Service (PLS)**: Exposes internal service through private connectivity
- **Internal Load Balancer**: Distributes traffic across backend VMs
- **Private Endpoint**: Consumes PLS from separate virtual network
- **Cross-VNet Connectivity**: Secure communication without VNet peering
- **Windows VMs**: Service provider and consumer virtual machines
- **Network Isolation**: Complete network segmentation and security
- **Custom Images Support**: Flexible VM deployment options
- **Load Balancing**: High availability and traffic distribution

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
az group create --name rg-pls-pe --location eastus

# Deploy template
az deployment group create \
  --resource-group rg-pls-pe \
  --template-file main.bicep \
  --parameters vmAdminUsername="azureuser" \
               vmAdminPassword="SecureP@ssw0rd123!" \
               allowedRdpSourceAddress="0.0.0.0/0"
```

### PowerShell
```powershell
# Create resource group
New-AzResourceGroup -Name "rg-pls-pe" -Location "East US"

# Deploy template
New-AzResourceGroupDeployment `
  -ResourceGroupName "rg-pls-pe" `
  -TemplateFile "main.bicep" `
  -vmAdminUsername "azureuser" `
  -vmAdminPassword (ConvertTo-SecureString "SecureP@ssw0rd123!" -AsPlainText -Force) `
  -allowedRdpSourceAddress "0.0.0.0/0"
```

## 🧪 Testing & Validation

### 1. Connect to Consumer VM
```bash
# RDP to consumer VM using its public IP
# Credentials: vmAdminUsername / vmAdminPassword
```

### 2. Test Private Endpoint Connectivity
```powershell
# From Consumer VM, test connectivity to Private Endpoint
# Get Private Endpoint IP from Azure Portal
Test-NetConnection -ComputerName <private-endpoint-ip> -Port 80

# Test HTTP connectivity
Invoke-WebRequest -Uri "http://<private-endpoint-ip>"
```

### 3. Verify Service Provider VMs
```powershell
# RDP to service provider VMs
# Test IIS is running on backend VMs
Get-Service -Name "W3SVC"

# Check load balancer backend health
# Use Azure Portal to verify backend pool health
```

## 🔒 Security Features

- ✅ Private Link Service for secure service exposure
- ✅ Network isolation between provider and consumer
- ✅ No internet routing for service traffic
- ✅ Internal Load Balancer (no public exposure)
- ✅ Network Security Groups for access control
- ✅ Configurable RDP source restrictions
- ✅ Windows Firewall and IIS security

## 🏷️ Resource Tags

All resources are tagged with:
- Project: Private-Link-Service
- Environment: Demo
- Architecture: PLS-PE-ILB

## 💰 Cost Optimization

- **Private Link Service**: No additional charges
- **Private Endpoint**: ~$7.30/month
- **Load Balancer**: ~$18/month (Standard)
- **VMs**: Variable based on size selection
- **Data Processing**: Pay per GB processed

## 📊 Monitoring

### Key Metrics
- Private Link Service connection count
- Internal Load Balancer backend health
- VM performance and availability
- Network throughput and latency
- Private Endpoint connection status

### Azure Monitor Queries
```kusto
// Load Balancer Health
AzureMetrics
| where ResourceProvider == "MICROSOFT.NETWORK"
| where MetricName == "VipAvailability"
| summarize avg(Average) by bin(TimeGenerated, 5m)

// VM Performance
Perf
| where CounterName == "% Processor Time"
| summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
```

## 🔧 Customization

### Multiple Backend VMs
Modify the template to add more backend VMs to the load balancer pool.

### Additional Service Endpoints
Extend PLS to expose multiple services on different ports.

### Enhanced Security
- Implement Azure Bastion for VM access
- Add Azure Firewall for advanced protection
- Configure custom NSG rules

### Load Balancer Rules
- Add health probes for different applications
- Configure multiple load balancing rules
- Implement session affinity if needed

## 🚨 Troubleshooting

### Private Endpoint Connection Issues
```powershell
# Check Private Endpoint status
Get-AzPrivateEndpointConnection

# Verify DNS resolution
nslookup <service-fqdn>
```

### Load Balancer Health Problems
```bash
# Check backend pool health in Azure Portal
# Verify health probe configuration
# Test connectivity to backend VMs directly
```

### VM Connectivity Issues
```powershell
# Test RDP connectivity
Test-NetConnection -ComputerName <vm-ip> -Port 3389

# Check NSG rules
# Verify public IP configuration
```

## 📚 Related Resources

- [Azure Private Link Service Documentation](https://docs.microsoft.com/azure/private-link/private-link-service-overview)
- [Azure Private Endpoint Documentation](https://docs.microsoft.com/azure/private-link/private-endpoint-overview)
- [Azure Load Balancer Documentation](https://docs.microsoft.com/azure/load-balancer/)
- [Azure Virtual Network Documentation](https://docs.microsoft.com/azure/virtual-network/)

---

*This template demonstrates advanced Azure networking patterns for secure, private service connectivity across virtual networks.*Terminal

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
