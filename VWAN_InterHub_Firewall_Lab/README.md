# Azure Virtual WAN Inter-Hub Traffic Inspection Lab 🔥

## Overview

This lab demonstrates **inter-hub traffic inspection** using Azure Virtual WAN with **Routing Intent** policies. The lab creates two Virtual Hubs in different Azure regions, each with an Azure Firewall, and configures Routing Intent to ensure all private traffic between hubs is inspected by the firewalls.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Azure Virtual WAN                                     │
│  ┌─────────────────────────────────┐    ┌─────────────────────────────────────┐ │
│  │        Southeast Asia Hub       │    │          East Asia Hub             │ │
│  │      (vhub-sea, 10.1.0.0/16)    │◄──►│      (vhub-ea, 10.2.0.0/16)        │ │
│  │                                 │    │                                     │ │
│  │  ┌─────────────────────────┐    │    │    ┌─────────────────────────┐      │ │
│  │  │    Azure Firewall       │    │    │    │    Azure Firewall       │      │ │
│  │  │   (Routing Intent)      │    │    │    │   (Routing Intent)      │      │ │
│  │  └─────────────────────────┘    │    │    └─────────────────────────┘      │ │
│  │             │                   │    │                   │                 │ │
│  │             ▼                   │    │                   ▼                 │ │
│  │  ┌─────────────────────────┐    │    │    ┌─────────────────────────┐      │ │
│  │  │     Spoke VNet          │    │    │    │     Spoke VNet          │      │ │
│  │  │  vnet-spoke-sea         │    │    │    │  vnet-spoke-ea          │      │ │
│  │  │  (10.10.0.0/16)         │    │    │    │  (10.20.0.0/16)         │      │ │
│  │  │                         │    │    │    │                         │      │ │
│  │  │  ┌─────────────────┐    │    │    │    │    ┌─────────────────┐  │      │ │
│  │  │  │   VM-SEA        │    │    │    │    │    │   VM-EA        │  │      │ │
│  │  │  │ (Ubuntu 22.04)  │    │    │    │    │    │ (Ubuntu 22.04)  │  │      │ │
│  │  │  └─────────────────┘    │    │    │    │    └─────────────────┘  │      │ │
│  │  └─────────────────────────┘    │    │    └─────────────────────────┘      │ │
│  └─────────────────────────────────┐    ┌─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘

Traffic Flow: VM-SEA ──► SEA Firewall ──► VWAN ──► EA Firewall ──► VM-EA
```

### Key Components

- **Virtual WAN**: Single Virtual WAN resource with Standard tier
- **Virtual Hubs**: Two hubs in different regions (Southeast Asia, East Asia)
- **Azure Firewalls**: Standard tier firewalls deployed in hub configuration
- **Routing Intent**: Configured to route all private traffic through firewalls
- **Spoke VNets**: Connected to respective hubs for VM workloads
- **Test VMs**: Ubuntu 22.04 LTS VMs with network testing tools

## 🔧 Prerequisites

- Azure CLI installed and configured
- Azure Bicep CLI extension
- PowerShell 7+ (for deployment script)
- An Azure subscription with appropriate permissions
- Contributor role on the subscription or resource group

### Install Prerequisites

```powershell
# Install Azure CLI
winget install Microsoft.AzureCLI

# Install Azure Bicep
az bicep install

# Login to Azure
az login

# Set your subscription (optional)
az account set --subscription "your-subscription-id"
```

## 🚀 Quick Deployment

### Option 1: PowerShell Script (Recommended)

```powershell
# Clone/download the lab files
cd C:\path\to\VWAN_InterHub_Firewall_Lab

# Run the deployment script
./deploy.ps1 -AdminPassword "YourStrongPassword123!"

# For what-if deployment (preview only)
./deploy.ps1 -AdminPassword "YourStrongPassword123!" -WhatIf

# For custom resource group and location
./deploy.ps1 -ResourceGroupName "my-vwan-lab" -Location "eastus" -AdminPassword "YourStrongPassword123!" -Force
```

### Option 2: Azure CLI Direct

```bash
# Deploy to subscription scope
az deployment sub create \
  --name vwan-interhub-lab \
  --location southeastasia \
  --template-file main.bicep \
  --parameters resourceGroupName=rg-vwan-interhub-lab \
  --parameters adminPassword='YourStrongPassword123!'
```

## 🧪 Testing Inter-Hub Traffic Inspection

### 1. Connect to VMs

After deployment, get VM connection details:

```bash
# SSH to Southeast Asia VM
ssh azureuser@<VM1_PUBLIC_IP>

