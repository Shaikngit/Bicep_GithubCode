# PE Policies Lab - Private Endpoint Network Policies with Optional Azure Firewall

This lab demonstrates **Private Endpoint Network Policies** behavior with an IIS web server exposed via Private Link Service.

## 🎯 Learning Objectives

- Understand `privateEndpointNetworkPolicies` setting
- Apply NSG rules to Private Endpoint traffic
- Configure Private Link Service with Internal Load Balancer
- Optionally route PE traffic through Azure Firewall

## 📐 Architecture

### Without Azure Firewall (Default)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       CLIENT VNET (10.10.0.0/16)                        │
│  ┌──────────────┐                                                       │
│  │  Client VM   │────────────────────────────────┐                      │
│  │  (Windows)   │                                │                      │
│  └──────────────┘                                │                      │
│                                                  ▼                      │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  pe-subnet [NSG + PE Network Policies Enabled]                  │    │
│  │  ┌───────────────────┐                                          │    │
│  │  │  Private Endpoint │──────────────────────┐                   │    │
│  │  └───────────────────┘                      │                   │    │
│  └─────────────────────────────────────────────┼───────────────────┘    │
│                                                │                        │
│  ┌─────────────────┐                           │ Private Link           │
│  │  Azure Bastion  │                           │                        │
│  └─────────────────┘                           │                        │
└────────────────────────────────────────────────┼────────────────────────┘
                                                 │
═══════════════════════════════════════════════════════════════════════════
                                                 │
┌────────────────────────────────────────────────┼────────────────────────┐
│                       SERVICE VNET (10.20.0.0/16)                       │
│  ┌─────────────────────────────────────────────┼───────────────────┐    │
│  │  pls-subnet                                 │                   │    │
│  │  ┌────────────────────────┐                 │                   │    │
│  │  │  Private Link Service  │◄────────────────┘                   │    │
│  │  └───────────┬────────────┘                                     │    │
│  └──────────────┼──────────────────────────────────────────────────┘    │
│                 │                                                       │
│  ┌──────────────▼──────────────────────────────────────────────────┐    │
│  │  web-subnet                                                     │    │
│  │  ┌───────────────────┐      ┌────────────────────────────────┐  │    │
│  │  │  Internal LB      │──────│  IIS Web Server VM             │  │    │
│  │  └───────────────────┘      └────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

### With Azure Firewall

```
Client VM → Route Table → Azure Firewall → Private Endpoint → PLS → ILB → IIS
```

When Azure Firewall is deployed:
- VNet peering connects Client VNet to Service VNet
- Route Table forces PE subnet traffic through Azure Firewall
- Firewall network rules allow HTTP/HTTPS traffic

## 🔑 Key Concepts

### Private Endpoint Network Policies

The `privateEndpointNetworkPolicies` subnet property controls whether NSG and UDR rules apply to Private Endpoint traffic:

| Setting | NSG on PE Traffic | UDR on PE Traffic |
|---------|-------------------|-------------------|
| `Disabled` (default) | ❌ No | ❌ No |
| `Enabled` | ✅ Yes | ✅ Yes |

In this lab, we set `privateEndpointNetworkPolicies: 'Enabled'` on the PE subnet, which allows:
- NSG rules to filter traffic to the Private Endpoint
- Route Tables to redirect PE traffic through Azure Firewall

### Private Link Service

Private Link Service exposes an Internal Load Balancer to consumers via Private Endpoint:
- Provider creates PLS attached to ILB frontend
- Consumer creates PE in their VNet
- Traffic flows: PE → PLS → ILB → Backend VMs

## 🚀 Deployment

### Prerequisites

- Azure CLI installed
- PowerShell 7.0+
- Azure subscription with Contributor access

### Deploy Without Firewall (Default)

```powershell
cd PE_Policies_Lab
.\deploy.ps1
```

### Deploy With Azure Firewall

