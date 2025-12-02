# VWAN BGP over IPsec with Azure Firewall Lab

This lab deploys a Virtual WAN topology with BGP over IPsec connectivity between a simulated on-premises network and Azure spoke VNets, with Azure Firewall deployed in the hub.

## Architecture Overview

```
                          ┌─────────────────────────────────────────────────────┐
                          │              Virtual WAN (Standard)                  │
                          │                                                       │
   ┌──────────────────────┼───────────────────────────────────────────────────────┼──────────────────────┐
   │                      │            Virtual Hub (Southeast Asia)               │                      │
   │                      │                  10.10.0.0/24                        │                      │
   │                      │                                                       │                      │
   │                      │    ┌────────────────┐    ┌────────────────┐          │                      │
   │                      │    │  Hub VPN GW    │    │ Azure Firewall │          │                      │
   │                      │    │  (ASN 65515)   │    │  (Non-Secure)  │          │                      │
   │                      │    └───────┬────────┘    └────────────────┘          │                      │
   │                      │            │                                          │                      │
   │                      └────────────┼──────────────────────────────────────────┘                      │
   │                                   │                                                                  │
   │                        IPsec + BGP│                                                                  │
   │                                   │                                                                  │
   │     ┌─────────────────────────────┼─────────────────────────────┐                                   │
   │     │                             │                              │                                   │
   │     ▼                             ▼                              ▼                                   │
   │  ┌──────────────────┐   ┌──────────────────────┐   ┌──────────────────┐                             │
   │  │   Spoke 1 VNet   │   │   On-Prem VNet       │   │   Spoke 2 VNet   │                             │
   │  │   10.20.0.0/16   │   │   192.168.0.0/16     │   │   10.30.0.0/16   │                             │
   │  │  (SE Asia)       │   │   (East Asia)        │   │  (SE Asia)       │                             │
   │  │                  │   │                      │   │                  │                             │
   │  │  ┌────────────┐  │   │  ┌────────────────┐  │   │  ┌────────────┐  │                             │
   │  │  │  Test VM   │  │   │  │  VPN Gateway   │  │   │  │  Test VM   │  │                             │
   │  │  │            │  │   │  │  (ASN 65010)   │  │   │  │            │  │                             │
   │  │  └────────────┘  │   │  └────────────────┘  │   │  └────────────┘  │                             │
   │  │                  │   │                      │   │                  │                             │
   │  │  ┌────────────┐  │   │  ┌────────────────┐  │   │                  │                             │
   │  │  │  Bastion   │  │   │  │  Test VM       │  │   │                  │                             │
   │  │  └────────────┘  │   │  └────────────────┘  │   │                  │                             │
   │  │                  │   │                      │   │                  │                             │
   │  │                  │   │  ┌────────────────┐  │   │                  │                             │
   │  │                  │   │  │  Bastion       │  │   │                  │                             │
   │  │                  │   │  └────────────────┘  │   │                  │                             │
   │  └──────────────────┘   └──────────────────────┘   └──────────────────┘                             │
   │                                                                                                      │
   └──────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Key Features

- **Virtual WAN Standard** with a single Virtual Hub in Southeast Asia
- **Hub VPN Gateway** (RouteBased) for site-to-site connectivity
- **Azure Firewall** deployed inside the vHub (NOT as Secure Hub)
- **BGP over IPsec** VPN connection between on-prem and vHub
- **Default vWAN routing** - no UDRs, no Routing Intent, no Route Maps
- **Azure Bastion** for secure VM access in Spoke 1 and On-Prem VNets

## Address Space Summary

| Resource | Address Space | Location |
|----------|---------------|----------|
| Virtual Hub | 10.10.0.0/24 | Southeast Asia |
| Spoke 1 VNet | 10.20.0.0/16 | Southeast Asia |
| Spoke 2 VNet | 10.30.0.0/16 | Southeast Asia |
| On-Prem VNet | 192.168.0.0/16 | East Asia |

## BGP Configuration

| Gateway | ASN |
|---------|-----|
| Hub VPN Gateway | 65515 (vWAN default) |
| On-Prem VPN Gateway | 65010 |

## Prerequisites

- Azure subscription with sufficient quota
- PowerShell with Az module installed
- Bicep CLI (or Azure CLI with Bicep extension)

## Deployment

### Option 1: PowerShell Script

```powershell
# Set secure strings for passwords
$adminPwd = ConvertTo-SecureString "YourSecurePassword123!" -AsPlainText -Force
$vpnKey = ConvertTo-SecureString "YourSharedKey123!" -AsPlainText -Force

