#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys VM and Storage Account in same region using modular architecture with Azure Bastion

.DESCRIPTION
    This script deploys a Windows VM and Storage Account in the same Azure region
    using modular Bicep templates for optimal performance and data locality.
    The VM is secured with Azure Bastion - no public IP or RDP exposure.

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to (default: rg-vm-storage-sameregion)

.PARAMETER Location
    Azure region for deployment (default: southeastasia)

.PARAMETER AdminPassword
    Administrator password for the VM

.PARAMETER AdminUsername
    Administrator username for the VM

.PARAMETER VmSizeOption
    VM size option - Overlake or Non-Overlake

.PARAMETER UseCustomImage
    Use custom image from gallery (default: No)

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER WhatIf
    Preview deployment without making changes

.EXAMPLE
    .\deploy.ps1 -VmSizeOption "Non-Overlake"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-vm-storage-sameregion",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "southeastasia",
    
    [Parameter(Mandatory=$false)]
    [SecureString]$AdminPassword,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("azuser")]
    [string]$AdminUsername = "azuser",
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Overlake", "Non-Overlake")]
    [string]$VmSizeOption,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Yes", "No")]
    [string]$UseCustomImage = "No",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Enforce project VM username default
$AdminUsername = "azuser"

if ($null -eq $AdminPassword) {
    $AdminPassword = Read-Host "Enter admin password for VM deployment" -AsSecureString
}

# Helper functions
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    $colors = @{ "Red" = [ConsoleColor]::Red; "Green" = [ConsoleColor]::Green; "Yellow" = [ConsoleColor]::Yellow; "Cyan" = [ConsoleColor]::Cyan; "White" = [ConsoleColor]::White }
    Write-Host $Message -ForegroundColor $colors[$Color]
}

function Test-Prerequisites {
    Write-ColorOutput "🔍 Checking prerequisites..." "Cyan"
    $allGood = $true
    
    try { $version = az version --output json 2>$null | ConvertFrom-Json; Write-ColorOutput "✅ Azure CLI version: $($version.'azure-cli')" "Green" }
    catch { Write-ColorOutput "❌ Azure CLI not found" "Red"; $allGood = $false }
    
    try { $account = az account show --output json 2>$null | ConvertFrom-Json; Write-ColorOutput "✅ Logged into Azure as: $($account.user.name)" "Green" }
    catch { Write-ColorOutput "❌ Not logged into Azure" "Red"; $allGood = $false }
    
    try { $version = az bicep version; Write-ColorOutput "✅ Bicep CLI version: $version" "Green" }
    catch { Write-ColorOutput "❌ Bicep CLI not found" "Red"; $allGood = $false }
    
    # Check for module files
    $modules = @("simplewindows/client.bicep", "simplestorage/storage.bicep")
    foreach ($module in $modules) {
        if (Test-Path $module) {
            Write-ColorOutput "✅ Module found: $module" "Green"
        } else {
            Write-ColorOutput "❌ Module missing: $module" "Red"
            $allGood = $false
        }
    }
    
    # Password validation - convert SecureString to plain text for validation
    $plainPassword = [System.Net.NetworkCredential]::new('', $AdminPassword).Password
    if ($plainPassword.Length -ge 12 -and $plainPassword -cmatch '[A-Z]' -and $plainPassword -cmatch '[a-z]' -and $plainPassword -match '\d' -and $plainPassword -match '[^A-Za-z0-9]') {
        Write-ColorOutput "✅ Password meets complexity requirements" "Green"
    } else {
        Write-ColorOutput "❌ Password must be 12+ characters with uppercase, lowercase, digit, and special character" "Red"
        $allGood = $false
    }
    
    return $allGood
}

