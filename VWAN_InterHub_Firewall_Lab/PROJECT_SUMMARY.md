# Azure Virtual WAN Inter-Hub Traffic Inspection Lab - Project Structure

## 📁 Complete File Structure

```
VWAN_InterHub_Firewall_Lab/
├── main.bicep                  # Main deployment template (subscription scope)
├── main.bicepparam            # Parameters file for easy deployment
├── deploy.ps1                 # PowerShell deployment script with validation
├── validate.ps1               # Template validation script
├── cleanup.ps1                # Resource cleanup script
├── README.md                  # Comprehensive lab guide and documentation
└── modules/
    ├── vwan.bicep             # Virtual WAN resource module
    ├── hub.bicep              # Virtual Hub module
    ├── firewall.bicep         # Azure Firewall module with policies
    ├── routing-intent.bicep   # Routing Intent configuration module
    └── spoke.bicep            # Spoke VNet and VM module
```

## 🎯 Key Features Delivered

✅ **Complete Bicep Infrastructure**
- Modular design with separation of concerns
- Subscription-level deployment
- Parameterized for flexibility
- Following Bicep best practices

✅ **Virtual WAN Architecture**
- Two Virtual Hubs (Southeast Asia & East Asia)
- Standard Virtual WAN with hub-to-hub connectivity
- Proper address space allocation

✅ **Secured Virtual Hubs**
- Azure Firewall Standard deployed in each hub
- Firewall policies with allow rules for testing
- DNS proxy enabled for domain resolution

✅ **Routing Intent Configuration**
- Automatic private traffic routing through firewalls
- No manual route table configuration needed
- Inter-hub traffic inspection enforced

✅ **Test Environment**
- Ubuntu 22.04 LTS VMs in each region
- Pre-installed network testing tools
- Public IPs for SSH access
- NSGs configured for SSH, RDP, and ICMP

✅ **Deployment Automation**
- PowerShell script with comprehensive validation
- Azure CLI integration
- What-if deployment support
- Detailed progress reporting

✅ **Operations & Maintenance**
- Template validation script
- Resource cleanup automation
- Cost optimization guidance
- Troubleshooting documentation

## 🚀 Quick Start Commands

```powershell
# Navigate to lab directory
cd C:\Bicep_GithubCode\VWAN_InterHub_Firewall_Lab

# Validate templates (recommended first)
./validate.ps1

# Deploy lab with secure password
./deploy.ps1 -AdminPassword "YourStrongPassword123!"

# Test connectivity (after deployment)
# SSH to VMs using output connection strings
# Run: ./test-connectivity.sh <target_vm_private_ip>

# Clean up when done (to save costs)
./cleanup.ps1 -DeleteResourceGroup
```

## 📊 Architecture Summary

| Component | Region | Address Space | Purpose |
|-----------|--------|---------------|---------|
| Virtual WAN | Global | - | Hub-to-hub connectivity backbone |
| vHub-SEA | Southeast Asia | 10.1.0.0/16 | Regional hub with firewall |
| vHub-EA | East Asia | 10.2.0.0/16 | Regional hub with firewall |
| Spoke-SEA | Southeast Asia | 10.10.0.0/16 | Test workload network |
| Spoke-EA | East Asia | 10.20.0.0/16 | Test workload network |

## 🔍 Traffic Flow Verification

**Expected Flow**: VM-SEA → SEA Firewall → VWAN → EA Firewall → VM-EA

**Test Commands**:
```bash
# From VM-SEA, ping VM-EA
ping 10.20.1.x

# Trace route to see firewall hops
traceroute 10.20.1.x

# Monitor traffic inspection
sudo tcpdump -i any -n host 10.20.1.x
```

## 💰 Cost Management

**Estimated Monthly Cost**: ~$2,240 USD
- Virtual WAN Hubs: ~$360/month
- Azure Firewalls: ~$1,800/month  
- VMs & Storage: ~$80/month

**Cost Optimization**:
- Use lab for short testing periods
- Stop VMs when not testing: `./cleanup.ps1 -StopVMsOnly`
- Delete firewalls for major savings: `./cleanup.ps1 -DeleteFirewalls`

## 🎓 Learning Objectives Achieved

1. ✅ **Virtual WAN Multi-Region Architecture**
2. ✅ **Azure Firewall Hub Integration**
3. ✅ **Routing Intent Configuration**
4. ✅ **Inter-Hub Traffic Inspection**
5. ✅ **Infrastructure as Code with Bicep**
6. ✅ **Network Security Policy Implementation**
7. ✅ **Azure CLI Automation**

## 📚 Next Steps

**Extend the Lab**:
- Add ExpressRoute gateway to hub
- Configure application rules for FQDN filtering
- Set up Log Analytics for centralized logging
- Add Network Security Groups for micro-segmentation
- Deploy multi-tier applications across regions

**Production Considerations**:
- Implement proper RBAC and governance
- Set up Azure Monitor alerts and dashboards
- Configure backup and disaster recovery
- Implement proper secret management with Key Vault
- Set up CI/CD pipelines for infrastructure updates

---

**Lab Status**: ✅ Complete and Ready for Deployment

The Azure Virtual WAN Inter-Hub Traffic Inspection Lab is now complete with all deliverables:
- Complete Bicep code (main + 5 modules)
- PowerShell deployment script with validation
- Comprehensive README with testing instructions
- Template validation and cleanup utilities
- Production-ready architecture following Azure best practices

You can now deploy this lab to demonstrate Virtual WAN's Routing Intent feature for enforcing traffic inspection across Azure regions!