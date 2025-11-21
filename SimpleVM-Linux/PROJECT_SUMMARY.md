# Simple Linux VM Deployment Lab - Project Structure

## 📁 Complete File Structure

```
SimpleVM-Linux/
├── main.bicep                 # Main Bicep template for Linux VM deployment
├── deploy.ps1                 # PowerShell deployment script
├── validate.ps1               # Template validation script
├── cleanup.ps1                # Resource cleanup automation
├── README.md                  # Comprehensive deployment guide
└── PROJECT_SUMMARY.md         # This project structure overview
```

## 🎯 Key Features Delivered

✅ **Flexible Linux VM Deployment**
- Ubuntu 20.04 and 22.04 LTS support
- Choice between Standard_D2s_v4 and Standard_D2s_v5 VM sizes
- Configurable VM naming and resource organization
- Dynamic public IP allocation with unique DNS labeling

✅ **Dual Authentication Methods**
- SSH public key authentication (recommended for production)
- Password authentication with complexity requirements
- Secure parameter handling for credentials
- Cloud-init integration for initial configuration

✅ **Network Security Architecture**
- Dedicated Virtual Network (10.1.0.0/16)
- Isolated subnet for VM placement (10.1.0.0/24)
- Network Security Group with controlled access rules
- Public IP with dynamic allocation and DNS resolution

✅ **Security Best Practices**
- SSH access control (port 22)
- HTTP/HTTPS support for web development (ports 80/443)
- Network isolation with private IP addressing
- Minimal attack surface configuration

✅ **Operational Flexibility**
- Overlake vs Non-Overlake VM sizing options
- Configurable virtual network and subnet naming
- Unique DNS label generation
- Resource group scoped deployment

✅ **Enterprise Ready**
- Premium SSD storage for performance
- Latest Ubuntu LTS with security updates
- Scalable network architecture
- Cost-optimized resource allocation

## 🚀 Quick Start Commands

```bash
# Navigate to project directory
cd C:\Bicep_GithubCode\SimpleVM-Linux

# Validate template (recommended first)
./validate.ps1

# Deploy with SSH key (Production recommended)
./deploy.ps1 -ResourceGroupName "rg-linux-lab" `
             -AdminUsername "azureuser" `
             -AuthenticationType "sshPublicKey" `
             -AdminPasswordOrKey "$(cat ~/.ssh/id_rsa.pub)" `
             -UbuntuOSVersion "Ubuntu-2204" `
             -VMSizeOption "Overlake"

# Deploy with password (Development/Testing)
./deploy.ps1 -ResourceGroupName "rg-linux-lab" `
             -AdminUsername "azureuser" `
             -AuthenticationType "password" `
             -AdminPasswordOrKey "SecurePassword123!" `
             -UbuntuOSVersion "Ubuntu-2004" `
             -VMSizeOption "Non-Overlake"

# Connect via SSH (get IP from deployment output)
ssh azureuser@<PUBLIC_IP_ADDRESS>

# Clean up when done
./cleanup.ps1 -ResourceGroupName "rg-linux-lab"
```

## 📊 Configuration Matrix

| Component | Option 1 | Option 2 | Recommendation |
|-----------|----------|----------|----------------|
| **OS Version** | Ubuntu 20.04 LTS | Ubuntu 22.04 LTS | 22.04 for new deployments |
| **VM Size** | Standard_D2s_v4 | Standard_D2s_v5 | v5 for better performance |
| **Authentication** | SSH Public Key | Password | SSH Key for production |
| **Storage** | Premium SSD | Premium SSD | Premium for all workloads |
| **Networking** | 10.1.0.0/16 | Configurable | Default for simple deployments |

## 🔧 Template Parameters Deep Dive

### Core VM Configuration
- **vmName**: Virtual machine identifier (default: simpleLinuxVM)
- **adminUsername**: Linux administrator account name
- **authenticationType**: SSH key or password selection
- **adminPasswordOrKey**: Credential data (SSH public key content or password)

### OS and Sizing
- **ubuntuOSVersion**: Ubuntu LTS version selection
- **vmSizeOption**: Performance tier selection (Overlake vs Non-Overlake)
- **location**: Azure region (inherits from resource group)

### Network Configuration
- **virtualNetworkName**: VNet identifier (default: vNet)
- **subnetName**: Subnet identifier (default: Subnet)
- **networkSecurityGroupName**: NSG identifier (default: SecGroupNet)
- **dnsLabelPrefix**: Public DNS prefix (auto-generated with uniqueString)

## 🏗️ Network Architecture

```
Internet
    │
    ▼
┌─────────────────────┐
│   Public IP         │
│  (Dynamic + DNS)    │
└─────────────────────┘
    │
    ▼
┌─────────────────────┐
│ Network Security    │
│ Group (NSG)         │
│ • SSH (22)          │
│ • HTTP (80)         │
│ • HTTPS (443)       │
└─────────────────────┘
    │
    ▼
┌─────────────────────┐
│ Virtual Network     │
│ (10.1.0.0/16)       │
│                     │
│ ┌─────────────────┐ │
│ │ Subnet          │ │
│ │ (10.1.0.0/24)   │ │
│ │                 │ │
│ │ ┌─────────────┐ │ │
│ │ │ Linux VM    │ │ │
│ │ │ (Ubuntu)    │ │ │
│ │ └─────────────┘ │ │
│ └─────────────────┘ │
└─────────────────────┘
```