# SSH to East Asia VM (from another terminal)
ssh azureuser@<VM2_PUBLIC_IP>
```

### 2. Test Hub-to-Hub Connectivity

From VM-SEA, test connectivity to VM-EA:

```bash
# Use the pre-installed test script
./test-connectivity.sh <VM_EA_PRIVATE_IP>

# Or manual tests
ping <VM_EA_PRIVATE_IP>
nc -zv <VM_EA_PRIVATE_IP> 22
traceroute <VM_EA_PRIVATE_IP>
```

### 3. Monitor Traffic Flow

Monitor network traffic on the VMs:

```bash
# Start traffic monitoring
sudo ./monitor-traffic.sh

# In another session, generate test traffic
ping <TARGET_VM_PRIVATE_IP>
```

### 4. Verify Firewall Inspection

Check Azure Firewall logs to confirm traffic inspection:

#### Using Azure Portal:
1. Navigate to Azure Firewall resource
2. Go to "Logs" under Monitoring
3. Run this KQL query:

```kql
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where TimeGenerated >= ago(1h)
| where msg_s contains "ALLOW"
| project TimeGenerated, msg_s, Protocol, SourceIP, DestinationIP, SourcePort, DestinationPort
| order by TimeGenerated desc
```

#### Using Azure CLI:
```bash
# Get firewall logs
az monitor log-analytics query \
  --workspace <LOG_ANALYTICS_WORKSPACE_ID> \
  --analytics-query "AzureDiagnostics | where Category == 'AzureFirewallNetworkRule' | limit 10"
```

## 📊 Understanding Routing Intent

### What is Routing Intent?

Routing Intent is a Virtual WAN feature that automatically configures routing to direct traffic through Network Virtual Appliances (NVAs) or Azure Firewall. With Routing Intent:

- **Private Traffic Policy**: Routes all RFC1918 private traffic through the specified next hop
- **Internet Traffic Policy**: Routes all internet-bound traffic through the specified next hop  
- **Automatic Route Propagation**: Eliminates manual route table configuration

### Routing Flow in This Lab

1. **VM-to-VM Communication**: 
   - VM-SEA (10.10.1.x) sends traffic to VM-EA (10.20.1.x)
   - Traffic hits the Virtual Hub's routing intent policy
   - Policy directs private traffic to Azure Firewall
   - Firewall inspects and allows the traffic
   - Traffic flows to destination hub via VWAN backbone
   - Destination hub's routing intent policy inspects return traffic

2. **Why Two Firewalls?**
   - Each hub requires its own firewall for Routing Intent
   - Provides regional traffic inspection and security policies
   - Enables independent security posture per region
   - Maintains optimal traffic flow patterns

### Expected Behavior

✅ **Expected Results:**
- Ping between VMs should work
- SSH connections should establish
- Traceroute shows firewall hops
- Azure Firewall logs show inspected traffic
- No direct VM-to-VM connectivity (always via firewall)

❌ **If Tests Fail:**
- Check NSG rules (should allow SSH/ICMP)
- Verify Routing Intent is configured correctly
- Confirm Azure Firewall policies allow traffic
- Check VM network interfaces and subnets

## 🔍 Troubleshooting

### Common Issues

#### 1. Deployment Failures

**Resource Quota Limits:**
```bash
# Check quotas
az vm list-usage --location southeastasia --output table
az network list-usages --location southeastasia --output table
```

**Bicep Compilation Errors:**
```bash
# Validate Bicep templates
az bicep build --file main.bicep
az deployment sub validate --template-file main.bicep --location southeastasia --parameters resourceGroupName=test
```

#### 2. Connectivity Issues

**VM Cannot Reach Internet:**
```bash
# Check VM effective routes
az network nic show-effective-route-table --ids <VM_NIC_RESOURCE_ID>

# Check firewall rules
az network firewall policy rule-collection-group list --policy-name <FIREWALL_POLICY_NAME> --resource-group <RG_NAME>
```

**Inter-Hub Communication Fails:**
```bash
# Check Virtual Hub routing
az network vhub route-table list --vhub-name <HUB_NAME> --resource-group <RG_NAME>

# Check Routing Intent status
az network vhub routing-intent list --vhub-name <HUB_NAME> --resource-group <RG_NAME>
```

### Debugging Commands

```bash
# Check deployment status
az deployment sub show --name <DEPLOYMENT_NAME>

