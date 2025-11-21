# Azure Firewall DNAT with Internal Load Balancer Lab - Project Structure

## 📁 Complete File Structure

```
Firewall_DNAT_Simple_Int_LB/
├── main.bicep                 # Main Bicep template for Firewall + Internal LB
├── deploy.ps1                 # PowerShell deployment script
├── validate.ps1               # Template validation script
├── cleanup.ps1                # Resource cleanup automation
├── README.md                  # Comprehensive deployment guide
└── PROJECT_SUMMARY.md         # This project structure overview
```

## 🎯 Key Features Delivered

✅ **Azure Firewall Infrastructure**
- Azure Firewall Standard with dedicated subnet
- Centralized firewall policy management
- DNAT rules for internet-to-internal traffic translation
- Public IP for internet-facing services

✅ **Hub-Spoke Network Architecture**
- Hub VNet (192.168.0.0/16) for security services
- Spoke VNet (10.0.0.0/16) for workload resources
- VNet peering for secure inter-network communication
- Network segmentation and isolation

✅ **Internal Load Balancer Setup**
- Private IP load balancer (10.0.0.6) in spoke network
- Backend pool with multiple Windows Server VMs
- Health probe configuration for automatic failover
- Load balancing rules for HTTP/HTTPS traffic

✅ **DNAT Rules Configuration**
- Port 80 translation from Firewall to Internal LB
- Port 443 translation for HTTPS traffic
- Centralized policy-based rule management
- Secure exposure of internal services

✅ **Backend Virtual Machines**
- Two Windows Server VMs with IIS configuration
- Automatic web server setup via CustomScript extension
- Network Security Groups for controlled access
- Test VM for internal connectivity validation

✅ **Secure Management Access**
- Azure Bastion for RDP without public IPs
- Dedicated bastion subnet (10.0.2.0/24)
- NAT Gateway for outbound connectivity
- Comprehensive network security posture

## 🚀 Quick Start Commands

```powershell
# Navigate to project directory
cd C:\Bicep_GithubCode\Firewall_DNAT_Simple_Int_LB

# Validate template (recommended first)
./validate.ps1

# Deploy complete Firewall + Internal LB solution
./deploy.ps1 -ResourceGroupName "rg-fw-dnat-lab" `
             -AdminUsername "azureuser" `
             -AdminPassword "ComplexPassword123!" `
             -VMNamePrefix "BackendVM" `
             -VMSizeOption "Overlake" `
             -TestVMName "TestVM" `
             -UseCustomImage "No"

# Get Firewall public IP for testing
$fwIP = az network public-ip show --resource-group "rg-fw-dnat-lab" --name "fw-public-ip" --query "ipAddress" --output tsv
Write-Host "Firewall Public IP: $fwIP"

# Test DNAT functionality
curl http://$fwIP  # Should reach internal load balancer

# Monitor firewall logs
az monitor activity-log list --resource-group "rg-fw-dnat-lab" --max-events 50

# Clean up when done
./cleanup.ps1 -ResourceGroupName "rg-fw-dnat-lab"
```

## 📊 Network Architecture Overview

| Network Component | Address Space | Purpose | Connectivity |
|-------------------|---------------|---------|--------------|
| **Hub VNet** | 192.168.0.0/16 | Security services | Internet + Spoke peering |
| **Firewall Subnet** | 192.168.2.0/24 | Azure Firewall placement | AzureFirewallSubnet |
| **Hub Default Subnet** | 192.168.1.0/24 | Hub network resources | Internal connectivity |
| **Spoke VNet** | 10.0.0.0/16 | Workload resources | Hub peering |
| **Backend Subnet** | 10.0.0.0/24 | Load balancer & VMs | Private connectivity |
| **Bastion Subnet** | 10.0.2.0/24 | Azure Bastion | AzureBastionSubnet |

## 🔧 DNAT Rules Configuration

