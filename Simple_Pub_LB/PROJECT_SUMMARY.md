# Azure Public Load Balancer with Backend VMs Lab - Project Structure

## 📁 Complete File Structure

```
Simple_Pub_LB/
├── main.bicep                 # Main Bicep template for Public Load Balancer deployment
├── deploy.ps1                 # PowerShell deployment script
├── README.md                  # Comprehensive lab guide and documentation
└── PROJECT_SUMMARY.md         # This project structure overview
```

## 🎯 Key Features Delivered

✅ **Public Load Balancer Infrastructure**
- Standard SKU load balancer with public IP frontend
- Backend pool with multiple Windows Server VMs
- Health probe configuration for automatic failover
- Load balancing rules for HTTP/HTTPS traffic

✅ **High Availability Backend**
- Two Windows Server VMs with IIS installed
- Automatic VM configuration with CustomScript extension
- Network Security Groups with controlled access
- Backend pool distribution across availability zones

✅ **Secure Network Architecture**
- Virtual Network (10.0.0.0/16) with subnet segmentation
- Azure Bastion for secure RDP access (10.0.2.0/24)
- NAT Gateway for dedicated outbound connectivity
- Network isolation between management and data planes

✅ **Test Environment**
- Dedicated test VM for load balancer validation
- Pre-configured client machine for testing scenarios
- Administrative access through Azure Bastion
- Comprehensive testing capabilities

✅ **Outbound Connectivity**
- NAT Gateway with static public IP
- Improved SNAT port management
- Dedicated outbound IP addresses
- Enhanced security for outbound connections

✅ **Enterprise Security**
- No direct VM public IPs (except load balancer)
- Controlled inbound access through NSG rules
- Azure Bastion for secure management access
- Network segmentation best practices

## 🚀 Quick Start Commands

```powershell
# Navigate to project directory
cd C:\Bicep_GithubCode\Simple_Pub_LB

# Deploy complete Public Load Balancer solution
./deploy.ps1 -ResourceGroupName "rg-pub-lb-lab" `
             -AdminUsername "azureuser" `
             -AdminPassword "ComplexPassword123!" `
             -VMNamePrefix "BackendVM" `
             -VMSizeOption "Overlake" `
             -TestVMName "TestVM" `
             -UseCustomImage "No"

# Get Load Balancer public IP
$lbIP = az network public-ip show --resource-group "rg-pub-lb-lab" --name "lbPublicIP" --query "ipAddress" --output tsv
Write-Host "Load Balancer IP: $lbIP"

# Test web application
curl http://$lbIP

# Monitor backend health
az network lb show --resource-group "rg-pub-lb-lab" --name "lb-public" --query "backendAddressPools"

# Clean up when done
./cleanup.ps1 -ResourceGroupName "rg-pub-lb-lab"
```

## 📊 Infrastructure Configuration

| Component | Specification | Purpose | Network |
|-----------|---------------|---------|---------|
| **Public Load Balancer** | Standard SKU | Internet traffic distribution | Public IP frontend |
| **Backend VMs (2x)** | Windows Server + IIS | Web application servers | Private IPs in backend subnet |
| **Test VM** | Windows Server | Load balancer testing | Private IP in backend subnet |
| **Azure Bastion** | Standard | Secure management | AzureBastionSubnet |
| **NAT Gateway** | Standard | Outbound connectivity | Static public IP |
| **Virtual Network** | 10.0.0.0/16 | Network isolation | Multi-subnet architecture |

## 🔧 Template Parameters Analysis

### Core Parameters
- **adminUsername**: Administrator account for all VMs
- **adminPassword**: Secure password (marked as @secure())
- **vmNamePrefix**: Naming prefix for backend VMs (default: "BackendVM")
- **vmSizeOption**: VM size selection ('Overlake' vs 'Non-Overlake')

### Network Configuration
- **vNetAddressPrefix**: Virtual network CIDR (default: 10.0.0.0/16)
- **vNetSubnetAddressPrefix**: Backend subnet CIDR (default: 10.0.0.0/24)
- **vNetBastionSubnetAddressPrefix**: Bastion subnet CIDR (default: 10.0.2.0/24)

### Load Balancer Settings
- **lbPublicIpAddressName**: Public IP name (default: "lbPublicIP")
- **testVmName**: Test VM identifier (default: "TestVM")
- **useCustomImage**: Gallery vs marketplace image selection

## 🏗️ Network Architecture Flow

```
┌─────────────────┐
│    Internet     │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│  Public Load    │
│   Balancer      │
│   (Frontend)    │
└─────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│         Backend Pool            │
│  ┌─────────────────────────────┐│
│  │ BackendVM1    BackendVM2    ││
│  │   (IIS)        (IIS)        ││
│  │ 10.0.0.x      10.0.0.y      ││
│  └─────────────────────────────┘│
└─────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│   NAT Gateway   │
│   (Outbound)    │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│    Internet     │
│   (Outbound)    │
└─────────────────┘
```

## 🧪 Comprehensive Testing Matrix

