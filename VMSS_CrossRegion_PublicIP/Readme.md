# VMSS Cross-Region with Public Load Balancer

This project deploys two Virtual Machine Scale Sets (VMSS) across two Azure regions (Southeast Asia and East Asia) behind Public Load Balancers. VMs have **no public IPs** - all outbound traffic is SNATed via the Load Balancer VIP.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                  Azure                                       │
│                                                                              │
│  ┌──────────────────────────────┐       ┌──────────────────────────────┐    │
│  │      Southeast Asia          │       │         East Asia            │    │
│  │                              │       │                              │    │
│  │  ┌────────────────────────┐  │       │  ┌────────────────────────┐  │    │
│  │  │   VMSS (no public IP)  │  │       │  │   VMSS (no public IP)  │  │    │
│  │  │                        │  │       │  │                        │  │    │
│  │  │  ┌──────┐  ┌──────┐    │  │       │  │  ┌──────┐  ┌──────┐    │  │    │
│  │  │  │ VM 0 │  │ VM 1 │    │  │       │  │  │ VM 0 │  │ VM 1 │    │  │    │
│  │  │  │ Priv │  │ Priv │    │  │       │  │  │ Priv │  │ Priv │    │  │    │
│  │  │  │  IP  │  │  IP  │    │  │       │  │  │  IP  │  │  IP  │    │  │    │
│  │  │  └──┬───┘  └──┬───┘    │  │       │  │  └──┬───┘  └──┬───┘    │  │    │
│  │  └─────┼─────────┼────────┘  │       │  └─────┼─────────┼────────┘  │    │
│  │        └────┬────┘           │       │        └────┬────┘           │    │
│  │             │                │       │             │                │    │
│  │     ┌───────┴───────┐        │       │     ┌───────┴───────┐        │    │
│  │     │ Load Balancer │        │       │     │ Load Balancer │        │    │
│  │     │  + Outbound   │        │       │     │  + Outbound   │        │    │
│  │     │    SNAT       │        │       │     │    SNAT       │        │    │
│  │     └───────┬───────┘        │       │     └───────┬───────┘        │    │
│  │             │                │       │             │                │    │
│  │     ┌───────┴───────┐        │       │     ┌───────┴───────┐        │    │
│  │     │   Public IP   │        │       │     │   Public IP   │        │    │
│  │     │  (LB VIP)     │        │       │     │  (LB VIP)     │        │    │
│  │     └───────┬───────┘        │       │     └───────┬───────┘        │    │
│  │             │                │       │             │                │    │
│  │     ┌───────┴───────┐        │       │     ┌───────┴───────┐        │    │
│  │     │ Azure Bastion │        │       │     │ Azure Bastion │        │    │
│  │     │  (for SSH)    │        │       │     │  (for SSH)    │        │    │
│  │     └───────────────┘        │       │     └───────────────┘        │    │
│  └──────────────────────────────┘       └──────────────────────────────┘    │
│                                                                              │
│                     ↕ Traffic via Public Internet ↕                         │
│                                                                              │
│  Traffic Flow:                                                               │
│  SEA VM → SEA LB (SNAT with SEA LB VIP) → Internet → EA LB VIP → EA VM      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Features

- **Two VMSS** deployed in Southeast Asia and East Asia regions
- **No public IPs on VMs** - VMs only have private IPs
- **Public Load Balancer** in each region with:
  - Inbound load balancing (HTTP/HTTPS)
  - Outbound SNAT rules (all outbound traffic uses LB VIP)
  - Health probes for HTTP and HTTPS
- **Azure Bastion** in each region for secure SSH access
- **Nginx with SSL** installed on each instance via Custom Script Extension
- **NSG rules** allowing SSH (22), HTTP (80), and HTTPS (443)

## Traffic Flow

### Outbound Traffic (SNAT)
When a VM in Southeast Asia makes an outbound connection:
1. VM sends packet with private source IP
2. Load Balancer performs SNAT, replacing source IP with LB VIP
3. Packet travels over public Internet
4. Destination sees SEA LB VIP as source

### Inbound Traffic (Load Balancing)
When traffic arrives at East Asia LB VIP:
1. Client connects to EA LB VIP on port 80/443
2. Load Balancer forwards to healthy backend VM
3. Response returns via same path

## Prerequisites

- Azure subscription
- Azure CLI installed and logged in
- PowerShell 7.0 or later
- Bicep CLI (auto-installed if missing)

## Files

| File | Description |
|------|-------------|
| `main.bicep` | Main Bicep template with Load Balancers and VMSS |
| `deploy.ps1` | Deployment script with test instructions |
| `cleanup.ps1` | Cleanup script to delete all resources |
| `validate.ps1` | Template validation script |

## Deployment

### Quick Start