function Get-UserConfirmation {
    if ($Force) { return $true }
    
    Write-ColorOutput "⚠️  This deployment will create Azure resources and incur costs." "Yellow"
    Write-ColorOutput "⚠️  VM (B2s): ~$35/month" "Yellow"
    Write-ColorOutput "⚠️  Storage Account: ~$20/month" "Yellow"
    Write-ColorOutput "⚠️  Virtual Network: ~$5/month" "Yellow"
    Write-ColorOutput "⚠️  Azure Bastion (Basic): ~$140/month" "Yellow"
    Write-ColorOutput "⚠️  Total estimated cost: ~$200/month" "Yellow"
    Write-ColorOutput "✅ Same-region deployment for optimal performance!" "Green"
    Write-ColorOutput "✅ Secure access via Azure Bastion (no public RDP exposure)!" "Green"
    
    $response = Read-Host "Do you want to continue with this same-region modular deployment? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y')
}

function Start-Deployment {
    $deploymentName = "vm-storage-sameregion-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    if ($SubscriptionId) { az account set --subscription $SubscriptionId }
    
    Write-ColorOutput "📦 Creating resource group: $ResourceGroupName" "Cyan"
    az group create --name $ResourceGroupName --location $Location --output none
    
    if ($LASTEXITCODE -ne 0) { Write-ColorOutput "❌ Failed to create resource group" "Red"; exit 1 }
    
    # Convert SecureString to plain text for Azure CLI
    $plainPassword = [System.Net.NetworkCredential]::new('', $AdminPassword).Password
    
    $deployCmd = @(
        "az", "deployment", "group", "create"
        "--resource-group", $ResourceGroupName
        "--template-file", "main.bicep"
        "--name", $deploymentName
        "--parameters"
        "adminpassword=$plainPassword"
        "adminusername=$AdminUsername"
        "vmSizeOption=$VmSizeOption"
        "useCustomImage=$UseCustomImage"
    )
    
    if ($WhatIf) {
        $deployCmd += @("--what-if")
        Write-ColorOutput "🔍 Running what-if analysis for same-region modular deployment..." "Cyan"
    } else {
        Write-ColorOutput "🚀 Starting same-region modular deployment: $deploymentName" "Cyan"
        Write-ColorOutput "📄 Main template: main.bicep" "White"
        Write-ColorOutput "📦 Modules: Windows VM, storage account" "White"
        Write-ColorOutput "🏗️  Deploying VM and Storage in same region for optimal performance..." "Cyan"
        Write-ColorOutput "📍 Target Region: $Location" "White"
        Write-ColorOutput "⏱️  Estimated duration: 8-12 minutes" "Yellow"
    }
    
    & $deployCmd[0] $deployCmd[1..($deployCmd.Length-1)]
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Same-region modular deployment completed successfully!" "Green"
        if (-not $WhatIf) {
            # Get deployment outputs
            $outputs = az deployment group show --resource-group $ResourceGroupName --name $deploymentName --query "properties.outputs" --output json 2>$null | ConvertFrom-Json
            
            $vmName = $outputs.vmName.value
            $bastionName = $outputs.bastionName.value
            $vmPrivateIp = $outputs.vmPrivateIp.value
            $vmPublicIp = $outputs.vmPublicIp.value
            $vmPrincipalId = $outputs.vmPrincipalId.value
            $storageAccountName = $outputs.storageAccountName.value
            $storageBlobEndpoint = $outputs.storageBlobEndpoint.value
            $containerName = $outputs.containerName.value
            
            Write-ColorOutput "" "White"
            Write-ColorOutput "╔══════════════════════════════════════════════════════════════════╗" "Green"
            Write-ColorOutput "║           🎉 DEPLOYMENT SUCCESSFUL - QUICK START GUIDE           ║" "Green"
            Write-ColorOutput "╚══════════════════════════════════════════════════════════════════╝" "Green"
            
            Write-ColorOutput "" "White"
            Write-ColorOutput "📋 DEPLOYED RESOURCES:" "Cyan"
            Write-ColorOutput "   VM Name:              $vmName" "White"
            Write-ColorOutput "   VM Private IP:        $vmPrivateIp" "White"
            Write-ColorOutput "   VM Public IP:         $vmPublicIp" "White"
            Write-ColorOutput "   VM Managed Identity:  $vmPrincipalId" "White"
            Write-ColorOutput "   Bastion:              $bastionName" "White"
            Write-ColorOutput "   Storage Account:      $storageAccountName" "White"
            Write-ColorOutput "   Blob Endpoint:        $storageBlobEndpoint" "White"
            Write-ColorOutput "   Container:            $containerName" "White"
            Write-ColorOutput "   RBAC Role:            Storage Blob Data Contributor (assigned to VM)" "White"
            
            Write-ColorOutput "" "White"
            Write-ColorOutput "═══════════════════════════════════════════════════════════════════" "Cyan"
            Write-ColorOutput "🔐 HOW TO CONNECT TO YOUR VM VIA BASTION:" "Cyan"
            Write-ColorOutput "═══════════════════════════════════════════════════════════════════" "Cyan"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   OPTION 1: Azure Portal (Recommended)" "Yellow"
            Write-ColorOutput "   ─────────────────────────────────────" "White"
            Write-ColorOutput "   1. Go to: https://portal.azure.com" "White"
            Write-ColorOutput "   2. Navigate to: Virtual Machines > $vmName" "White"
            Write-ColorOutput "   3. Click 'Connect' > 'Connect via Bastion'" "White"
            Write-ColorOutput "   4. Enter Username: $AdminUsername" "White"
            Write-ColorOutput "   5. Enter your password and click 'Connect'" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   OPTION 2: Azure CLI" "Yellow"
            Write-ColorOutput "   ────────────────────" "White"
            Write-ColorOutput "   az network bastion rdp --name $bastionName --resource-group $ResourceGroupName --target-resource-id /subscriptions/`$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/$vmName" "White"
            
            Write-ColorOutput "" "White"
            Write-ColorOutput "═══════════════════════════════════════════════════════════════════" "Cyan"
            Write-ColorOutput "🔗 HOW TO TEST STORAGE CONNECTIVITY FROM VM:" "Cyan"
            Write-ColorOutput "═══════════════════════════════════════════════════════════════════" "Cyan"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   Once connected to VM via Bastion, run these commands:" "Yellow"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   TEST 1: Verify DNS Resolution" "Yellow"
            Write-ColorOutput "   ──────────────────────────────" "White"
            Write-ColorOutput "   nslookup $storageAccountName.blob.core.windows.net" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   TEST 2: Test Network Connectivity (Port 443)" "Yellow"
            Write-ColorOutput "   ─────────────────────────────────────────────" "White"
            Write-ColorOutput "   Test-NetConnection -ComputerName $storageAccountName.blob.core.windows.net -Port 443" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   TEST 3: List Blob Containers (requires Az module)" "Yellow"
            Write-ColorOutput "   ─────────────────────────────────────────────────" "White"
            Write-ColorOutput "   # Install Az module if not present" "White"
            Write-ColorOutput "   Install-Module -Name Az -Scope CurrentUser -Force" "White"
            Write-ColorOutput "   Connect-AzAccount" "White"
            Write-ColorOutput "   Get-AzStorageContainer -Context (New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount)" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   TEST 4: Quick HTTP Test" "Yellow"
            Write-ColorOutput "   ────────────────────────" "White"
            Write-ColorOutput "   Invoke-WebRequest -Uri '${storageBlobEndpoint}${containerName}?restype=container' -Method Head" "White"
            
            Write-ColorOutput "" "White"
            Write-ColorOutput "═══════════════════════════════════════════════════════════════════" "Cyan"
            Write-ColorOutput "🔑 ACCESS STORAGE WITH MANAGED IDENTITY (RECOMMENDED):" "Cyan"
            Write-ColorOutput "═══════════════════════════════════════════════════════════════════" "Cyan"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   The VM has a System-Assigned Managed Identity with" "Yellow"
            Write-ColorOutput "   'Storage Blob Data Contributor' role on the storage account." "Yellow"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   STEP 1: Install Azure CLI (one-time, requires internet)" "Yellow"
            Write-ColorOutput "   ─────────────────────────────────────────────────────────" "White"
            Write-ColorOutput "   Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi" "White"
            Write-ColorOutput "   Start-Process msiexec.exe -ArgumentList '/I AzureCLI.msi /quiet' -Wait" "White"
            Write-ColorOutput "   # Restart PowerShell after installation" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   STEP 2: Login with Managed Identity" "Yellow"
            Write-ColorOutput "   ────────────────────────────────────" "White"
            Write-ColorOutput "   az login --identity --allow-no-subscriptions" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   STEP 3: Upload a Single File" "Yellow"
            Write-ColorOutput "   ─────────────────────────────" "White"
            Write-ColorOutput "   `"Hello from Azure!`" | Out-File test.txt" "White"
            Write-ColorOutput "   az storage blob upload --account-name $storageAccountName --container-name $containerName --name test.txt --file `"test.txt`" --auth-mode login" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   STEP 4: Upload Multiple Files (Batch)" "Yellow"
            Write-ColorOutput "   ──────────────────────────────────────" "White"
            Write-ColorOutput "   az storage blob upload-batch --source `"C:\MyFolder`" --destination `"$containerName`" --account-name $storageAccountName --auth-mode login" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   STEP 5: List Blobs in Container" "Yellow"
            Write-ColorOutput "   ────────────────────────────────" "White"
            Write-ColorOutput "   az storage blob list --account-name $storageAccountName --container-name $containerName --auth-mode login --output table" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "   💡 TIP: The --auth-mode login flag uses Managed Identity instead of keys!" "Green"
            
            Write-ColorOutput "" "White"
            Write-ColorOutput "═══════════════════════════════════════════════════════════════════" "Cyan"
            Write-ColorOutput "🧹 CLEANUP COMMAND:" "Cyan"
            Write-ColorOutput "═══════════════════════════════════════════════════════════════════" "Cyan"
            Write-ColorOutput "   az group delete --name $ResourceGroupName --yes --no-wait" "White"
            Write-ColorOutput "" "White"
        }
    } else { Write-ColorOutput "❌ Same-region modular deployment failed" "Red"; exit 1 }
}