### 1. Load Balancing Verification
```powershell
# Distribution testing
for ($i=1; $i -le 50; $i++) {
    $response = Invoke-WebRequest "http://$lbIP" -UseBasicParsing
    $serverInfo = ($response.Content | Select-String "Server:.*").Matches.Value
    Write-Host "Request $i - $serverInfo"
    Start-Sleep 0.5
}
```

### 2. Health Probe Testing
```powershell
# Simulate backend failure
az vm stop --resource-group "rg-pub-lb-lab" --name "BackendVM1"

# Verify failover behavior
for ($i=1; $i -le 10; $i++) {
    curl http://$lbIP
    Start-Sleep 2
}

# Restore service
az vm start --resource-group "rg-pub-lb-lab" --name "BackendVM1"
```

### 3. Performance Testing
```powershell
# Concurrent connections test
$jobs = @()
for ($i=1; $i -le 10; $i++) {
    $jobs += Start-Job -ScriptBlock {
        param($url)
        for ($j=1; $j -le 20; $j++) {
            Invoke-WebRequest $url -UseBasicParsing | Out-Null
            Start-Sleep 0.1
        }
    } -ArgumentList "http://$lbIP"
}

# Wait for completion and measure performance
$jobs | Wait-Job | Receive-Job
```

### 4. Security Validation
```powershell
# Verify NAT Gateway outbound IP
# From TestVM or Backend VMs
curl ifconfig.me  # Should return NAT Gateway IP

# Test RDP access (should fail from internet)
Test-NetConnection $lbIP -Port 3389  # Should timeout

# Verify Bastion access (should succeed)
# Use Azure portal to connect via Bastion
```

## 💰 Cost Breakdown & Optimization

### Monthly Cost Estimates (USD)
| Component | SKU | Estimated Cost | Optimization Notes |
|-----------|-----|----------------|-------------------|
| **Load Balancer** | Standard | ~$25/month | Fixed cost for LB rules |
| **Backend VMs (2x)** | Standard_D2s_v4/v5 | ~$140/month | Use spot instances for dev |
| **Test VM** | Standard_D2s_v4/v5 | ~$70/month | Stop when not testing |
| **NAT Gateway** | Standard | ~$45/month + data | Monitor data transfer |
| **Azure Bastion** | Standard | ~$87/month | Essential for security |
| **Storage** | Premium SSD | ~$45/month | OS disks for all VMs |
| **Public IPs (2x)** | Static | ~$7/month | LB and NAT Gateway |

**Total Estimated**: ~$419/month

### Cost Optimization Strategies
💡 **Development Optimizations**
```powershell
# Stop VMs during non-business hours
az vm deallocate --ids $(az vm list -g "rg-pub-lb-lab" --query "[].id" -o tsv)

# Use scheduled shutdown
az vm auto-shutdown --resource-group "rg-pub-lb-lab" --name "BackendVM1" --time 1900
```

💡 **Production Optimizations**
- Implement VM Scale Sets for automatic scaling
- Use Azure Reserved Instances (up to 72% savings)
- Monitor and right-size based on actual usage
- Consider Azure Hybrid Benefit for Windows licensing

## 🛡️ Security Best Practices Implementation

### Network Security Configuration
```bicep
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${vmNamePrefix}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTPSInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1001
          direction: 'Inbound'
        }
      }
    ]
  }
}
```

### Load Balancer Health Probe
```bicep
healthProbes: [
  {
    name: 'healthProbe'
    properties: {
      protocol: 'Http'
      port: 80
      intervalInSeconds: 5
      numberOfProbes: 2
      requestPath: '/'
    }
  }
]
```

## 🔄 Operational Management

### Monitoring & Alerting
```powershell
# Enable diagnostic logs
az monitor diagnostic-settings create \
  --name "lb-diagnostics" \
  --resource "/subscriptions/{subscription}/resourceGroups/rg-pub-lb-lab/providers/Microsoft.Network/loadBalancers/lb-public" \
  --logs '[{"category":"LoadBalancerAlertEvent","enabled":true},{"category":"LoadBalancerProbeHealthStatus","enabled":true}]' \
  --metrics '[{"category":"AllMetrics","enabled":true}]'
```

### Scaling Operations
```powershell
# Add additional backend VM
az vm create \
  --resource-group "rg-pub-lb-lab" \
  --name "BackendVM3" \
  --image "Win2019Datacenter" \
  --admin-username "azureuser" \
  --admin-password "ComplexPassword123!" \
  --vnet-name "lb-vnet" \
  --subnet "backendSubnet" \
  --lb-name "lb-public" \
  --lb-backend-pool-name "backendPool"
```

### Backup & Recovery
```powershell
# Enable backup for VMs
az backup protection enable-for-vm \
  --resource-group "rg-pub-lb-lab" \
  --vault-name "lb-backup-vault" \
  --vm "BackendVM1" \
  --policy-name "DefaultPolicy"
```

---

**🎯 Lab Success Criteria**: Production-ready public load balancing infrastructure with comprehensive security, monitoring, and operational excellence capabilities.