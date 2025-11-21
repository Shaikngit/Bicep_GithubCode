# 🐧 Linux VM with Application Security Group

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.compute%2Fvm-simple-linux%2Fazuredeploy.json)

## 🎯 Overview

This Bicep template deploys a Linux virtual machine with Application Security Groups (ASG) for micro-segmentation and network security. The VM is configured with NGINX web server and demonstrates advanced network security patterns using application-centric security policies.

## 🏗️ Architecture

```
    Internet
        │
        ▼
    ┌──────────────┐
    │ Public IP    │
    └──────┬───────┘
           │
    ┌──────▼──────────────────────────────────────────────────────┐
    │        Virtual Network                       │
    │        (10.0.0.0/16)                        │
    │                                              │
    │  ┌─────────────────────────────────────────────────────────┐ │
    │  │          Subnet                         │ │
    │  │        (10.0.0.0/24)                   │ │
    │  │                                         │ │
    │  │  ┌─────────────────────────────────────────────────────┐ │ │
    │  │  │    Application Security Group       │ │ │
    │  │  │        (Web Servers)               │ │ │
    │  │  │                                     │ │ │
    │  │  │  ┌─────────────────────────────────┐│ │ │
    │  │  │  │      Linux VM               ││ │ │
    │  │  │  │    • Ubuntu LTS             ││ │ │
    │  │  │  │    • NGINX Web Server       ││ │ │
    │  │  │  │    • SSH Access             ││ │ │
    │  │  │  └─────────────────────────────────┘│ │ │
    │  │  └─────────────────────────────────────────────────────┘ │ │
    │  └─────────────────────────────────────────────────────────┘ │
    │                                              │
    │  ┌─────────────────────────────────────────────────────────┐ │
    │  │    Network Security Group               │ │
    │  │  • SSH (Port 22)                        │ │
    │  │  • HTTP (Port 80)                       │ │
    │  │  • HTTPS (Port 443)                     │ │
    │  │  • ASG-based rules                      │ │
    │  └─────────────────────────────────────────────────────────┘ │
    └──────────────────────────────────────────────────────────────┘
```

## 📋 Features

- **Linux Virtual Machine**: Ubuntu LTS with configurable sizing
- **Application Security Groups**: Micro-segmentation for web servers
- **NGINX Web Server**: Automatically installed and configured
- **SSH Access**: Secure shell access with key-based authentication
- **Network Security**: ASG-based security rules
- **Custom Script Extension**: Automated NGINX installation
- **Flexible VM Sizing**: Overlake and Non-Overlake options
- **Public IP**: Optional internet connectivity

## 🔧 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| vmName | string | VM | Virtual machine name |
| vmSizeOption | string | Non-Overlake | VM size option (Overlake/Non-Overlake) |
| adminUsername | string | - | Administrator username for SSH |
| location | string | resourceGroup().location | Azure region for deployment |
| authenticationType | string | sshPublicKey | Authentication type (sshPublicKey/password) |
| adminPasswordOrKey | securestring | - | SSH public key or password |
| scriptFileUri | string | - | URI for NGINX installation script |

## 🚀 Quick Deploy

### Azure CLI
```bash
# Create resource group
az group create --name rg-linux-asg --location eastus

# Generate SSH key pair (if needed)
ssh-keygen -t rsa -b 2048 -f ~/.ssh/azure_vm_key

# Deploy template with SSH key
az deployment group create \
  --resource-group rg-linux-asg \
  --template-file azuredeploy.bicep \
  --parameters vmName="WebServer01" \
               adminUsername="azureuser" \
               adminPasswordOrKey="$(cat ~/.ssh/azure_vm_key.pub)" \
               authenticationType="sshPublicKey"
```

### PowerShell
```powershell
# Create resource group
New-AzResourceGroup -Name "rg-linux-asg" -Location "East US"

# Deploy template with password authentication
New-AzResourceGroupDeployment `
  -ResourceGroupName "rg-linux-asg" `
  -TemplateFile "azuredeploy.bicep" `
  -vmName "WebServer01" `
  -adminUsername "azureuser" `
  -adminPasswordOrKey (ConvertTo-SecureString "SecureP@ssw0rd123!" -AsPlainText -Force) `
  -authenticationType "password"
```

