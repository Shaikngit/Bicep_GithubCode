# 🖥️ Two VMs in Same Virtual Network

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.compute%2F2-vms-internal-load-balancer%2Fazuredeploy.json)

## 🎯 Overview

This Bicep template deploys two Windows virtual machines in the same virtual network, demonstrating inter-VM connectivity, shared networking resources, and multi-VM scenarios within a single network boundary.

## Prerequisites
- Azure CLI installed and logged in (`az login`)
- Sufficient permissions to create resources

## 1. Create a Resource Group
Replace `<resource-group>` and `<location>` with your desired values:

```sh
az group create --name <resource-group> --location <location>
```

## 2. Deploy the Bicep Template
Replace `<resource-group>` with your resource group name. You can customize parameters as needed.

### Basic Deployment (default parameters)
```sh
az deployment group create \
  --resource-group <resource-group> \
  --template-file main.bicep \
  --parameters adminUsername=<username> adminPassword=<password> allowedRdpSourceAddress=<your-ip>
```

### Specify OS Type (Windows or Linux)
```sh
az deployment group create \
  --resource-group <resource-group> \
  --template-file main.bicep \
  --parameters adminUsername=<username> adminPassword=<password> allowedRdpSourceAddress=<your-ip> osType=Linux
```

### Use a Custom Image
```sh
az deployment group create \
  --resource-group <resource-group> \
  --template-file main.bicep \
  --parameters adminUsername=<username> adminPassword=<password> allowedRdpSourceAddress=<your-ip> useCustomImage=Yes customImageResourceId=<image-resource-id>
```

### Override VM Size or Image Details
```sh
az deployment group create \
  --resource-group <resource-group> \
  --template-file main.bicep \
  --parameters adminUsername=<username> adminPassword=<password> allowedRdpSourceAddress=<your-ip> vmSizeOption=Overlake imageSku=20_04-lts-gen2
```

## 3. Parameter Reference
- `adminUsername`: VM admin username
- `adminPassword`: VM admin password
- `allowedRdpSourceAddress`: Your public IP for RDP/SSH access
- `osType`: Windows or Linux (default: Windows)
- `useCustomImage`: Yes/No (default: No)
- `customImageResourceId`: Resource ID of your custom image
- `vmSizeOption`: Overlake or Non-Overlake
- `imagePublisher`, `imageOffer`, `imageSku`, `imageVersion`: Advanced image options

## Notes
- For Linux VMs, SSH is enabled. For Windows VMs, RDP is enabled.
- Make sure to use a strong password and restrict `allowedRdpSourceAddress` to your IP.

---
For more details, see the comments in `main.bicep` or Azure documentation.
