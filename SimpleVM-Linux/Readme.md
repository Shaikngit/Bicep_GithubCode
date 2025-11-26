# Simple Linux VM Deployment Lab 🐧

## Overview

This lab demonstrates the deployment of a **secure Linux Virtual Machine** on Azure with flexible authentication options, customizable network configuration, and enterprise-ready security practices. The template supports both SSH key and password authentication, multiple Ubuntu versions, and flexible VM sizing options.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Azure Resource Group                      │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Virtual Network (vNet)                         ││
│  │                   10.1.0.0/16                               ││
│  │                                                             ││
│  │  ┌─────────────────────────────────────────────────────┐   ││
│  │  │                 Subnet                              │   ││
│  │  │               10.1.0.0/24                           │   ││
│  │  │                                                     │   ││
│  │  │  ┌─────────────────────────────────────────────┐   │   ││
│  │  │  │             Linux VM                        │   │   ││
│  │  │  │        (simpleLinuxVM)                      │   │   ││
│  │  │  │                                             │   │   ││
│  │  │  │  • Ubuntu 20.04/22.04 LTS                 │   │   ││
│  │  │  │  • Standard_D2s_v4/v5                     │   │   ││
│  │  │  │  • SSH Key or Password Auth                │   │   ││
│  │  │  │  • Private IP: 10.1.0.x                   │   │   ││
│  │  │  └─────────────────────────────────────────────┘   │   ││
│  │  │                      │                              │   ││
│  │  └──────────────────────┼──────────────────────────────┘   ││
│  └───────────────────────────┼───────────────────────────────────┘│
│                              │                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Network Security Group                         ││
│  │                  (SecGroupNet)                              ││
│  │                                                             ││
│  │  📋 Inbound Rules:                                         ││
│  │  • Allow SSH (22) from Internet                            ││
│  │  • Allow HTTP (80) for web services                        ││
│  │  • Allow HTTPS (443) for secure web                        ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Public IP Address                              ││
│  │            (simpleLinuxVM-xxx-ip)                           ││
│  │               Dynamic allocation                            ││
│  │              Unique DNS label                               ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘

Access Methods: SSH (Port 22) ──► Internet ──► Public IP ──► VM
Web Services: HTTP/HTTPS (80/443) ──► Internet ──► Public IP ──► VM
```

### Key Components

- **Linux Virtual Machine**: Ubuntu LTS with flexible authentication
- **Network Security Group**: Controlled access with SSH, HTTP, and HTTPS
- **Public IP with DNS**: Dynamic IP allocation with unique DNS label
- **Virtual Network**: Isolated network environment (10.1.0.0/16)
- **Flexible Authentication**: Support for SSH keys (recommended) or passwords
- **VM Sizing**: Overlake (v5) and Non-Overlake (v4) options

## 🔧 Prerequisites

- Azure CLI installed and configured
- Azure Bicep CLI extension
- SSH key pair (if using SSH authentication)
- Valid Azure subscription with VM deployment permissions

## 🚀 Quick Start

### 1. Clone and Navigate
```bash
cd C:\Bicep_GithubCode\SimpleVM-Linux
```

### 2. Deploy with SSH Key (Recommended)
```bash
# Generate SSH key pair if you don't have one
ssh-keygen -t rsa -b 2048 -f ~/.ssh/azure_vm_key

# Create resource group
az group create --name "rg-linux-vm-lab" --location "East US"

# Deploy with SSH key authentication
az deployment group create \
  --resource-group "rg-linux-vm-lab" \
  --template-file main.bicep \
  --parameters adminUsername="azureuser" \
               authenticationType="sshPublicKey" \
               adminPasswordOrKey="$(cat ~/.ssh/azure_vm_key.pub)" \
               ubuntuOSVersion="Ubuntu-2204" \
               vmSizeOption="Overlake"
```

### 3. Deploy with Password Authentication
```bash
az deployment group create \
  --resource-group "rg-linux-vm-lab" \
  --template-file main.bicep \
  --parameters adminUsername="azureuser" \
               authenticationType="password" \
               adminPasswordOrKey="SecureLinuxPassword123!" \
               ubuntuOSVersion="Ubuntu-2004" \
               vmSizeOption="Non-Overlake"
