# Project Summary: VWAN Route Table Isolation Lab

## Purpose
This lab demonstrates Azure Virtual WAN hub route table isolation to control traffic flow between VNets and simulated branch sites.

## Key Features
- **Route Table Isolation**: VNet_A is completely isolated from Branch_A and Branch_B traffic
- **Full Mesh Connectivity**: VNet_B and VNet_C have full connectivity to all resources
- **BGP-Enabled VPN**: Branch sites use BGP for dynamic routing with APIPA addresses
- **Multi-Region**: Hub in SoutheastAsia, Branches in EastAsia

## Architecture Components
| Component | Count | Purpose |
|-----------|-------|---------|
| Virtual WAN | 1 | Central networking hub |
| Virtual Hub | 1 | SoutheastAsia routing hub |
| Spoke VNets | 3 | VNet_A, VNet_B, VNet_C |
| Branch VNets | 2 | Branch_A, Branch_B with VPN Gateways |
| Hub Route Tables | 2 | RouteTable_A (isolation), RouteTable_B (branches) |
| VMs | 5 | Ubuntu 22.04 LTS for testing |

## Routing Isolation Logic
```
RouteTable_A (VNet_A):
  - Only propagates to itself
  - Does NOT receive branch routes
  
RouteTable_B (Branches):
  - Propagates to Default + RouteTable_B
  - Does NOT receive VNet_A routes

Default Route Table (VNet_B, VNet_C):
  - Full mesh connectivity
  - Receives all routes except isolated paths
```

## Files
| File | Description |
|------|-------------|
| main.bicep | Complete Bicep template |
| deploy.ps1 | Deployment script with outputs |
| validate.ps1 | Resource validation script |
| cleanup.ps1 | Resource cleanup script |
| README.md | Full documentation |

## Deployment Time
~45-60 minutes (VPN Gateway provisioning)

## Estimated Cost
~$750-800/month (delete after testing)
