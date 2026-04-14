---
name: bicep-error-lookup
description: 'Look up Azure Bicep deployment errors and get fixes. Use when: deployment failed, ARM error code, Azure error lookup, SkuNotAvailable, QuotaExceeded, InvalidTemplate, AuthorizationFailed, ResourceNotFound, diagnose deployment error.'
argument-hint: 'Paste the error message or code (e.g., SkuNotAvailable, QuotaExceeded)'
---

# Bicep Deployment Error Lookup

Quick-reference skill for diagnosing Azure Bicep deployment failures. Provides root causes, fixes, and diagnostic commands for common errors.

## When to Use

- Deployment failed and you have an error message or code
- Want a quick fix without running the full troubleshooter agent
- Need the right `az` CLI diagnostic command for a specific error

## Error Reference

### Resource Errors

| Error Code | Root Cause | Fix |
|-----------|-----------|-----|
| `SkuNotAvailable` | VM size not available in region | Run: `az vm list-skus --location <loc> --size <sku> --output table` and pick an available SKU |
| `ResourceQuotaExceeded` | Subscription quota hit | Run: `az vm list-usage --location <loc> --output table` then request increase in portal |
| `ResourceNotFound` | Referenced resource doesn't exist | Verify resource name/ID, check it's in the same RG or use full resource ID |
| `ResourceGroupNotFound` | RG doesn't exist yet | Ensure `az group create` runs before deployment |
| `ConflictError` / `StorageAccountAlreadyTaken` | Name globally taken | Use `uniqueString(resourceGroup().id)` for globally unique names |
| `ParentResourceNotFound` | Parent resource missing | Deploy parent first or add `dependsOn` |
| `ResourceDeploymentFailure` | Nested resource failed | Check inner error — drill into `details[0].message` |

### Template Errors

| Error Code | Root Cause | Fix |
|-----------|-----------|-----|
| `InvalidTemplate` | Bicep/ARM syntax error | Run: `az bicep build --file main.bicep` to see compilation errors |
| `InvalidParameter` | Parameter value doesn't match constraints | Check `@allowed()` values and parameter types |
| `InvalidParameterValue` | Value outside valid range | Check `@minValue()` / `@maxValue()` constraints |
| `MissingRequiredParameter` | Required param not provided | Add to deployment: `--parameters paramName=value` |
| `DeploymentOutputLimitExceeded` | Too many/large outputs | Reduce output count or output sizes |

### Auth & Policy Errors

| Error Code | Root Cause | Fix |
|-----------|-----------|-----|
| `AuthorizationFailed` | No permission to create resource | Run: `az role assignment list --assignee <upn> --output table` |
| `LinkedAuthorizationFailed` | No permission on linked resource | Check RBAC on the dependent resource (e.g., VNet in another RG) |
| `RequestDisallowedByPolicy` | Azure Policy blocking deployment | Run: `az policy assignment list -g <rg> --output table` |
| `RoleAssignmentExists` | Duplicate role assignment | Use `existing` keyword in Bicep or check for existing assignment |

### Networking Errors

| Error Code | Root Cause | Fix |
|-----------|-----------|-----|
| `NetcfgInvalidSubnet` | Subnet address overlap | Check VNet/subnet CIDR ranges don't overlap |
| `InUseSubnetCannotBeDeleted` | Subnet has attached resources | Remove NICs/endpoints from subnet first |
| `PrivateIPAddressNotInSubnet` | Static IP outside subnet range | Use IP within the subnet CIDR |
| `PublicIPCountLimitReached` | Too many public IPs | Delete unused PIPs or request quota increase |
| `NsgNotApplied` | NSG rules not taking effect | Verify NSG is associated to subnet or NIC |

## Diagnostic Commands

```powershell
# Get latest deployment status
az deployment group list -g <rg> --query "[0].{Name:name, State:properties.provisioningState, Timestamp:properties.timestamp}" --output table

# Get failed operations from a deployment
az deployment operation group list -g <rg> -n <deployment-name> --query "[?properties.provisioningState=='Failed'].{Resource:properties.targetResource.resourceType, Error:properties.statusMessage.error.code, Message:properties.statusMessage.error.message}" --output table

# Check VM SKU availability
az vm list-skus --location southeastasia --size Standard_D2s --output table

# Check subscription quotas
az vm list-usage --location southeastasia --output table

# Check resource provider registration
az provider show -n Microsoft.Compute --query "registrationState" --output tsv

# Validate template without deploying
az deployment group validate -g <rg> --template-file main.bicep --parameters key=value
```

## Procedure

1. Identify the error code from the deployment output
2. Look it up in the tables above
3. Run the suggested diagnostic command to confirm root cause
4. Apply the fix
5. Re-run `az bicep build --file main.bicep` to verify syntax
6. Retry the deployment