```powershell
cd PE_Policies_Lab
.\deploy.ps1 -DeployAzureFirewall
```

### Custom Parameters

```powershell
.\deploy.ps1 -ResourceGroupName "my-pe-lab" `
             -Location "eastus" `
             -DeploymentPrefix "mylab" `
             -DeployAzureFirewall
```

### Cleanup

```powershell
.\deploy.ps1 -Cleanup
```

## 🧪 Testing

After deployment, the script displays test instructions. Here's a summary:

### Step 1: Connect to Client VM

1. Go to Azure Portal → Resource Group
2. Select `pelab-client-vm`
3. Click **Connect** → **Bastion**
4. Login with credentials (default: `azureuser` / your password)

### Step 2: Test Connectivity

From Client VM PowerShell:

```powershell
# Get PE IP from deployment output, e.g., 10.10.1.4

# Test TCP connectivity
Test-NetConnection -ComputerName <PE_IP> -Port 80

# Test HTTP request
Invoke-WebRequest -Uri http://<PE_IP> -UseBasicParsing

# View webpage content
(Invoke-WebRequest -Uri http://<PE_IP> -UseBasicParsing).Content
```

### Expected Results

- ✅ `TcpTestSucceeded: True`
- ✅ `StatusCode: 200`
- ✅ HTML content showing "Success! You have reached the IIS Web Server via Private Endpoint"

### Step 3: Verify PE Network Policies

1. Go to Client VNet → Subnets → pe-subnet
2. Verify **Private endpoint network policies** is `Enabled`
3. Check NSG `pelab-pe-nsg` is attached
4. Review NSG rules:
   - `AllowHTTPInbound` - Allows HTTP from Client VM subnet
   - `DenyAllOtherInbound` - Denies all other traffic

## 📁 Files

| File | Description |
|------|-------------|
| `main.bicep` | Main Bicep template with all resources |
| `deploy.ps1` | Deployment script with architecture diagram |
| `cleanup.ps1` | Cleanup script |
| `validate.ps1` | Validation script |

## 📊 Resources Deployed

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | rg-pe-policies-lab | Container for all resources |
| Client VNet | pelab-client-vnet | Client network (10.10.0.0/16) |
| Service VNet | pelab-service-vnet | Service network (10.20.0.0/16) |
| Client VM | pelab-client-vm | Test machine |
| Web Server VM | pelab-web-vm | IIS web server |
| Bastion | pelab-bastion | Secure VM access |
| Internal LB | pelab-ilb | Load balancer for web server |
| Private Link Service | pelab-pls | Exposes ILB via Private Link |
| Private Endpoint | pelab-pe | Consumer endpoint in client VNet |
| NSG | pelab-pe-nsg | NSG on PE subnet |
| Azure Firewall | pelab-fw | (Optional) Traffic inspection |
| Route Table | pelab-rt-pe-subnet | (Optional) Routes PE traffic via firewall |

## 💡 Key Takeaways

1. **PE Network Policies Enable NSG/UDR**: By default, NSG and UDR are ignored for PE traffic. Enable `privateEndpointNetworkPolicies` to apply them.

2. **Private Link Service Architecture**: PLS connects to ILB frontend, allowing consumers to access backend services via PE without VNet peering.

3. **Optional Firewall Routing**: When security requirements demand traffic inspection, Azure Firewall + Route Table can inspect PE traffic.

4. **No VNet Peering Without Firewall**: Private Link works without VNet peering. Peering is only needed when routing through a firewall.

## 🔗 References

- [Private Endpoint Network Policies](https://learn.microsoft.com/en-us/azure/private-link/disable-private-endpoint-network-policy)
- [Private Link Service Overview](https://learn.microsoft.com/en-us/azure/private-link/private-link-service-overview)
- [Azure Firewall with Private Link](https://learn.microsoft.com/en-us/azure/firewall/integrate-with-private-link)