```

## 📋 Configuration Parameters

| Parameter | Type | Options | Description |
|-----------|------|---------|-------------|
| `vmName` | string | - | Virtual machine name (default: simpleLinuxVM) |
| `adminUsername` | string | - | Administrator username for SSH/login |
| `authenticationType` | string | `sshPublicKey` \| `password` | Authentication method |
| `adminPasswordOrKey` | securestring | - | SSH public key or password |
| `ubuntuOSVersion` | string | `Ubuntu-2004` \| `Ubuntu-2204` | Ubuntu LTS version |
| `vmSizeOption` | string | `Overlake` \| `Non-Overlake` | VM size category |
| `virtualNetworkName` | string | - | VNet name (default: vNet) |
| `subnetName` | string | - | Subnet name (default: Subnet) |
| `dnsLabelPrefix` | string | - | DNS label prefix (auto-generated) |

### VM Size Options

| Option | VM Size | vCPUs | RAM | Storage | Use Case |
|--------|---------|-------|-----|---------|----------|
| **Non-Overlake** | Standard_D2s_v4 | 2 | 8 GB | Premium SSD | General purpose workloads |
| **Overlake** | Standard_D2s_v5 | 2 | 8 GB | Premium SSD | Latest generation, enhanced performance |

### Ubuntu Version Options

| Version | Description | Support Period | Recommended For |
|---------|-------------|----------------|-----------------|
| **Ubuntu-2004** | Ubuntu 20.04 LTS | Until 2030 | Stable, proven environment |
| **Ubuntu-2204** | Ubuntu 22.04 LTS | Until 2032 | Latest features, extended support |

## 🔐 Security Features

✅ **Network Security**
- Network Security Group with minimal required rules
- SSH access from internet (consider restricting in production)
- HTTP/HTTPS ports for web application development
- Private IP within isolated virtual network

✅ **Authentication Security**
- SSH key authentication (recommended for production)
- Password authentication with complexity requirements
- No root login enabled by default
- Secure credential parameter handling

✅ **Operating System Security**
- Latest Ubuntu LTS with security updates
- Cloud-init for secure initial configuration
- Premium SSD for encrypted storage
- Automatic security updates enabled

## 📊 Resource Overview

| Resource Type | Name | Purpose | Configuration |
|---------------|------|---------|---------------|
| Virtual Network | vNet | Network isolation | 10.1.0.0/16 |
| Subnet | Subnet | VM placement | 10.1.0.0/24 |
| Network Security Group | SecGroupNet | Traffic filtering | SSH, HTTP, HTTPS rules |
| Public IP | [vmName]-[uniqueString]-ip | External access | Dynamic with DNS label |
| Network Interface | [vmName]-nic | VM connectivity | Auto-assigned private IP |
| Virtual Machine | simpleLinuxVM | Compute workload | Ubuntu LTS |

## 🧪 Testing & Validation

### 1. Verify Deployment
```bash
# Check VM status
az vm show --resource-group "rg-linux-vm-lab" --name "simpleLinuxVM" --query "provisioningState"

# Get connection details
az vm show --resource-group "rg-linux-vm-lab" --name "simpleLinuxVM" --show-details --query "publicIps" --output tsv
```

### 2. Connect via SSH
```bash
# Get the public IP or DNS name
VM_IP=$(az vm show --resource-group "rg-linux-vm-lab" --name "simpleLinuxVM" --show-details --query "publicIps" --output tsv)

# Connect with SSH key
ssh -i ~/.ssh/azure_vm_key azureuser@$VM_IP

# Or connect with password (if using password authentication)
ssh azureuser@$VM_IP
```

### 3. Verify Network Configuration
```bash
# Inside the VM, check network settings
ip addr show
ping -c 4 8.8.8.8
curl -I http://www.ubuntu.com
```

### 4. Test Web Services (if applicable)
```bash
# Install and test web server
sudo apt update
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Test from outside
curl http://$VM_IP
```

## 🧹 Cleanup

### Remove All Resources
```bash
# Delete the entire resource group
az group delete --name "rg-linux-vm-lab" --yes --no-wait
```

### Verify Cleanup
```bash
# Confirm resource group deletion
az group list --query "[?name=='rg-linux-vm-lab']"
```

## 💡 Customization Examples

### Deploy with Custom Network Configuration
```bash
az deployment group create \
  --resource-group "rg-linux-vm-lab" \
  --template-file main.bicep \
  --parameters adminUsername="devuser" \
               authenticationType="sshPublicKey" \
               adminPasswordOrKey="$(cat ~/.ssh/dev_key.pub)" \
               virtualNetworkName="dev-vnet" \
               subnetName="dev-subnet" \
               dnsLabelPrefix="my-dev-vm"
```

### Deploy for Development Team
```bash
az deployment group create \
  --resource-group "rg-team-dev-linux" \
  --template-file main.bicep \
  --parameters vmName="team-dev-vm" \
               adminUsername="teamadmin" \
               authenticationType="password" \
               adminPasswordOrKey="TeamSecure789!" \
               ubuntuOSVersion="Ubuntu-2204" \
               vmSizeOption="Overlake"
```

## 🚨 Important Notes

⚠️ **Security Considerations**
- SSH key authentication is more secure than passwords
- Consider restricting SSH access to specific IP ranges in production
- Regularly update the operating system and installed packages
- Monitor failed authentication attempts

💰 **Cost Management**
- VM charges apply while running (use `az vm deallocate` to stop billing)
- Premium SSD storage has ongoing costs
- Public IP addresses incur charges
- Monitor usage with Azure Cost Management

🔄 **Best Practices**
- Use SSH keys for automated deployments
- Implement backup strategies for important data
- Configure monitoring and alerting
- Document any custom configurations

---

**Need help?** Check the deployment output for SSH connection details or review Azure portal for resource status.

2. Log in to your Azure account:
    ```sh
    az login
    ```

3. Create a resource group:
    ```sh
    az group create --name myResourceGroup --location southeastasia
    ```

4. Deploy the Bicep template:
    ```sh
    az deployment group create --resource-group myResourceGroup --template-file main.bicep
    ```

## Template Details

The Bicep template (`main.bicep`) includes the following resources:
- A Linux Virtual Machine
- A Virtual Network
- A Network Interface
- A Public IP Address
- A Network Security Group

## Cleanup

To remove the deployed resources, delete the resource group:
```sh
az group delete --name myResourceGroup --no-wait --yes
```