## 🧪 Testing & Validation

### 1. Connect via SSH
```bash
# SSH to the VM
ssh azureuser@<vm-public-ip>

# Or using specific key
ssh -i ~/.ssh/azure_vm_key azureuser@<vm-public-ip>
```

### 2. Verify NGINX Installation
```bash
# Check NGINX status
sudo systemctl status nginx

# Test web server locally
curl localhost

# Check NGINX configuration
sudo nginx -t
```

### 3. Test Web Server Access
```bash
# Test HTTP access from external
curl http://<vm-public-ip>

# Test with browser
# Navigate to http://<vm-public-ip>
```

### 4. Verify Application Security Group
```bash
# Check ASG assignment
az network nic show --name <nic-name> --resource-group <rg> --query "ipConfigurations[].applicationSecurityGroups"

# List ASG rules
az network nsg rule list --nsg-name <nsg-name> --resource-group <rg>
```

## 🔒 Security Features

- ✅ Application Security Groups for micro-segmentation
- ✅ SSH key-based authentication (recommended)
- ✅ Network Security Group with targeted rules
- ✅ NGINX with security best practices
- ✅ Ubuntu LTS with security updates
- ✅ Application-centric security policies
- ✅ Configurable access restrictions

## 🏷️ Resource Tags

All resources are tagged with:
- Project: Linux-VM-ASG
- Environment: Demo
- Application: Web-Server
- OS: Ubuntu

## 💰 Cost Optimization

- **Virtual Machine**: Variable based on size selection
- **Storage**: Standard SSD for optimal price/performance
- **Public IP**: ~$4/month (Standard)
- **Network**: No additional charges for ASG or NSG
- **Bandwidth**: Pay-per-GB for outbound traffic

## 📊 Monitoring

Monitor your Linux VM:
- VM performance metrics (CPU, memory, disk)
- NGINX access and error logs
- Application Security Group flow logs
- Network Security Group analytics
- System health and availability

## 🔧 Customization

### NGINX Configuration
```bash
# Custom NGINX configuration
sudo nano /etc/nginx/sites-available/default

# Add SSL/TLS support
sudo nginx -s reload
```

### Application Security Groups
- Add multiple ASGs for different application tiers
- Configure database tier ASG for backend connectivity
- Implement load balancer tier ASG

### Security Enhancements
- Configure fail2ban for SSH protection
- Implement UFW (Uncomplicated Firewall)
- Set up log monitoring and alerting

## 🚨 Troubleshooting

### SSH Connection Issues
```bash
# Check SSH service status
sudo systemctl status ssh

# Verify SSH configuration
sudo sshd -T

# Check firewall rules
sudo ufw status
```

### NGINX Issues
```bash
# Check NGINX logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log

# Test configuration
sudo nginx -t

# Restart NGINX
sudo systemctl restart nginx
```

### Network Connectivity
```bash
# Check network interface
ip addr show

# Test connectivity
ping google.com

# Check routing
ip route show
```

### Application Security Group Issues
```bash
# Verify ASG assignment
az network nic ip-config show --name <ip-config> --nic-name <nic> --resource-group <rg>

# Check NSG rules with ASG references
az network nsg rule list --nsg-name <nsg> --resource-group <rg>
```

## 🔄 Application Security Group Benefits

| Traditional NSG | ASG-Enhanced NSG | Benefits |
|----------------|------------------|----------|
| IP-based rules | Application-based rules | More intuitive security |
| Static configuration | Dynamic membership | Easier maintenance |
| Network-centric | Application-centric | Better alignment with architecture |

## 📚 Related Resources

- [Application Security Groups Documentation](https://docs.microsoft.com/azure/virtual-network/application-security-groups)
- [Linux VM Documentation](https://docs.microsoft.com/azure/virtual-machines/linux/)
- [NGINX Configuration Guide](https://nginx.org/en/docs/)
- [Network Security Groups](https://docs.microsoft.com/azure/virtual-network/network-security-groups-overview)

---

*This template demonstrates modern network security patterns using application-centric security policies for micro-segmentation.*