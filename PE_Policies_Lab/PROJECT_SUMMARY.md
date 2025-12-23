# PE Policies Lab - Project Summary

## Overview
This lab demonstrates **Private Endpoint Network Policies** with an IIS web server exposed via Private Link Service. The lab supports optional Azure Firewall deployment for traffic inspection scenarios.

## Architecture

### Without Firewall (Default)
```
Client VM → Private Endpoint → Private Link Service → Internal LB → IIS Web Server
```

### With Azure Firewall
```
Client VM → Route Table → Azure Firewall → Private Endpoint → PLS → ILB → IIS
```

## Key Learning Points

1. **privateEndpointNetworkPolicies**: When set to `Enabled`, NSG and UDR rules apply to Private Endpoint traffic
2. **Private Link Service**: Exposes Internal Load Balancer to consumers via Private Endpoint
3. **NSG on PE Subnet**: Demonstrates filtering traffic to Private Endpoints
4. **Optional Firewall Routing**: UDR can force PE traffic through Azure Firewall when enabled

## Files

| File | Purpose |
|------|---------|
| main.bicep | Main Bicep template with all resources |
| deploy.ps1 | Deployment script with architecture diagram |
| validate.ps1 | Validation script |
| cleanup.ps1 | Resource cleanup script |
| README.md | Detailed documentation |

## Quick Start

```powershell
# Deploy without firewall
.\deploy.ps1

# Deploy with Azure Firewall
.\deploy.ps1 -DeployAzureFirewall

# Cleanup
.\deploy.ps1 -Cleanup
```

## Resources Deployed

- Client VNet (10.10.0.0/16) with vm-subnet, pe-subnet, AzureBastionSubnet
- Service VNet (10.20.0.0/16) with web-subnet, pls-subnet
- Client VM (Windows Server 2022)
- IIS Web Server VM
- Azure Bastion
- Internal Load Balancer
- Private Link Service
- Private Endpoint
- NSG for PE subnet
- (Optional) Azure Firewall + Route Table

## Testing

1. Connect to Client VM via Bastion
2. Test HTTP connectivity to Private Endpoint IP:
   ```powershell
   Test-NetConnection -ComputerName <PE_IP> -Port 80
   Invoke-WebRequest -Uri http://<PE_IP> -UseBasicParsing
   ```
