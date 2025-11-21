# Azure SQL Database Private Endpoint Lab - Project Structure

## 📁 Complete File Structure

```
PEtoSQLServerDB/
├── main.bicep                 # Main Bicep template for SQL DB with Private Endpoint
├── deploy.ps1                 # PowerShell deployment script
├── validate.ps1               # Template validation script
├── cleanup.ps1                # Resource cleanup automation
├── README.md                  # Comprehensive deployment guide
└── PROJECT_SUMMARY.md         # This project structure overview
```

## 🎯 Key Features Delivered

✅ **Azure SQL Database Infrastructure**
- SQL Server with unique naming (sqlserver-{uniqueString})
- Sample database (sample-db) with Standard S0 tier
- Public network access disabled for enhanced security
- Azure Active Directory integration capability

✅ **Private Endpoint Connectivity**
- Dedicated private endpoint (myPrivateEndpoint) in isolated subnet
- Network interface with private IP allocation
- Connection to SQL Database service
- Eliminated public internet exposure

✅ **Private DNS Integration**
- Private DNS zone (privatelink.database.windows.net)
- Automatic DNS record creation for SQL server
- VNet link for DNS resolution
- Private endpoint DNS group configuration

✅ **Network Architecture**
- Virtual Network (10.0.0.0/16) with proper segmentation
- Default subnet (10.0.0.0/24) for compute resources
- Private endpoint subnet (10.0.1.0/24) for service connections
- Network Security Group with controlled access

✅ **Test Environment**
- Windows Server test VM for connectivity validation
- SQL Server Management Studio for database access
- Public IP for administrative access via RDP
- Private network connectivity to SQL Database

✅ **Security Best Practices**
- No public database endpoints
- Network isolation through private connectivity
- Secure parameter handling for credentials
- NSG rules for controlled access

## 🚀 Quick Start Commands

```powershell
# Navigate to project directory
cd C:\Bicep_GithubCode\PEtoSQLServerDB

# Validate template (recommended first)
./validate.ps1

# Deploy complete SQL Database with Private Endpoint
./deploy.ps1 -ResourceGroupName "rg-sql-pe-lab" `
             -SqlAdministratorLogin "sqladmin" `
             -SqlAdministratorPassword "ComplexSQLPassword123!" `
             -VmAdminUsername "azureuser" `
             -VmAdminPassword "VMPassword123!" `
             -VMSizeOption "Overlake" `
             -Location "East US"

# Connect to test VM (get IP from deployment output)
mstsc /v:<VM_PUBLIC_IP>

# Test SQL connectivity from VM using SSMS
# Server name: sqlserver-{uniqueString}.database.windows.net
# Authentication: SQL Server Authentication
# Login: sqladmin
# Password: ComplexSQLPassword123!

# Clean up when done
./cleanup.ps1 -ResourceGroupName "rg-sql-pe-lab"
```

## 📊 Infrastructure Overview

| Component | Configuration | Purpose | Network |
|-----------|---------------|---------|---------|
| **SQL Server** | Standard tier, no public access | Database hosting | Private endpoint only |
| **SQL Database** | Standard S0, sample-db | Data storage | 1 DTU, 250GB max |
| **Private Endpoint** | SQL Database connection | Secure connectivity | 10.0.1.0/24 subnet |
| **Private DNS Zone** | privatelink.database.windows.net | Name resolution | VNet-linked |
| **Test VM** | Windows Server 2019 | Connectivity testing | 10.0.0.0/24 subnet |
| **Virtual Network** | 10.0.0.0/16 | Network isolation | Segmented subnets |

## 🔧 Template Parameters Deep Dive

### SQL Server Configuration
- **sqlAdministratorLogin**: SQL Server administrator username
- **sqlAdministratorLoginPassword**: Secure password for SQL admin (marked as @secure())

### Virtual Machine Configuration
- **vmAdminUsername**: Local administrator for test VM
- **vmAdminPassword**: Secure password for VM access (marked as @secure())
- **vmSizeOption**: Choice between 'Overlake' (v5) and 'Non-Overlake' (v4)

### Computed Variables
- **sqlServerName**: Unique SQL server name using resourceGroup().id
- **databaseName**: Constructed as '{sqlServerName}/sample-db'
- **privateEndpointName**: Fixed as 'myPrivateEndpoint'
- **vmName**: Truncated unique name for test VM (max 15 chars)

## 🏗️ Network Flow Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Test VM       │    │ Private         │    │  SQL Database   │
│   (10.0.0.x)    │───▶│ Endpoint        │───▶│   (Private)     │
│                 │    │ (10.0.1.x)      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Default Subnet  │    │ Private EP      │    │ Azure SQL       │
│ (10.0.0.0/24)   │    │ Subnet          │    │ Service         │
│                 │    │ (10.0.1.0/24)   │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         └───────────────────────┼─────────────────────────┐
                                 │                         │
                                 ▼                         ▼
                    ┌─────────────────────────────────────────┐
                    │          Virtual Network               │
                    │           (10.0.0.0/16)                │
                    └─────────────────────────────────────────┘