# Deploy
.\deploy.ps1 -AdminPassword $adminPwd -VpnSharedKey $vpnKey
```

### Option 2: Azure CLI

```bash
az group create --name rg-vwan-bgp-lab --location southeastasia

az deployment group create \
  --resource-group rg-vwan-bgp-lab \
  --template-file main.bicep \
  --parameters adminPassword='YourSecurePassword123!' vpnSharedKey='YourSharedKey123!'
```

### Deployment Time

⏱️ **Expected Duration: 45-60 minutes**

The deployment takes a long time primarily due to:
- Virtual Hub provisioning (~15 min)
- Hub VPN Gateway provisioning (~20-25 min)
- On-Prem VPN Gateway provisioning (~20-25 min)
- Azure Firewall provisioning (~10 min)

## Post-Deployment Testing Plan

### Phase 1: Verify Infrastructure Deployment

#### 1.1 Check Virtual WAN Resources
```powershell
# Get Virtual WAN status
Get-AzVirtualWan -ResourceGroupName rg-vwan-bgp-lab

# Get Virtual Hub status
Get-AzVirtualHub -ResourceGroupName rg-vwan-bgp-lab

# Get Hub VPN Gateway
Get-AzVpnGateway -ResourceGroupName rg-vwan-bgp-lab
```

#### 1.2 Verify Azure Firewall
1. Navigate to Azure Portal → Resource Group → Azure Firewall
2. Check that the firewall is deployed and has a private IP
3. Verify the firewall policy has the "Allow All" rules for testing

### Phase 2: Verify VPN Connectivity

#### 2.1 Check VPN Connection Status
1. Azure Portal → Virtual WAN → Virtual Hub → VPN (Site to site)
2. Check the connection status shows **"Connected"**
3. If not connected, wait a few more minutes and refresh

#### 2.2 Verify BGP Sessions
1. Azure Portal → Virtual Hub → VPN Gateway
2. Check BGP peer status under "BGP Peers"
3. Verify that BGP sessions are established

```powershell
# Check VPN connection status
Get-AzVpnConnection -ResourceGroupName rg-vwan-bgp-lab -ParentResourceName "vwan-bgp-hub-vpngw"

# Check On-Prem gateway BGP status
Get-AzVirtualNetworkGatewayBGPPeerStatus -ResourceGroupName rg-vwan-bgp-lab -VirtualNetworkGatewayName vwan-bgp-onprem-vpngw
```

### Phase 3: Verify Route Propagation

#### 3.1 Check Virtual Hub Effective Routes
1. Azure Portal → Virtual Hub → Effective Routes
2. Verify you see:
   - Spoke 1 prefix: 10.20.0.0/16
   - Spoke 2 prefix: 10.30.0.0/16
   - On-Prem prefix: 192.168.0.0/16

#### 3.2 Check On-Prem Gateway Learned Routes
```powershell
# Get learned routes from BGP
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName rg-vwan-bgp-lab -VirtualNetworkGatewayName vwan-bgp-onprem-vpngw | Format-Table
```

Expected routes learned via BGP:
- 10.20.0.0/16 (Spoke 1)
- 10.30.0.0/16 (Spoke 2)
- 10.10.0.0/24 (Hub)

### Phase 4: Connectivity Testing

#### 4.1 Connect to VMs via Bastion

**Connect to On-Prem VM:**
1. Azure Portal → Resource Group → `vwan-bgp-vm-onprem`
2. Click "Connect" → "Bastion"
3. Enter credentials (azureadmin / your password)

**Connect to Spoke 1 VM:**
1. Azure Portal → Resource Group → `vwan-bgp-vm-spoke1`
2. Click "Connect" → "Bastion"
3. Enter credentials

#### 4.2 Test Connectivity from On-Prem VM

Open Command Prompt or PowerShell on the On-Prem VM and run:

```cmd
# Ping Spoke 1 VM
ping 10.20.1.4

