# Azure SQL Database Private Endpoint Lab 🔐

## Overview

This lab demonstrates the implementation of **Azure SQL Database with Private Endpoint connectivity**, providing secure, private access to SQL Database from within a virtual network. The solution eliminates the need for public endpoints while maintaining full database functionality and includes a test VM for connectivity validation.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Azure Resource Group                             │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                Virtual Network (myVirtualNetwork)                   │   │
│  │                        10.0.0.0/16                                  │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │              Default Subnet                                 │   │   │
│  │  │               10.0.0.0/24                                   │   │   │
│  │  │                                                             │   │   │
│  │  │  ┌─────────────────────────────────────────────────────┐   │   │   │
│  │  │  │             Test VM                                 │   │   │   │
│  │  │  │         (myVm-uniquestring)                         │   │   │   │
│  │  │  │                                                     │   │   │   │
│  │  │  │  • Windows Server 2019                            │   │   │   │
│  │  │  │  • SQL Server Management Studio                   │   │   │   │
│  │  │  │  • Private IP: 10.0.0.x                          │   │   │   │
│  │  │  │  • Public IP for RDP                             │   │   │   │
│  │  │  └─────────────────────────────────────────────────────┘   │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                               │                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │          Private Endpoint Subnet                           │   │   │
│  │  │              10.0.1.0/24                                   │   │   │
│  │  │                                                             │   │   │
│  │  │  ┌─────────────────────────────────────────────────────┐   │   │   │
│  │  │  │           Private Endpoint                          │   │   │   │
│  │  │  │         (myPrivateEndpoint)                         │   │   │   │
│  │  │  │                                                     │   │   │   │
│  │  │  │  • SQL Database connectivity                       │   │   │   │
│  │  │  │  • Private DNS integration                         │   │   │   │
│  │  │  │  • Network interface: 10.0.1.x                    │   │   │   │
│  │  │  └─────────────────────────────────────────────────────┘   │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                               │                                         │
│                               ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                  Private DNS Zone                                   │   │
│  │              privatelink.database.windows.net                       │   │
│  │                                                                     │   │
│  │  📋 DNS Records:                                                   │   │
│  │  • sqlserver-xxx.privatelink.database.windows.net                 │   │
│  │  • Points to Private Endpoint IP (10.0.1.x)                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                               │                                         │
│                               ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Azure SQL Server                                 │   │
│  │                (sqlserver-uniquestring)                             │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │                 SQL Database                                │   │   │
│  │  │               (sample-db)                                   │   │   │
│  │  │                                                             │   │   │
│  │  │  • No public endpoint                                      │   │   │
│  │  │  • Private connectivity only                               │   │   │
│  │  │  • Standard tier (S0)                                      │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

Connection Flow: Test VM ──► Private Endpoint ──► SQL Database
DNS Resolution: privatelink.database.windows.net ──► Private IP
```

### Key Components

- **Azure SQL Server**: Logical server with disabled public access
- **SQL Database**: Sample database with private connectivity
- **Private Endpoint**: Secure connection within VNet
- **Private DNS Zone**: Custom DNS resolution for private connectivity
- **Test VM**: Windows VM for database connectivity testing
- **Network Segmentation**: Separate subnets for compute and private endpoints

## 🔧 Prerequisites

- Azure CLI installed and configured
- Azure Bicep CLI extension
- Valid Azure subscription with SQL Database permissions
- Understanding of private networking and DNS concepts

## 🚀 Quick Start

### 1. Clone and Navigate
```powershell
cd C:\Bicep_GithubCode\PEtoSQLServerDB
```

### 2. Deploy the Lab
- VM Admin Username
- VM Admin Password
- SQL Admin Username
- SQL Admin Password
- Public IP Address of your machine to allow RDP

## Output

- Public IP Address of the VM to connect via RDP

## Notes

The Bicep file defines multiple Azure resources:

Microsoft.Sql/servers: The instance of SQL Database with the sample database.
Microsoft.Sql/servers/databases: The sample database.
Microsoft.Network/virtualNetworks: The virtual network where the private endpoint is deployed.
Microsoft.Network/privateEndpoints: The private endpoint that you use to access the instance of SQL Database.
Microsoft.Network/privateDnsZones: The zone that you use to resolve the private endpoint IP address.
Microsoft.Network/privateDnsZones/virtualNetworkLinks
Microsoft.Network/privateEndpoints/privateDnsZoneGroups: The zone group that you use to associate the private endpoint with a private DNS zone.
Microsoft.Network/publicIpAddresses: The public IP address that you use to access the virtual machine.
Microsoft.Network/networkInterfaces: The network interface for the virtual machine.
Microsoft.Compute/virtualMachines: The virtual machine that you use to test the connection of the private endpoint to the instance of SQL Database.

## Access the SQL Database Server via Private Endpoint

Access the SQL Database server privately from the VM. To connect to the SQL Database server from the VM by using the private endpoint, do the following:

1. On the Remote Desktop of `myVM{uniqueid}`, open PowerShell.
2. Run the following command:
   ```powershell
   nslookup sqlserver{uniqueid}.database.windows.net
   ```
   You'll receive a message that's similar to this one:
   ```
   Server:  UnKnown
   Address:  168.63.129.16
   Non-authoritative answer:
   Name:    sqlserver.privatelink.database.windows.net
   Address:  10.0.0.5
   Aliases:  sqlserver.database.windows.net
   ```
3. Install SQL Server Management Studio.
4. On the Connect to Server pane, do the following:
   - For Server type, select Database Engine.
   - For Server name, select `sqlserver{uniqueid}.database.windows.net`.
   - For Username, enter the username that was provided earlier.
   - For Password, enter the password that was provided earlier.
   - For Remember password, select Yes.
   - Select Connect.
5. On the left pane, select Databases. Optionally, you can create or query information from `sample-db`.
6. Close the Remote Desktop connection to `myVM{uniqueid}`.

## Clean up deployment

To remove the resources that were created as part of this deployment, use the following command:

```Terminal
az group delete --name <resourcegroupname> --yes --no-wait
```