```

## 🔍 SQL Database Configuration

### Server Properties
```bicep
resource sqlServer 'Microsoft.Sql/servers@2021-11-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorLoginPassword
    version: '12.0'
    publicNetworkAccess: 'Disabled'  // Critical for security
  }
}
```

### Database Properties
```bicep
resource sqlDB 'Microsoft.Sql/servers/databases@2021-11-01-preview' = {
  parent: sqlServer
  name: 'sample-db'
  location: location
  sku: {
    name: 'S0'
    tier: 'Standard'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 268435456000
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}
```

### Private Endpoint Configuration
```bicep
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet.properties.subnets[1].id
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: ['sqlServer']
        }
      }
    ]
  }
}
```

## 🧪 Testing Scenarios

### 1. Private Connectivity Test
```sql
-- From SQL Server Management Studio on test VM
-- Test connection to: sqlserver-{uniqueString}.database.windows.net

-- Verify private IP resolution
SELECT CONNECTIONPROPERTY('client_net_address') AS ClientIP;

-- Test database access
SELECT 
    DB_NAME() AS DatabaseName,
    SUSER_SNAME() AS LoginName,
    GETDATE() AS ConnectionTime;
```

### 2. Network Isolation Verification
```powershell
# From test VM PowerShell
# Test that SQL server resolves to private IP
nslookup sqlserver-{uniqueString}.database.windows.net

# Expected result should show private IP (10.0.1.x), not public IP
# Verify no internet connectivity to SQL service
Test-NetConnection sqlserver-{uniqueString}.database.windows.net -Port 1433
```

### 3. DNS Resolution Test
```powershell
# Test private DNS zone resolution
nslookup sqlserver-{uniqueString}.privatelink.database.windows.net

# Verify DNS queries resolve to private endpoint IP
Resolve-DnsName sqlserver-{uniqueString}.database.windows.net
```

## 🛡️ Security Configuration

### SQL Server Security
- **Public Network Access**: Disabled
- **Private Endpoint Only**: All connectivity through VNet
- **Administrator Authentication**: SQL Server authentication
- **Firewall Rules**: None needed (private endpoint only)

### Network Security
```bicep
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'RDP'
        properties: {
          priority: 1000
          protocol: 'TCP'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}
```

## 💰 Cost Analysis

### Core Components Cost (USD/month estimates)
| Resource | SKU | Estimated Cost | Notes |
|----------|-----|----------------|-------|
| SQL Database | Standard S0 | ~$15/month | 10 DTU, pay-per-use |
| Test VM | Standard_D2s_v4/v5 | ~$70/month | 730 hours |
| Storage | Premium SSD | ~$15/month | OS disk |
| Public IP | Basic | ~$4/month | Dynamic allocation |
| Private Endpoint | Standard | ~$7/month | Data processing charges |

**Total Estimated**: ~$111/month

### Cost Optimization Tips
💡 **Development/Testing**
- Use SQL Database serverless for variable workloads
- Stop/deallocate VM when not testing
- Consider SQL Database Basic tier for development

💡 **Production Considerations**
- Scale SQL Database based on performance requirements
- Use Reserved Capacity for SQL Database
- Implement automated VM shutdown policies

## 🔄 Operational Procedures

### Database Management
```powershell
# Check SQL server status
az sql server show --resource-group "rg-sql-pe-lab" --name "sqlserver-{uniqueString}"

# View database metrics
az sql db show --resource-group "rg-sql-pe-lab" --server "sqlserver-{uniqueString}" --name "sample-db"

# Scale database if needed
az sql db update --resource-group "rg-sql-pe-lab" --server "sqlserver-{uniqueString}" --name "sample-db" --service-objective S1
```

### Private Endpoint Management
```powershell
# Check private endpoint status
az network private-endpoint show --resource-group "rg-sql-pe-lab" --name "myPrivateEndpoint"

# View private endpoint connections
az network private-endpoint-connection list --resource-group "rg-sql-pe-lab" --name "sqlserver-{uniqueString}" --type Microsoft.Sql/servers
```

### Monitoring and Diagnostics
```powershell
# Enable diagnostic logs for SQL Database
az monitor diagnostic-settings create \
  --name "sql-db-diagnostics" \
  --resource "/subscriptions/{subscription}/resourceGroups/rg-sql-pe-lab/providers/Microsoft.Sql/servers/sqlserver-{uniqueString}/databases/sample-db" \
  --logs '[{"category":"SQLInsights","enabled":true}]' \
  --workspace "/subscriptions/{subscription}/resourceGroups/rg-sql-pe-lab/providers/Microsoft.OperationalInsights/workspaces/sql-workspace"
```

---

**🎯 Lab Success Criteria**: Secure, private SQL Database connectivity without public internet exposure, validated through comprehensive testing from within the VNet.