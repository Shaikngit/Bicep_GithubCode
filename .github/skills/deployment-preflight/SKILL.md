---
name: deployment-preflight
description: 'Run pre-flight checks before Azure Bicep deployment. Use when: check before deploy, preflight check, verify SKU availability, check quota, check provider registration, deployment readiness, pre-deploy validation, can I deploy this.'
argument-hint: 'Specify project folder and target region (e.g., SimpleVM-Linux southeastasia)'
---

# Deployment Pre-Flight Check

Runs comprehensive pre-flight checks to catch issues before `deploy.ps1` even starts. Verifies Azure environment readiness, SKU availability, quotas, and provider registration.

## When to Use

- Before deploying a new lab project
- After getting quota or SKU errors and want to verify the fix
- Deploying to a new region and need to check resource availability
- Want confidence that deployment will succeed before kicking it off

## Pre-Flight Checklist

Run these checks in order. Stop on first critical failure.

### 1. Azure Environment

```powershell
# Check Azure CLI installed
az version --output table

# Check logged in
az account show --query "{Subscription:name, Id:id, User:user.name}" --output table

# Check Bicep CLI
az bicep version
```

### 2. Bicep Compilation

```powershell
# Compile template — catches all syntax errors
az bicep build --file <ProjectFolder>/main.bicep --stdout > $null
```

### 3. Resource Provider Registration

Check that required providers are registered. Common providers for Bicep labs:

```powershell
# Check registration status for common providers
$providers = @(
    'Microsoft.Compute',
    'Microsoft.Network', 
    'Microsoft.Storage',
    'Microsoft.KeyVault',
    'Microsoft.Sql',
    'Microsoft.Web'
)

foreach ($p in $providers) {
    az provider show -n $p --query "{Provider:namespace, State:registrationState}" --output table
}

# Register if needed
az provider register -n Microsoft.Compute
```

### 4. VM SKU Availability

```powershell
# Check if target VM SKU is available in region
az vm list-skus --location southeastasia --size Standard_D2s_v4 --query "[].{Name:name, Zones:locationInfo[0].zones, Restrictions:restrictions[0].reasonCode}" --output table

# List all available VM sizes in region
az vm list-skus --location southeastasia --resource-type virtualMachines --query "[?restrictions[0].reasonCode!='NotAvailableForSubscription'].name" --output table
```

### 5. Subscription Quotas

```powershell
# Check vCPU usage vs limits
az vm list-usage --location southeastasia --query "[?contains(name.value,'cores') || contains(name.value,'vCPUs')].{Name:name.localizedValue, Current:currentValue, Limit:limit}" --output table

# Check specific family (e.g., Dv4 for Standard_D2s_v4)
az vm list-usage --location southeastasia --query "[?contains(name.value,'DSv4')].{Name:name.localizedValue, Used:currentValue, Limit:limit}" --output table
```

### 6. Naming Availability

```powershell
# Check storage account name availability
az storage account check-name --name <storage-name> --query "{Available:nameAvailable, Reason:reason}" --output table

# Check DNS label availability (for public IPs)
az network public-ip list --query "[?dnsSettings.domainNameLabel=='<label>'].{Name:name, FQDN:dnsSettings.fqdn}" --output table
```

### 7. Existing Resources Check

```powershell
# Check if resource group already exists
az group show --name rg-<project-slug> --query "{Name:name, State:properties.provisioningState}" --output table 2>$null

# List resources in existing RG (if redeploying)
az resource list --resource-group rg-<project-slug> --query "[].{Type:type, Name:name}" --output table 2>$null
```

### 8. Template What-If

```powershell
# Preview changes without deploying
az deployment group what-if --resource-group rg-<project-slug> --template-file main.bicep --parameters adminUsername=azureuser adminPasswordOrKey=<pwd>
```

## Procedure

1. Read the project's `main.bicep` to identify required resources, SKUs, and providers
2. Run checks 1-3 (environment, compilation, providers) — these are mandatory
3. Parse `main.bicep` for VM sizes → run check 4 (SKU availability)
4. If VMs are involved → run check 5 (quota)  
5. If storage accounts or public DNS → run check 6 (naming)
6. Run check 7 (existing resources) to detect conflicts
7. Optionally run check 8 (what-if) for full preview
8. Report results with ✅/❌ per check

## Output Format

```
## ✈️ Pre-Flight: <ProjectName> → <Region>

| Check | Status | Details |
|-------|--------|---------|
| Azure CLI | ✅ | v2.x.x |
| Azure Login | ✅ | user@domain.com |
| Bicep CLI | ✅ | v0.x.x |
| Bicep Compilation | ✅ | No errors |
| Providers | ✅ | 4/4 registered |
| VM SKU (Standard_D2s_v4) | ✅ | Available in southeastasia |
| vCPU Quota | ✅ | 8/20 used (12 remaining) |
| RG Conflict | ✅ | rg-xxx does not exist |

🟢 All pre-flight checks passed — safe to deploy!
```