# Main script
Write-ColorOutput "📍 VM and Storage Same Region (Modular) Deployment" "Cyan"
Write-ColorOutput "===================================================" "Cyan"

if (-not (Test-Prerequisites)) { exit 1 }

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  VM AND STORAGE SAME REGION (MODULAR)" "Cyan"
Write-ColorOutput "=========================================" "Cyan"
Write-ColorOutput "This modular deployment creates:" "White"
Write-ColorOutput "• Windows VM module (simplewindows/client.bicep)" "White"
Write-ColorOutput "• Storage Account module (simplestorage/storage.bicep)" "White"
Write-ColorOutput "• Azure Bastion for secure VM access" "White"
Write-ColorOutput "• Co-located in same Azure region" "White"
Write-ColorOutput "• VNet with subnet configuration" "White"
Write-ColorOutput "• No public RDP exposure (secure by design)" "White"
Write-ColorOutput "• Optimized for data transfer performance" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "Deployment Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Location: $Location" "White"
Write-ColorOutput "• VM Size Option: $VmSizeOption" "White"
Write-ColorOutput "• Custom Image: $UseCustomImage" "White"
Write-ColorOutput "• VM Access: Azure Bastion (secure)" "White"
Write-ColorOutput "• Deployment Type: Modular (main + 2 modules)" "White"
Write-ColorOutput "• Optimization: Same-region co-location" "White"
Write-ColorOutput "=========================================" "Cyan"

if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Deployment cancelled by user." "Red"; exit 1
}

Start-Deployment
Write-ColorOutput "🎉 Script execution completed!" "Green"