### Firewall Policy DNAT Rules
```bicep
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2021-03-01' = {
  name: 'fw-policy'
  location: location
  properties: {
    dnsSettings: {
      servers: []
      enableProxy: true
    }
  }
}

resource dnatRuleCollection 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-03-01' = {
  parent: firewallPolicy
  name: 'dnat-rules'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        name: 'web-dnat-rules'
        priority: 100
        action: {
          type: 'Dnat'
        }
        rules: [
          {
            ruleType: 'NatRule'
            name: 'http-to-ilb'
            translatedAddress: '10.0.0.6'  // Internal LB IP
            translatedPort: '80'
            ipProtocols: ['TCP']
            sourceAddresses: ['*']
            destinationAddresses: [firewallPublicIP.properties.ipAddress]
            destinationPorts: ['80']
          }
          {
            ruleType: 'NatRule'
            name: 'https-to-ilb'
            translatedAddress: '10.0.0.6'  // Internal LB IP
            translatedPort: '443'
            ipProtocols: ['TCP']
            sourceAddresses: ['*']
            destinationAddresses: [firewallPublicIP.properties.ipAddress]
            destinationPorts: ['443']
          }
        ]
      }
    ]
  }
}
```

## 🏗️ Traffic Flow Analysis

### Inbound Traffic Path
```
Internet Request
      │
      ▼
┌─────────────────┐
│ Azure Firewall  │ ◄─── Public IP: x.x.x.x:80
│ DNAT Rule       │      Translates to: 10.0.0.6:80
└─────────────────┘
      │
      ▼ (via VNet Peering)
┌─────────────────┐
│ Internal Load   │ ◄─── Private IP: 10.0.0.6:80
│ Balancer        │      Distributes to backend pool
└─────────────────┘
      │
      ▼
┌─────────────────┐    ┌─────────────────┐
│   BackendVM1    │    │   BackendVM2    │
│   (10.0.0.x)    │    │   (10.0.0.y)    │
│   IIS Web       │    │   IIS Web       │
└─────────────────┘    └─────────────────┘
```

### Management Access Path
```
Azure Portal/Bastion
      │
      ▼
┌─────────────────┐
│ Azure Bastion   │ ◄─── Bastion Subnet: 10.0.2.0/24
│ (Secure RDP)    │      Managed service
└─────────────────┘
      │
      ▼ (RDP over HTTPS)
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   BackendVM1    │    │   BackendVM2    │    │    TestVM       │
│   Management    │    │   Management    │    │   Management    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🧪 Comprehensive Testing Scenarios

### 1. DNAT Functionality Test
```powershell
# Get firewall public IP
$fwIP = az network public-ip show --resource-group "rg-fw-dnat-lab" --name "fw-public-ip" --query "ipAddress" --output tsv

# Test HTTP DNAT (port 80)
$response = Invoke-WebRequest -Uri "http://$fwIP" -UseBasicParsing
Write-Host "HTTP Response: $($response.StatusCode)"
Write-Host "Content Preview: $($response.Content.Substring(0,100))"

# Test HTTPS DNAT (port 443) - if SSL configured
try {
    $httpsResponse = Invoke-WebRequest -Uri "https://$fwIP" -UseBasicParsing -SkipCertificateCheck
    Write-Host "HTTPS Response: $($httpsResponse.StatusCode)"
} catch {
    Write-Host "HTTPS test result: $($_.Exception.Message)"
}
```

### 2. Load Balancer Distribution Test
```powershell
# Test load balancing through firewall
for ($i=1; $i -le 20; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://$fwIP" -UseBasicParsing
        $serverInfo = ($response.Content | Select-String "BackendVM\d+").Matches.Value
        Write-Host "Request $i - Served by: $serverInfo"
    } catch {
        Write-Host "Request $i - Failed: $($_.Exception.Message)"
    }
    Start-Sleep 1
}
```

### 3. Firewall Rule Validation
```powershell
# Check firewall policy status
az network firewall policy show --resource-group "rg-fw-dnat-lab" --name "fw-policy" --query "provisioningState"

# List DNAT rules
az network firewall policy rule-collection-group show \
  --resource-group "rg-fw-dnat-lab" \
  --policy-name "fw-policy" \
  --name "dnat-rules" \
  --query "ruleCollections[0].rules"

