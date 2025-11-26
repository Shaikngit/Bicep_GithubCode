# VWAN Route Table Isolation Lab

## Overview

This lab deploys an Azure Virtual WAN topology to demonstrate **hub route table isolation**. The goal is to isolate `VNet_A` from branch site traffic (`Branch_A` and `Branch_B`) while maintaining full mesh connectivity for other VNets.

## Architecture Diagram

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │                      SoutheastAsia                          │
                    │  ┌──────────────────────────────────────────────────────┐   │
                    │  │               Virtual Hub (vhub-test)                 │   │
                    │  │                   10.0.0.0/24                         │   │
                    │  │                                                       │   │
                    │  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │   │
                    │  │  │ RouteTable_A │  │  Default RT  │  │RouteTable_B │ │   │
                    │  │  │  (VNet_A)    │  │(VNet_B,C)    │  │(Branches)   │ │   │
                    │  │  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘ │   │
                    │  │         │                 │                  │        │   │
                    │  │         │    ┌────────────┤                  │        │   │
                    │  │         │    │            │                  │        │   │
                    │  └─────────┼────┼────────────┼──────────────────┼────────┘   │
                    │            │    │            │                  │            │
                    │   ┌────────▼─┐ ┌▼────────┐ ┌─▼────────┐        │            │
                    │   │ VNet_A   │ │ VNet_B  │ │ VNet_C   │        │            │
                    │   │10.1.0.0  │ │10.2.0.0 │ │10.3.0.0  │        │            │
                    │   │  /16     │ │  /16    │ │  /16     │        │            │
                    │   │          │ │         │ │          │        │            │
                    │   │  [vm-a]  │ │ [vm-b]  │ │ [vm-c]   │        │            │
                    │   └──────────┘ └─────────┘ └──────────┘        │            │
                    └────────────────────────────────────────────────┼────────────┘
                                                                     │
                                                        VPN Connections (BGP)
                                                                     │
                    ┌────────────────────────────────────────────────┼────────────┐
                    │                      EastAsia                  │            │
                    │                                                │            │
                    │      ┌─────────────────────────────────────────┼──────┐     │
                    │      │                                         │      │     │
                    │  ┌───▼───────┐                         ┌───────▼────┐ │     │
                    │  │ Branch_A  │                         │ Branch_B   │ │     │
                    │  │10.10.0.0  │                         │10.20.0.0   │ │     │
                    │  │  /16      │                         │  /16       │ │     │
                    │  │           │                         │            │ │     │
                    │  │[VPN GW]   │                         │ [VPN GW]   │ │     │
                    │  │ASN:65010  │                         │ ASN:65020  │ │     │
                    │  │           │                         │            │ │     │
                    │  │[vm-branchA│                         │[vm-branchB]│ │     │
                    │  └───────────┘                         └────────────┘ │     │
                    │                                                       │     │
                    └───────────────────────────────────────────────────────┘     │
                    └─────────────────────────────────────────────────────────────┘
```

## Resources Deployed

### SoutheastAsia Region

| Resource | Name | Details |
|----------|------|---------|
| Virtual WAN | vwan-test | Standard tier |
| Virtual Hub | vhub-test | Address: 10.0.0.0/24 |
| Hub VPN Gateway | vhub-test-vpngw | For branch connectivity |
| VNet_A | VNet_A | 10.1.0.0/16 |
| VNet_B | VNet_B | 10.2.0.0/16 |
| VNet_C | VNet_C | 10.3.0.0/16 |
| VNet_Bastion | VNet_Bastion | 10.100.0.0/16 (for secure access) |
| Azure Bastion | bastion-vwan-lab | Standard SKU with tunneling |
| VM | vm-a | In VNet_A, Ubuntu 22.04 |
| VM | vm-b | In VNet_B, Ubuntu 22.04 |
| VM | vm-c | In VNet_C, Ubuntu 22.04 |

### EastAsia Region (Simulated Branches)

| Resource | Name | Details |
|----------|------|---------|
| Branch_A VNet | Branch_A | 10.10.0.0/16 |
| Branch_A VPN GW | vpngw-Branch_A | ASN: 65010, APIPA: 169.254.10.1 |
| Branch_B VNet | Branch_B | 10.20.0.0/16 |
| Branch_B VPN GW | vpngw-Branch_B | ASN: 65020, APIPA: 169.254.20.1 |
| VM | vm-branchA | In Branch_A, Ubuntu 22.04 |
| VM | vm-branchB | In Branch_B, Ubuntu 22.04 |

## Route Table Configuration

### RouteTable_A (VNet_A Isolation)

- **Associated with:** VNet_A
- **Propagates to:** RouteTable_A only
- **Result:** VNet_A does NOT receive branch routes

### RouteTable_B (Branch Isolation)

- **Associated with:** Branch_A, Branch_B (VPN connections)
- **Propagates to:** RouteTable_B and Default
- **Result:** Branches do NOT learn VNet_A routes

### Default Route Table (Full Mesh)

- **Associated with:** VNet_B, VNet_C
- **Propagates to:** Default and RouteTable_B
- **Result:** Full connectivity with branches

## Routing Behavior

| Source | Destination | Expected Result |
|--------|-------------|-----------------|
| vm-a | vm-branchA/B | ❌ BLOCKED (isolated) |
| vm-branchA/B | vm-a | ❌ BLOCKED (isolated) |
| vm-a | vm-b | ✅ ALLOWED |
| vm-a | vm-c | ✅ ALLOWED |
| vm-b | vm-branchA/B | ✅ ALLOWED |
| vm-c | vm-branchA/B | ✅ ALLOWED |
| vm-branchA | vm-branchB | ✅ ALLOWED |
| vm-b | vm-c | ✅ ALLOWED |

## Deployment

### Prerequisites

- Azure PowerShell module installed (`Install-Module -Name Az`)
- Logged into Azure (`Connect-AzAccount`)
- Sufficient permissions to create resources

### Deploy

```powershell
# Basic deployment
./deploy.ps1 -ResourceGroupName "rg-vwan-isolation-lab" `
             -AdminUsername "azureuser" `
             -AdminPassword (ConvertTo-SecureString "YourPassword123!" -AsPlainText -Force)

# With custom VM size
./deploy.ps1 -ResourceGroupName "rg-vwan-isolation-lab" `
             -Location "southeastasia" `
             -AdminUsername "azureuser" `
             -AdminPassword (ConvertTo-SecureString "YourPassword123!" -AsPlainText -Force) `
             -VmSize "Standard_B2ms"
```

### Deployment Time

⚠️ **This deployment takes approximately 45-60 minutes** due to:
- Hub VPN Gateway provisioning (~30 minutes)
- Branch VPN Gateways provisioning (~30 minutes each, deployed in parallel)
- VPN connection establishment

## Post-Deployment Testing

### Connect to VMs via Azure Bastion

The lab includes Azure Bastion (Standard SKU) for secure VM access without public IPs.

#### Option 1: Azure Portal
1. Go to Azure Portal → Search for your VM (e.g., `vm-a`)
2. Click **Connect** → **Bastion**
3. Enter username and password
4. Click **Connect**

#### Option 2: Native SSH Client (Recommended)
Azure Bastion Standard SKU supports native client tunneling, allowing you to use your local SSH client:

```powershell
# Install Azure CLI extension (one-time)
az extension add --name bastion

# Connect to VMs via Bastion tunnel
# Replace <subscription-id> and <resource-group> with your values

# Connect to vm-a
az network bastion ssh --name "bastion-vwan-lab" `
    --resource-group "rg-vwan-isolation-lab2" `
    --target-resource-id "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Compute/virtualMachines/vm-a" `
    --auth-type password `
    --username "<admin-username>"

# Or connect using private IP (requires IP Connect feature)
az network bastion ssh --name "bastion-vwan-lab" `
    --resource-group "rg-vwan-isolation-lab2" `
    --target-ip-address "10.1.0.4" `
    --auth-type password `
    --username "<admin-username>"
```

#### Option 3: Bastion Tunnel for SSH
Create a tunnel and use any SSH client:

```powershell
# Create tunnel to VM (runs in background, use port 2222 locally)
az network bastion tunnel --name "bastion-vwan-lab" `
    --resource-group "rg-vwan-isolation-lab2" `
    --target-resource-id "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Compute/virtualMachines/vm-a" `
    --resource-port 22 `
    --port 2222

# In another terminal, SSH through the tunnel
ssh -p 2222 <admin-username>@127.0.0.1
```

### Wait for Route Propagation

After deployment completes, wait **5-10 minutes** for BGP routes to fully propagate.

### Test 1: Validate VNet_A Isolation

SSH into `vm-b` first (since it has connectivity to all VMs), then SSH to `vm-a`:

```bash
# From vm-a - these should FAIL (isolation working)
ping <vm-branchA-ip> -c 4    # Expected: FAIL (timeout)
ping <vm-branchB-ip> -c 4    # Expected: FAIL (timeout)

# From vm-a - these should SUCCEED
ping <vm-b-ip> -c 4          # Expected: SUCCESS
ping <vm-c-ip> -c 4          # Expected: SUCCESS
```

### Test 2: Validate Branch Isolation from VNet_A

SSH into `vm-branchA`:

```bash
# From vm-branchA - this should FAIL (isolation working)
ping <vm-a-ip> -c 4          # Expected: FAIL (timeout)

# From vm-branchA - these should SUCCEED
ping <vm-b-ip> -c 4          # Expected: SUCCESS
ping <vm-c-ip> -c 4          # Expected: SUCCESS
ping <vm-branchB-ip> -c 4    # Expected: SUCCESS (branch-to-branch)
```

### Test 3: Verify Full Mesh for VNet_B/C

SSH into `vm-b`:

```bash
# From vm-b - all should SUCCEED
ping <vm-a-ip> -c 4          # Expected: SUCCESS
ping <vm-c-ip> -c 4          # Expected: SUCCESS
ping <vm-branchA-ip> -c 4    # Expected: SUCCESS
ping <vm-branchB-ip> -c 4    # Expected: SUCCESS
```

### View Effective Routes

To verify route table behavior, check effective routes in Azure Portal:

1. Go to Virtual Hub → Routing → Effective Routes
2. Select each route table and connection to see learned routes
3. Verify VNet_A routes are NOT in RouteTable_B
4. Verify Branch routes are NOT in RouteTable_A

## Cleanup

```powershell
./cleanup.ps1 -ResourceGroupName "rg-vwan-isolation-lab"
```

## Troubleshooting

### VPN Connections Not Establishing

1. Verify VPN Gateway status in Azure Portal
2. Check VPN connection status (should be "Connected")
3. Allow additional time for BGP peering (can take 10-15 minutes)

### Pings Failing When They Should Succeed

1. Verify NSG rules allow ICMP from lab address ranges
2. Check effective routes on VM NICs
3. Wait additional time for BGP route propagation
4. Restart VMs if routes were applied after VM boot

### All Pings Failing

1. Verify VNet connections to hub are "Connected"
2. Check if hub VPN gateway is provisioned
3. Verify branch VPN gateways are active
4. Check VPN connection shared keys match

## Network Security Groups

All VMs are configured with NSGs that:
- Allow SSH (port 22) from lab address ranges only
- Allow ICMP from lab address ranges only
- Deny SSH from internet
- No public IPs on VMs (except VPN Gateway PIPs)

## Cost Considerations

This lab deploys resources that incur costs:
- **VPN Gateways (VpnGw1)**: ~$140/month each × 3 = ~$420/month
- **Virtual Hub**: ~$0.25/hour = ~$180/month
- **VMs (Standard_B2s)**: ~$30/month each × 5 = ~$150/month
- **Total estimated cost**: ~$750-800/month

**Recommendation**: Delete resources after testing using the cleanup script.

## References

- [Virtual WAN Documentation](https://learn.microsoft.com/azure/virtual-wan/)
- [Hub Route Tables](https://learn.microsoft.com/azure/virtual-wan/about-virtual-hub-routing)
- [VPN Gateway BGP](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-bgp-overview)
