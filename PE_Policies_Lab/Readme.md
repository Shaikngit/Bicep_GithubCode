# 🛡️ Private Endpoint Policies Lab

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.network%2Fprivate-endpoint%2Fazuredeploy.json)

## 🎯 Overview

This Bicep template creates a comprehensive lab environment demonstrating Private Endpoint policies with Azure Firewall, SQL Server with Private Endpoint, and client VM connectivity. This architecture showcases network security policies, private connectivity patterns, and firewall integration.

## 🏛️ Architecture

```
    Internet
        │
        ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                 Hub Network                               │
    │              (172.16.0.0/16)                             │
    │                                                           │
    │  ┌─────────────────┐         ┌─────────────────────────┐  │
    │  │ Firewall Subnet │         │    Management Subnet    │  │
    │  │  (172.16.1.0/24)│         │     (172.16.2.0/24)    │  │
    │  │                 │         │                         │  │
    │  │ ┌─────────────┐ │         │  ┌────────────────────┐ │  │
    │  │ │Azure        │ │         │  │    Client VM       │ │  │
    │  │ │Firewall     │ │◄────────┼──┤  (Test Client)     │ │  │
    │  │ └─────────────┘ │         │  └────────────────────┘ │  │
    │  └─────────────────┘         └─────────────────────────┘  │
    └─────────────────────────────────────────────────────────────┘
                │
                ▼ (Filtered Traffic)
    ┌─────────────────────────────────────────────────────────────┐
    │                Spoke Network                              │
    │              (10.0.0.0/16)                               │
    │                                                           │
    │  ┌─────────────────────────────────────────────────────────┐  │
    │  │              Data Subnet                            │  │
    │  │            (10.0.1.0/24)                           │  │
    │  │                                                     │  │
    │  │  ┌─────────────┐        ┌─────────────────────────┐ │  │
    │  │  │Private      │        │     SQL Server         │ │  │
    │  │  │Endpoint     │◄───────┤   (Private Access)     │ │  │
    │  │  └─────────────┘        └─────────────────────────┘ │  │
    │  └─────────────────────────────────────────────────────────┘  │
    └─────────────────────────────────────────────────────────────┘
```

## 📋 Features

- **Azure Firewall**: Network security and traffic filtering
- **Private Endpoint**: Secure SQL Server connectivity
- **SQL Server Database**: Managed database with private access
- **Client VM**: Windows test machine for connectivity validation
- **Hub-Spoke Topology**: Centralized security and routing
- **Network Policies**: Comprehensive security rule sets
- **Private DNS Integration**: Automatic DNS resolution
- **Modular Design**: Separate modules for each component

## 🔧 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| location | string | resourceGroup().location | Azure region for deployment |
| adminpassword | securestring | - | Administrator password for VMs and SQL |
| adminusername | string | - | Administrator username |
| allowedRdpSourceAddress | string | - | Source IP/CIDR for RDP access |
| vmSizeOption | string | Non-Overlake | VM size option (Overlake/Non-Overlake) |
| useCustomImage | string | No | Use custom VM image (Yes/No) |

## 🚀 Quick Deploy

### Azure CLI
```bash
# Create resource group
az group create --name rg-pe-policies --location southeastasia

# Deploy template
az deployment group create \
  --resource-group rg-pe-policies \
  --template-file main.bicep \
  --parameters adminusername="azureuser" \
               adminpassword="SecureP@ssw0rd123!" \
               allowedRdpSourceAddress="0.0.0.0/0"
```

### PowerShell
```powershell
# Create resource group
New-AzResourceGroup -Name "rg-pe-policies" -Location "East US"

# Deploy template
New-AzResourceGroupDeployment `
  -ResourceGroupName "rg-pe-policies" `
  -TemplateFile "main.bicep" `
  -adminusername "azureuser" `
  -adminpassword (ConvertTo-SecureString "SecureP@ssw0rd123!" -AsPlainText -Force) `
  -allowedRdpSourceAddress "0.0.0.0/0"