```powershell
# Navigate to the project directory
cd VMSS_CrossRegion_PublicIP

# Deploy with default settings
.\deploy.ps1 -AdminUsername "azureuser" -AdminPassword "YourP@ssword123!"
```

### With Custom Parameters

```powershell
.\deploy.ps1 `
    -AdminUsername "azureuser" `
    -AdminPassword "YourP@ssword123!" `
    -ResourceGroupName "my-vmss-rg" `
    -InstanceCount 3 `
    -UbuntuOSVersion "Ubuntu-2204" `
    -VmSize "Standard_D2s_v4"
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `AdminUsername` | Yes | - | Administrator username |
| `AdminPassword` | Yes | - | Administrator password (12+ chars, mixed case, digit, special) |
| `ResourceGroupName` | No | `rg-vmss-crossregion` | Resource group name |
| `ResourcePrefix` | No | `vmss` | Prefix for resource names |
| `InstanceCount` | No | `2` | Number of instances per VMSS (1-10) |
| `UbuntuOSVersion` | No | `Ubuntu-2204` | Ubuntu version |
| `VmSize` | No | `Standard_D2s_v4` | VM SKU size |

## Testing Connectivity

After deployment, the script displays Load Balancer VIPs and test instructions.

### 1. Connect to VM via Azure Bastion

1. Go to **Azure Portal** → **Virtual Machine Scale Sets** → `vmss-vmss-sea`
2. Click **Instances** → Select an instance (e.g., `vmss-vmss-sea_0`)
3. Click **Connect** → **Bastion**
4. Enter credentials and connect

### 2. Test HTTPS Connection to East Asia

From the Southeast Asia instance (via Bastion):

```bash
# Test HTTPS (port 443)
curl -k https://<EA-LB-VIP>

# Test HTTP (port 80)
curl http://<EA-LB-VIP>

# Multiple requests to see load balancing
for i in {1..5}; do curl -s http://<EA-LB-VIP>; done
```

### 3. Verify Outbound SNAT IP

```bash
# Check your outbound IP (should be SEA LB VIP)
curl ifconfig.me
```

### 4. Test Reverse Direction (EA to SEA)

From an East Asia instance:

```bash
curl -k https://<SEA-LB-VIP>
curl http://<SEA-LB-VIP>
```

## Resources Created

| Resource | Location | Description |
|----------|----------|-------------|
| `vmss-vnet-sea` | Southeast Asia | Virtual Network (10.1.0.0/16) |
| `vmss-vnet-ea` | East Asia | Virtual Network (10.2.0.0/16) |
| `vmss-nsg-sea` | Southeast Asia | Network Security Group |
| `vmss-nsg-ea` | East Asia | Network Security Group |
| `vmss-lb-sea` | Southeast Asia | Public Load Balancer with SNAT |
| `vmss-lb-ea` | East Asia | Public Load Balancer with SNAT |
| `vmss-lb-pip-sea` | Southeast Asia | Load Balancer Public IP |
| `vmss-lb-pip-ea` | East Asia | Load Balancer Public IP |
| `vmss-bastion-sea` | Southeast Asia | Azure Bastion |
| `vmss-bastion-ea` | East Asia | Azure Bastion |
| `vmss-vmss-sea` | Southeast Asia | Virtual Machine Scale Set |
| `vmss-vmss-ea` | East Asia | Virtual Machine Scale Set |

## Cleanup

Remove all deployed resources:

```powershell
# With confirmation prompt
.\cleanup.ps1 -ResourceGroupName "rg-vmss-crossregion"

# Without confirmation
.\cleanup.ps1 -ResourceGroupName "rg-vmss-crossregion" -Force
```

## Cost Estimate

- VMSS instances (Standard_D2s_v4): ~$60-70/month per instance
- Load Balancers (Standard): ~$25/month each
- Azure Bastion (Basic): ~$140/month each
- **Total (4 instances, 2 LBs, 2 Bastions)**: ~$600-700/month

## Security Considerations

1. **No Public IPs on VMs**: VMs are not directly accessible from the internet
2. **Azure Bastion**: Secure SSH access without exposing SSH to internet
3. **Self-signed SSL**: Used for testing only. Use proper certificates in production.
4. **NSG Rules**: Restrict source IPs in production

## Troubleshooting

### Cannot connect to VM via Bastion
1. Verify Bastion is provisioned successfully
2. Check NSG allows traffic from AzureBastionSubnet

### Load Balancer returns no response
1. Wait 2-3 minutes for nginx to install
2. Check Load Balancer backend pool health
3. Verify NSG allows HTTP/HTTPS

### SNAT exhaustion
If you see connection timeouts, check SNAT port allocation:
```bash
az network lb show -g <rg> -n vmss-lb-sea --query "outboundRules"
```

## License

MIT License