# List all Virtual WAN components
az network vwan list --output table
az network vhub list --output table
az network firewall list --output table

# Check VM status
az vm list --resource-group <RG_NAME> --output table
az vm get-instance-view --resource-group <RG_NAME> --name <VM_NAME>

# Network troubleshooting
az network watcher test-connectivity --source-resource <VM1_ID> --dest-resource <VM2_ID> --resource-group <RG_NAME>
```

## 🧹 Cleanup

### Automated Cleanup

```powershell
# Delete the entire resource group (recommended)
az group delete --name rg-vwan-interhub-lab --yes --no-wait
```

### Manual Cleanup (if needed)

```bash
# Stop VMs first (to save costs)
az vm deallocate --resource-group rg-vwan-interhub-lab --name vnet-spoke-sea-vm
az vm deallocate --resource-group rg-vwan-interhub-lab --name vnet-spoke-ea-vm

# Delete specific resources
az network firewall delete --name azfw-vhub-sea --resource-group rg-vwan-interhub-lab
az network firewall delete --name azfw-vhub-ea --resource-group rg-vwan-interhub-lab
az network vhub delete --name vhub-sea --resource-group rg-vwan-interhub-lab
az network vhub delete --name vhub-ea --resource-group rg-vwan-interhub-lab
az network vwan delete --name vwan-interhub-lab --resource-group rg-vwan-interhub-lab
```

## 💰 Cost Estimation

### Monthly Cost Breakdown (USD)

| Component | Quantity | Unit Cost | Monthly Cost |
|-----------|----------|-----------|--------------|
| Virtual WAN Hub | 2 | $0.25/hour | ~$360 |
| Azure Firewall Standard | 2 | $1.25/hour | ~$1,800 |
| Standard_B2s VMs | 2 | $30/month | $60 |
| Public IPs | 2 | $3.65/month | $7.30 |
| Storage (Premium SSD) | 2 x 30GB | $4.81/month | $9.62 |
| **Total Estimated Cost** | | | **~$2,237/month** |

> ⚠️ **Cost Warning**: This lab includes Azure Firewall which has significant hourly costs. Remember to clean up resources when testing is complete!

### Cost Optimization Tips

1. **Use for Learning**: Deploy for short testing periods
2. **Deallocate VMs**: Stop VMs when not actively testing
3. **Basic Firewall**: Consider Firewall Basic tier for learning (if available)
4. **Regional Choice**: Some regions have lower costs

## 📚 Additional Resources

### Virtual WAN Documentation
- [Virtual WAN Overview](https://docs.microsoft.com/azure/virtual-wan/virtual-wan-about)
- [Routing Intent and Policies](https://docs.microsoft.com/azure/virtual-wan/how-to-routing-policies)
- [Virtual Hub Routing](https://docs.microsoft.com/azure/virtual-wan/about-virtual-hub-routing)

### Azure Firewall Documentation
- [Azure Firewall in Virtual Hub](https://docs.microsoft.com/azure/firewall/firewall-integration-in-hub)
- [Azure Firewall Logs and Metrics](https://docs.microsoft.com/azure/firewall/logs-and-metrics)
- [Firewall Policy Overview](https://docs.microsoft.com/azure/firewall/policy-overview)

### Bicep Documentation
- [Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Virtual WAN Bicep Templates](https://docs.microsoft.com/azure/templates/microsoft.network/virtualwans)

## 🎯 Learning Objectives

After completing this lab, you will understand:

1. **Virtual WAN Architecture**: How Virtual WAN connects multiple regions
2. **Routing Intent**: Automatic traffic steering through security appliances
3. **Azure Firewall Integration**: Hub-integrated firewall deployment
4. **Inter-Hub Communication**: How traffic flows between Virtual WAN hubs
5. **Traffic Inspection**: Network security policy enforcement points
6. **Infrastructure as Code**: Bicep template development and deployment

## 📝 Lab Extensions

Consider these extensions to enhance your learning:

1. **Add ExpressRoute**: Connect on-premises networks
2. **Site-to-Site VPN**: Add branch connectivity
3. **Application Rules**: Configure FQDN filtering
4. **Log Analytics**: Set up centralized logging
5. **Network Security Groups**: Add micro-segmentation
6. **Multiple Spokes**: Add additional spoke networks
7. **Cross-Region Workloads**: Deploy applications across regions

---

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review Azure Activity Log for deployment errors
3. Validate prerequisites and permissions
4. Ensure quotas are sufficient in target regions

**Happy Learning!** 🚀