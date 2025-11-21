# Azure Application Gateway with Backend VMs Lab 🚀

## Overview

This lab demonstrates a **complete Azure Application Gateway deployment** with backend virtual machines, Web Application Firewall (WAF), and load balancing capabilities. The template creates a secure three-tier architecture with internet-facing Application Gateway, backend VMs running Windows Server, and proper network segmentation.

## 🏗️ Architecture

```
                             Internet
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Azure Resource Group                                │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Virtual Network (myVNet)                         │   │
│  │                        10.0.0.0/16                                  │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │              Application Gateway Subnet                     │   │   │
│  │  │                   10.0.0.0/24                              │   │   │
│  │  │                                                             │   │   │
│  │  │  ┌─────────────────────────────────────────────────────┐   │   │   │
│  │  │  │           Azure Application Gateway                  │   │   │   │
│  │  │  │            (myAppGateway)                           │   │   │   │
│  │  │  │                                                     │   │   │   │
│  │  │  │  • WAF v2 (Detection/Prevention)                  │   │   │   │
│  │  │  │  • SSL Termination                                │   │   │   │
│  │  │  │  • Load Balancing                                 │   │   │   │
│  │  │  │  • Public IP: Dynamic                             │   │   │   │
│  │  │  └─────────────────────────────────────────────────────┘   │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                │                                    │   │
│  │                                ▼                                    │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │               Backend Subnet                                │   │   │
│  │  │                 10.0.1.0/24                                │   │   │
│  │  │                                                             │   │   │
│  │  │  ┌─────────────────┐              ┌─────────────────┐      │   │   │
│  │  │  │    VM1 (myVM1)  │              │    VM2 (myVM2)  │      │   │   │
│  │  │  │                 │              │                 │      │   │   │
│  │  │  │ • Windows Server│              │ • Windows Server│      │   │   │
│  │  │  │ • IIS Web Server│              │ • IIS Web Server│      │   │   │
│  │  │  │ • Private IP    │              │ • Private IP    │      │   │   │
│  │  │  │ • Public IP     │              │ • Public IP     │      │   │   │
│  │  │  │ • Standard_B2ms │              │ • Standard_B2ms │      │   │   │
│  │  │  └─────────────────┘              └─────────────────┘      │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

Traffic Flow: Internet ──► App Gateway ──► WAF ──► Backend Pool ──► VMs
```

### Key Components

- **Application Gateway v2**: Standard_v2 SKU with WAF capabilities
- **Web Application Firewall**: Protection against OWASP Top 10 vulnerabilities
- **Backend VMs**: Two Windows Server instances with IIS
- **Network Segmentation**: Dedicated subnets for Application Gateway and backend
- **Load Balancing**: Round-robin distribution to healthy backend instances
- **SSL/TLS**: Secure communication and certificate management

## 🔧 Prerequisites

- Azure CLI installed and configured
- Azure Bicep CLI extension
- Valid Azure subscription with Application Gateway permissions
- Understanding of web application security principles

## 🚀 Quick Start

### 1. Clone and Navigate
```powershell
cd C:\Bicep_GithubCode\AzureAppGW
```

### 2. Deploy the Lab

```powershell
# Create resource group
az group create --name "rg-appgw-lab" --location "East US"

# Deploy Application Gateway with backend VMs
az deployment group create \
  --resource-group "rg-appgw-lab" \
  --template-file main.bicep \
  --parameters adminUsername="azureuser" \
               adminPassword="ComplexPassword123!" \
               vmSize="Standard_B2ms" \
               location="East US"
```

### 3. Verify Deployment
```powershell
# Check Application Gateway status
az network application-gateway show \
  --resource-group "rg-appgw-lab" \
  --name "myAppGateway" \
  --query "operationalState"

# Get Application Gateway public IP
az network public-ip show \
  --resource-group "rg-appgw-lab" \
  --name "public_ip0" \
  --query "ipAddress" \
  --output tsv
```

## 📋 Configuration Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `adminUsername` | string | - | Administrator username for backend VMs |
| `adminPassword` | securestring | - | Strong password for VM access |
| `location` | string | Resource Group | Azure region for deployment |
| `vmSize` | string | `Standard_B2ms` | VM size for backend instances |