# Monitor firewall metrics
az monitor metrics list \
  --resource "/subscriptions/{subscription}/resourceGroups/rg-fw-dnat-lab/providers/Microsoft.Network/azureFirewalls/hub-firewall" \
  --metric "FirewallHealth" \
  --start-time $(Get-Date).AddHours(-1).ToString("yyyy-MM-ddTHH:mm:ss") \
  --end-time $(Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
```

### 4. Network Connectivity Validation
```powershell
# From TestVM, test internal connectivity to load balancer
# Connect to TestVM via Bastion, then run:
Test-NetConnection -ComputerName "10.0.0.6" -Port 80

# Test connectivity to backend VMs directly
Test-NetConnection -ComputerName "10.0.0.4" -Port 80  # BackendVM1
Test-NetConnection -ComputerName "10.0.0.5" -Port 80  # BackendVM2

# Verify outbound connectivity through NAT Gateway
curl ifconfig.me  # Should return NAT Gateway public IP
```

## 💰 Cost Analysis & Optimization

### Monthly Cost Breakdown (USD)
| Component | SKU/Type | Estimated Cost | Notes |
|-----------|----------|----------------|-------|
| **Azure Firewall** | Standard | ~$550/month | Fixed + data processing |
| **Firewall Public IP** | Standard Static | ~$4/month | Required for firewall |
| **Internal Load Balancer** | Standard | ~$25/month | Rule-based pricing |
| **Backend VMs (2x)** | Standard_D2s_v4/v5 | ~$140/month | Windows Server licensing |
| **Test VM** | Standard_D2s_v4/v5 | ~$70/month | Testing and validation |
| **Azure Bastion** | Standard | ~$87/month | Secure management |
| **NAT Gateway** | Standard | ~$45/month + data | Outbound connectivity |
| **VNet Peering** | Standard | ~$15/month | Data transfer charges |

**Total Estimated**: ~$936/month

### Cost Optimization Strategies
💡 **Development Environment**
```powershell
# Deallocate VMs during off-hours
az vm deallocate --ids $(az vm list -g "rg-fw-dnat-lab" --query "[].id" -o tsv)

# Use Azure Firewall Basic for non-production (when available)
# Consider Azure Firewall Policy inheritance for multiple environments
```

💡 **Production Optimizations**
- Implement Azure Firewall Premium for advanced threat protection
- Use Hub-spoke with multiple spokes to amortize firewall costs
- Consider Azure Firewall Manager for multi-region deployments
- Monitor and optimize firewall rule performance

## 🛡️ Security Best Practices

### Firewall Rule Management
- **Least Privilege**: Only allow necessary ports and protocols
- **Source IP Restrictions**: Limit DNAT rules to specific source ranges when possible
- **Application Rules**: Implement application-layer filtering
- **Network Rules**: Control inter-subnet communication

### Monitoring & Alerting
```powershell
# Enable diagnostic logs for Azure Firewall
az monitor diagnostic-settings create \
  --name "firewall-diagnostics" \
  --resource "/subscriptions/{subscription}/resourceGroups/rg-fw-dnat-lab/providers/Microsoft.Network/azureFirewalls/hub-firewall" \
  --logs '[{"category":"AzureFirewallApplicationRule","enabled":true},{"category":"AzureFirewallNetworkRule","enabled":true},{"category":"AzureFirewallDnsProxy","enabled":true}]' \
  --workspace "/subscriptions/{subscription}/resourceGroups/rg-fw-dnat-lab/providers/Microsoft.OperationalInsights/workspaces/fw-workspace"

# Set up alerts for firewall health
az monitor activity-log alert create \
  --name "firewall-health-alert" \
  --resource-group "rg-fw-dnat-lab" \
  --condition "category=Administrative and operationName=Microsoft.Network/azureFirewalls/write and level=Error"
```

## 🔄 Operational Procedures

### Firewall Management
```powershell
# Update DNAT rules
az network firewall policy rule-collection-group update \
  --resource-group "rg-fw-dnat-lab" \
  --policy-name "fw-policy" \
  --name "dnat-rules" \
  --rule-collections @new-rules.json

# Monitor firewall performance
az network firewall show \
  --resource-group "rg-fw-dnat-lab" \
  --name "hub-firewall" \
  --query "{State: provisioningState, IP: ipConfigurations[0].publicIPAddress.id}"
```

### Load Balancer Operations
```powershell
# Add new backend VM to load balancer
az network nic ip-config update \
  --resource-group "rg-fw-dnat-lab" \
  --nic-name "BackendVM3-nic" \
  --name "ipconfig1" \
  --lb-name "lb-internal" \
  --lb-backend-pool "backend-pool"

# Check backend health
az network lb show \
  --resource-group "rg-fw-dnat-lab" \
  --name "lb-internal" \
  --query "backendAddressPools[0].backendIPConfigurations[*].{Name:id,State:provisioningState}"
```

---

**🎯 Lab Success Criteria**: Secure internet-to-internal service access through Azure Firewall DNAT with high availability internal load balancing.