```

## 🧪 Testing & Validation

### 1. Connect to Client VM
```bash
# RDP to client VM through Azure Firewall
# Navigate to Azure Portal > Virtual Machines > ClientVM > Connect
```

### 2. Test Private Endpoint Connectivity
```powershell
# From Client VM, test SQL Server connectivity
$serverName = "<sql-server-name>.database.windows.net"
Test-NetConnection -ComputerName $serverName -Port 1433

# Test DNS resolution (should resolve to private IP)
nslookup $serverName
```

### 3. Validate Firewall Policies
```bash
# Check Azure Firewall logs
# Navigate to Azure Portal > Firewall > Logs
# Review allowed/denied connections
```

## 🔒 Security Features

- ✅ Azure Firewall for network traffic filtering
- ✅ Private Endpoint eliminates public SQL access
- ✅ Hub-spoke network topology for centralized security
- ✅ Network Security Groups for subnet-level protection
- ✅ Private DNS zones for secure name resolution
- ✅ SQL Server firewall rules for additional protection
- ✅ VNet integration for all components

## 🏷️ Resource Tags

All resources are tagged with:
- Project: Private-Endpoint-Policies
- Environment: Lab
- Architecture: Hub-Spoke-Firewall

## 💰 Cost Optimization

- **Azure Firewall**: ~$1.25/hour + data processing
- **SQL Database**: Variable based on compute and storage tier
- **Private Endpoint**: ~$7.30/month
- **Virtual Machines**: Variable based on size selection
- **VNet**: No additional charges

## 📊 Monitoring

Monitor your lab environment:
- Azure Firewall application and network rules
- SQL Database performance and connections
- Private Endpoint connection health
- VM performance metrics
- Network Security Group flow logs

## 🔧 Customization

### Firewall Rules
- Configure additional application rules
- Set up network rules for specific protocols
- Implement threat intelligence filtering

### SQL Database Configuration
- Configure different performance tiers
- Set up backup and retention policies
- Implement advanced security features

### Network Topology
- Add additional spoke networks
- Implement ExpressRoute connectivity
- Configure site-to-site VPN

## 🚨 Troubleshooting

### Firewall Connectivity Issues
```bash
# Check firewall rules
az network firewall application-rule list --firewall-name <firewall-name> --resource-group <rg>

# Review firewall logs
# Navigate to Azure Portal > Firewall > Logs
```

### SQL Connectivity Problems
```powershell
# Test SQL Server connectivity
Test-NetConnection -ComputerName <sql-server-name>.database.windows.net -Port 1433

# Check private endpoint status
Get-AzPrivateEndpointConnection
```

## 📚 Related Resources

- [Azure Firewall Documentation](https://docs.microsoft.com/azure/firewall/)
- [Private Endpoint Documentation](https://docs.microsoft.com/azure/private-link/private-endpoint-overview)
- [Azure SQL Database Documentation](https://docs.microsoft.com/azure/azure-sql/database/)
- [Hub-Spoke Network Topology](https://docs.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)

---

*This lab environment demonstrates enterprise network security patterns with private connectivity and centralized policy enforcement.*
Azure Private DNS Link

This deployment script creates three VNETs - one for the client VM, one for the SQL Server VM, and one for the private endpoint.

when the deployment is completed, you can connect to the client VM and try to connect to the SQL Server VM using the private IP address. You can also try to connect to the SQL Server VM using the private endpoint.

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
To deploy the VM resources in the `main.bicep` with custom image use the following command:

```Terminal 

az deployment group create --resource-group <resourcegroupname> --template-file main.bicep --parameters useCustomImage=Yes 

```

## Input 

- Admin Username
- Admin Password
- Public IP Address of your machine to allow RDP

## Output

- None

## Clean up deployment

To remove the resources that were created as part of this deployment, use the following command:

```Terminal
az group delete --name <resourcegroupname> --yes --no-wait
```