## 🔍 Security Configuration

### Network Security Group Rules
```bicep
securityRules: [
  {
    name: 'SSH'
    properties: {
      priority: 1001
      protocol: 'Tcp'
      access: 'Allow'
      direction: 'Inbound'
      sourceAddressPrefix: '*'
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
      destinationPortRange: '22'
    }
  }
  {
    name: 'HTTP'
    properties: {
      priority: 1002
      protocol: 'Tcp'
      access: 'Allow'
      direction: 'Inbound'
      destinationPortRange: '80'
    }
  }
  {
    name: 'HTTPS'
    properties: {
      priority: 1003
      protocol: 'Tcp'
      access: 'Allow'
      direction: 'Inbound'
      destinationPortRange: '443'
    }
  }
]
```

### SSH Key Configuration
```bicep
linuxConfiguration: {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}
```

## 🧪 Testing Scenarios

### 1. SSH Connectivity Test
```bash
# Test SSH connection
ssh -o ConnectTimeout=10 azureuser@<VM_PUBLIC_IP>

# Test SSH key authentication
ssh -i ~/.ssh/azure_vm_key azureuser@<VM_PUBLIC_IP>

# Test password authentication (if configured)
ssh azureuser@<VM_PUBLIC_IP>
```

### 2. Network Connectivity Test
```bash
# Inside VM - test outbound connectivity
ping -c 4 8.8.8.8
curl -I https://www.ubuntu.com
wget -q --spider http://security.ubuntu.com

# Test DNS resolution
nslookup www.microsoft.com
```

### 3. Web Service Test
```bash
# Install and configure nginx
sudo apt update && sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Test from external
curl http://<VM_PUBLIC_IP>
curl -I http://<VM_PUBLIC_IP>
```

### 4. Performance Validation
```bash
# Check VM specifications
lscpu
free -h
df -h
lsblk

# Network performance test
sudo apt install -y iperf3
iperf3 -c iperf.he.net
```

## 💰 Cost Optimization

### Development Environment
```bash
# Stop VM to save compute costs (storage costs continue)
az vm deallocate --resource-group "rg-linux-lab" --name "simpleLinuxVM"

# Start VM when needed
az vm start --resource-group "rg-linux-lab" --name "simpleLinuxVM"

# Check current status
az vm get-instance-view --resource-group "rg-linux-lab" --name "simpleLinuxVM" --query "instanceView.statuses"
```

### Cost Monitoring
```bash
# Get cost information
az consumption usage list --start-date 2024-01-01 --end-date 2024-01-31

# Monitor resource usage
az monitor metrics list --resource-id "/subscriptions/{subscription}/resourceGroups/rg-linux-lab/providers/Microsoft.Compute/virtualMachines/simpleLinuxVM"
```

### Cost Optimization Tips
💡 **Development/Testing**
- Use Spot VMs for non-production workloads (up to 90% savings)
- Deallocate VMs during non-business hours
- Use smaller VM sizes for basic testing

💡 **Production Considerations**
- Reserved Instances for predictable workloads (up to 72% savings)
- Azure Hybrid Benefit if applicable
- Right-size VMs based on actual usage metrics

## 🔄 Operational Procedures

### VM Management
```bash
# Check VM status
az vm show --resource-group "rg-linux-lab" --name "simpleLinuxVM" --query "provisioningState"

# Get VM details including public IP
az vm show --resource-group "rg-linux-lab" --name "simpleLinuxVM" --show-details

# Restart VM
az vm restart --resource-group "rg-linux-lab" --name "simpleLinuxVM"

# Resize VM
az vm resize --resource-group "rg-linux-lab" --name "simpleLinuxVM" --size "Standard_D4s_v5"
```

### Security Maintenance
```bash
# Inside VM - update packages
sudo apt update && sudo apt upgrade -y

# Check for security updates
sudo unattended-upgrades --dry-run

# Configure automatic security updates
sudo dpkg-reconfigure -plow unattended-upgrades
```

### Backup Configuration
```bash
# Enable backup for the VM
az backup protection enable-for-vm \
  --resource-group "rg-linux-lab" \
  --vault-name "vm-backup-vault" \
  --vm "simpleLinuxVM" \
  --policy-name "DefaultPolicy"
```

## 🎛️ Advanced Customization

### Custom Script Extension
```bicep
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  parent: vm
  name: 'CustomScript'
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    settings: {
      fileUris: ['https://raw.githubusercontent.com/your-repo/setup-script.sh']
      commandToExecute: 'bash setup-script.sh'
    }
  }
}
```

### Multiple Network Interfaces
```bicep
resource additionalNic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${vmName}-nic2'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig2'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}
```

---

**🎯 Lab Success Criteria**: Secure, accessible Linux environment ready for development, testing, or production workloads.