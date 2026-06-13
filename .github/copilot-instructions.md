---
name: Bicep-VM-Defaults
description: "Project-specific defaults for VM creation: always use azuser username and prompt for password at deployment time"
---

# Bicep Project VM Creation Defaults

## Default Credentials

When creating or modifying Azure VMs in Bicep templates within this project, use this default admin username and collect password interactively at deployment time:

- **Admin Username**: `azuser`
- **Admin Password**: prompt the user each deployment (do not hardcode)

## When This Applies

This applies to:
- Creating Bicep templates with `Microsoft.Compute/virtualMachines` resources
- Modifying existing VM parameters in this workspace
- Adding new VM deployments to any template in `c:\Github\Bicep_GithubCode\`
- Parameter files (`parameters.json`) that reference VM admin credentials

## Implementation

- Never prompt for VM username; always use `azuser`
- Never hardcode VM passwords in Bicep, scripts, or parameter files
- Prompt for VM password at deployment time and pass it securely
- Document in parameter files that password must be provided at deploy time

## Do Not Override

These defaults should not be overridden unless the user explicitly requests different credentials in the same message.

## Deployment Tenant Selection (Mandatory)

Before any new lab deployment, the agent must ask the user where the deployment will happen and force authentication in the matching tenant.

### Tenant Options

- **MicrosoftInternal**
	- Tenant ID: `16b3c013-d300-468d-ac64-7eda0820b6d3`
	- Default Subscription ID: `58400668-ed03-47a3-a7f8-fb03677bdffb`

- **Outlook Tenant**
	- Tenant ID: `92bc17ae-8183-4173-9a07-397e548d00a1`
	- Default Subscription ID: `c18a2d54-fae6-4708-aa27-c0ad1ed4d172`

### Required Agent Behavior For Every New Deployment

- Ask the user to choose deployment target: `MicrosoftInternal` or `Outlook Tenant`.
- Run tenant-specific authentication using Azure CLI:
	- `az login --tenant <selected-tenant-id>`
- Set the matching default subscription immediately after login:
	- `az account set --subscription <mapped-default-subscription-id>`
- Verify active context before deployment:
	- `az account show --output table`
- Only proceed with deployment commands after the correct tenant and subscription are active.

### Preferred User Prompt Format

When asking where to deploy, use this menu-style format:

1. MicrosoftInternal
	- Tenant: 16b3c013-d300-468d-ac64-7eda0820b6d3
	- Default Subscription: 58400668-ed03-47a3-a7f8-fb03677bdffb
2. Outlook Tenant
	- Tenant: 92bc17ae-8183-4173-9a07-397e548d00a1
	- Default Subscription: c18a2d54-fae6-4708-aa27-c0ad1ed4d172

Ask the user to respond with option number (`1` or `2`) or tenant name.

### Do Not Skip

- Do not assume the currently active tenant/subscription is correct.
- Do not run deployment commands before tenant selection, login, and subscription selection are completed.