# Ping Spoke 2 VM
ping 10.30.1.4

# Traceroute to Spoke 1 (shows traffic path)
tracert 10.20.1.4
```

**Expected Results:**
- Pings should succeed
- Traceroute should show traffic going through the VPN tunnel and vHub

#### 4.3 Test Connectivity from Spoke 1 VM

Open Command Prompt or PowerShell on Spoke 1 VM and run:

```cmd
# Ping On-Prem VM
ping 192.168.2.4

# Ping Spoke 2 VM (spoke-to-spoke via hub)
ping 10.30.1.4

# Traceroute to On-Prem
tracert 192.168.2.4
```

#### 4.4 Test Connectivity from Spoke 2 VM

Connect via Spoke 1 Bastion (since Spoke 2 doesn't have Bastion):
1. From Spoke 1 VM, RDP to Spoke 2 VM: `mstsc /v:10.30.1.4`
2. Then test connectivity to On-Prem

### Phase 5: Verify Traffic Flow

#### 5.1 Expected Traffic Path (On-Prem → Spoke)
```
On-Prem VM → On-Prem VPN GW → [IPsec Tunnel + BGP] → Hub VPN GW → Hub → Spoke VNet → Spoke VM
```

#### 5.2 Check Azure Firewall Logs
1. Azure Portal → Azure Firewall → Diagnostic settings
2. Enable logging to Log Analytics (if needed)
3. Query network rule logs to see traffic passing through

### Phase 6: Advanced Testing

#### 6.1 Test File Transfer
From On-Prem VM to Spoke 1 VM:
```powershell
# Create a test file
New-Item -Path C:\testfile.txt -Value "Test content" -Force

# Copy to Spoke 1 (requires file sharing enabled)
# Or use PowerShell remoting if configured
```

#### 6.2 Check Firewall Hit Counts
```kusto
// Log Analytics Query
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where TimeGenerated > ago(1h)
| project TimeGenerated, msg_s
| order by TimeGenerated desc
```

## Troubleshooting

### VPN Not Connecting
1. Verify shared key matches on both sides
2. Check that both gateways are fully provisioned (ProvisioningState: Succeeded)
3. Verify public IPs are correctly assigned

### BGP Not Establishing
1. Verify ASN configuration matches
2. Check that BGP is enabled on both the VPN site and connection
3. Verify the BGP peer IP addresses are correct

### Traffic Not Flowing
1. Check effective routes in the Virtual Hub
2. Verify firewall rules allow the traffic
3. Check NSG rules on the VM subnets (none by default in this lab)

### Common Issues
- **"Connection stuck in Connecting"**: Wait longer (can take 10-15 min after initial deployment)
- **"Pings fail but VPN shows connected"**: Check firewall rules, ensure ICMP is allowed
- **"Spoke-to-spoke fails"**: Verify hub connections are in "Connected" state

## Cleanup

```powershell
.\cleanup.ps1 -ResourceGroupName rg-vwan-bgp-lab
```

Or manually:
```powershell
Remove-AzResourceGroup -Name rg-vwan-bgp-lab -Force -AsJob
```

## Cost Considerations

This lab deploys expensive resources:
- Virtual Hub: ~$0.25/hour
- Hub VPN Gateway (1 scale unit): ~$0.36/hour
- Azure Firewall Standard: ~$1.25/hour
- On-Prem VPN Gateway (VpnGw2): ~$0.39/hour
- Azure Bastion (x2): ~$0.26/hour each
- VMs (x3): ~$0.08/hour each

**Estimated total: ~$2.85/hour (~$68/day)**

⚠️ **Remember to delete the resource group when testing is complete!**

## Notes

- This deployment does NOT use Secure Hub, Routing Intent, or Route Maps
- Azure Firewall is deployed "inside" the hub but without security provider configuration
- Traffic routing relies entirely on default vWAN behavior
- For production, restrict firewall rules appropriately