### Network Configuration

| Component | Address Space | Purpose |
|-----------|---------------|---------|
| **Virtual Network** | 10.0.0.0/16 | Complete network isolation |
| **Application Gateway Subnet** | 10.0.0.0/24 | Frontend network segment |
| **Backend Subnet** | 10.0.1.0/24 | Backend VMs network segment |

## 🔐 Security Features

✅ **Web Application Firewall (WAF)**
- OWASP Core Rule Set protection
- Detection and Prevention modes
- Customizable security policies
- Real-time threat monitoring

✅ **Network Security Groups**
- RDP access control (Port 3389)
- HTTP/HTTPS traffic management
- Inbound rule prioritization
- Source IP restrictions

✅ **SSL/TLS Security**
- Certificate management
- Protocol version control
- Cipher suite configuration
- End-to-end encryption

✅ **Backend Pool Security**
- Health probe monitoring
- Automatic failover
- Private IP communication
- Isolated backend subnet

## 📊 Resource Overview

| Resource Type | Name | Purpose | Configuration |
|---------------|------|---------|---------------|
| Virtual Network | myVNet | Network isolation | 10.0.0.0/16 |
| Application Gateway | myAppGateway | Load balancer + WAF | Standard_v2 SKU |
| WAF Policy | WafPol01 | Security protection | Detection mode |
| Backend VMs | myVM1, myVM2 | Web servers | Windows Server + IIS |
| Public IPs | public_ip0-2 | External connectivity | Dynamic allocation |
| Network Security Groups | vm-nsg1, vm-nsg2 | Traffic filtering | RDP + HTTP rules |

## 🧪 Testing & Validation

### 1. Web Application Testing
```powershell
# Get Application Gateway public IP
$appGwIP = az network public-ip show --resource-group "rg-appgw-lab" --name "public_ip0" --query "ipAddress" --output tsv

# Test web application
curl http://$appGwIP
```

### 2. Load Balancing Verification
```powershell
# Test multiple requests to verify load balancing
for ($i=1; $i -le 10; $i++) {
    curl http://$appGwIP
    Start-Sleep 1
}
```

### 3. WAF Testing (Safe Tests)
```powershell
# Test basic WAF functionality (blocked request)
curl "http://$appGwIP?test=<script>alert('xss')</script>"

# Test normal request (allowed)
curl "http://$appGwIP/index.html"
```

### 4. Backend Health Check
```bash
# Check backend pool health from Azure CLI
az network application-gateway show-backend-health \
  --resource-group "rg-appgw-lab" \
  --name "myAppGateway"
```

## 🧹 Cleanup

### Remove All Resources
```powershell
# Delete the entire resource group
az group delete --name "rg-appgw-lab" --yes --no-wait
```

### Verify Cleanup
```powershell
# Confirm resource group deletion
az group list --query "[?name=='rg-appgw-lab']"
```

## 💰 Cost Optimization Tips

💡 **Development Environment**
- Use Basic SKU for non-production testing
- Stop VMs when not in use
- Use Burstable VM sizes for variable workloads

💡 **Production Considerations**
- Use Standard_v2 SKU for performance
- Enable autoscaling for Application Gateway
- Monitor and optimize WAF rule performance
- Consider Reserved Instances for consistent workloads

## 🚨 Important Notes

⚠️ **Security Considerations**
- Review WAF policies regularly
- Monitor security logs and alerts
- Implement proper SSL certificate management
- Use private endpoints for backend communication

💰 **Cost Management**
- Application Gateway charges for provisioned instances
- WAF adds additional cost per processed request
- Monitor data transfer charges
- Use Azure Cost Management for optimization

🔄 **Operational Excellence**
- Implement health checks for all backend services
- Monitor Application Gateway performance metrics
- Set up alerting for security events
- Regular backup of configurations and certificates

---

**🎯 Lab Objective**: Deploy a production-ready Application Gateway with WAF protection and learn enterprise web application security patterns.
