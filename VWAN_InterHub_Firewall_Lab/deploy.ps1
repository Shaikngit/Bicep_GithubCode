#!/usr/bin/env pwsh

<#
.SYNOPSIS
Deploy Azure Virtual WAN Inter-Hub Traffic Inspection Lab

.DESCRIPTION
This script deploys a complete Virtual WAN lab demonstrating inter-hub traffic 
inspection using Azure Firewall with Routing Intent policies. The lab creates
two Virtual Hubs in different regions with Azure Firewalls and spoke VNets
connected to each hub.

.PARAMETER ResourceGroupName
Name of the resource group to create/use for the deployment
Default: rg-vwan-interhub-lab

.PARAMETER Location
Primary deployment location
Default: southeastasia

.PARAMETER AdminPassword
Password for VM administrator accounts (must meet complexity requirements)

.PARAMETER SubscriptionId
Azure subscription ID to deploy to (optional - uses current subscription if not specified)

.PARAMETER WhatIf
Perform a what-if deployment to preview changes without actually deploying

.PARAMETER Force
Skip confirmation prompts and deploy immediately

.EXAMPLE
./deploy.ps1 -AdminPassword "YourStrongPassword123!"

.EXAMPLE
./deploy.ps1 -ResourceGroupName "my-vwan-lab" -Location "eastus" -AdminPassword "YourStrongPassword123!" -Force

.EXAMPLE
./deploy.ps1 -AdminPassword "YourStrongPassword123!" -WhatIf
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-vwan-interhub-lab",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "southeastasia",
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword,
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colors = @{
        "Red" = [System.ConsoleColor]::Red
        "Green" = [System.ConsoleColor]::Green
        "Yellow" = [System.ConsoleColor]::Yellow
        "Blue" = [System.ConsoleColor]::Blue
        "Cyan" = [System.ConsoleColor]::Cyan
        "Magenta" = [System.ConsoleColor]::Magenta
        "White" = [System.ConsoleColor]::White
    }
    
    Write-Host $Message -ForegroundColor $colors[$Color]
}

# Function to validate prerequisites
function Test-Prerequisites {
    Write-ColorOutput "🔍 Checking prerequisites..." "Yellow"
    
    # Check if Azure CLI is installed
    try {
        $azVersion = az version --output json | ConvertFrom-Json
        Write-ColorOutput "✅ Azure CLI version: $($azVersion.'azure-cli')" "Green"
    }
    catch {
        Write-ColorOutput "❌ Azure CLI is not installed. Please install Azure CLI first." "Red"
        exit 1
    }
    
    # Check if logged into Azure
    try {
        $account = az account show --output json | ConvertFrom-Json
        Write-ColorOutput "✅ Logged into Azure as: $($account.user.name)" "Green"
        Write-ColorOutput "✅ Current subscription: $($account.name) ($($account.id))" "Green"
    }
    catch {
        Write-ColorOutput "❌ Not logged into Azure. Please run 'az login' first." "Red"
        exit 1
    }
    
    # Check if Bicep is available
    try {
        $bicepVersion = az bicep version
        Write-ColorOutput "✅ Azure Bicep version: $bicepVersion" "Green"
    }
    catch {
        Write-ColorOutput "⚠️  Bicep not found. Installing Bicep..." "Yellow"
        az bicep install
        Write-ColorOutput "✅ Bicep installed successfully." "Green"
    }
}

# Function to set subscription context
function Set-SubscriptionContext {
    param([string]$SubId)
    
    if ($SubId) {
        Write-ColorOutput "🔄 Setting subscription context to: $SubId" "Yellow"
        try {
            az account set --subscription $SubId
            $account = az account show --output json | ConvertFrom-Json
            Write-ColorOutput "✅ Subscription context set to: $($account.name)" "Green"
        }
        catch {
            Write-ColorOutput "❌ Failed to set subscription context. Please verify subscription ID." "Red"
            exit 1
        }
    }
}

# Function to validate password complexity
function Test-PasswordComplexity {
    param([string]$Password)
    
    $hasUpper = $Password -cmatch '[A-Z]'
    $hasLower = $Password -cmatch '[a-z]'
    $hasNumber = $Password -cmatch '[0-9]'
    $hasSpecial = $Password -cmatch '[^A-Za-z0-9]'
    $hasLength = $Password.Length -ge 12
    
    if (-not ($hasUpper -and $hasLower -and $hasNumber -and $hasSpecial -and $hasLength)) {
        Write-ColorOutput "❌ Password does not meet complexity requirements:" "Red"
        Write-ColorOutput "   - Minimum 12 characters" "Red"
        Write-ColorOutput "   - At least one uppercase letter" "Red"
        Write-ColorOutput "   - At least one lowercase letter" "Red"
        Write-ColorOutput "   - At least one number" "Red"
        Write-ColorOutput "   - At least one special character" "Red"
        exit 1
    }
    
    Write-ColorOutput "✅ Password meets complexity requirements." "Green"
}

# Function to display deployment information
function Show-DeploymentInfo {
    Write-ColorOutput "`n🏗️  VIRTUAL WAN INTER-HUB TRAFFIC INSPECTION LAB" "Cyan"
    Write-ColorOutput "===============================================" "Cyan"
    Write-ColorOutput "This lab will deploy:" "White"
    Write-ColorOutput "• Virtual WAN with 2 hubs (Southeast Asia & East Asia)" "White"
    Write-ColorOutput "• Azure Firewalls in each hub with Routing Intent" "White"
    Write-ColorOutput "• 2 spoke VNets with Ubuntu VMs for testing" "White"
    Write-ColorOutput "• Network Security Groups with SSH/ICMP rules" "White"
    Write-ColorOutput "• All networking components for traffic inspection demo" "White"
    Write-ColorOutput "`nDeployment Details:" "Yellow"
    Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
    Write-ColorOutput "• Primary Location: $Location" "White"
    Write-ColorOutput "• Deployment Type: $(if ($WhatIf) { 'What-If Preview' } else { 'Full Deployment' })" "White"
    Write-ColorOutput "• Estimated Duration: 30-45 minutes" "White"
    Write-ColorOutput "===============================================`n" "Cyan"
}

# Function to prompt for confirmation
function Get-UserConfirmation {
    if ($Force) {
        return $true
    }
    
    Write-ColorOutput "⚠️  This deployment will create multiple Azure resources and may incur costs." "Yellow"
    Write-ColorOutput "⚠️  Standard B2s VMs: ~$30-50/month per VM" "Yellow"
    Write-ColorOutput "⚠️  Azure Firewall Standard: ~$1.25/hour per firewall" "Yellow"
    Write-ColorOutput "⚠️  Virtual WAN Hub: ~$0.25/hour per hub`n" "Yellow"
    
    $response = Read-Host "Do you want to continue? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y' -or $response -eq 'yes' -or $response -eq 'YES')
}

# Main deployment function
function Start-Deployment {
    $deploymentName = "vwan-interhub-lab-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $templateFile = "main.bicep"
    
    # Check if template file exists
    if (-not (Test-Path $templateFile)) {
        Write-ColorOutput "❌ Template file '$templateFile' not found in current directory." "Red"
        Write-ColorOutput "Please ensure you are running this script from the lab directory." "Red"
        exit 1
    }
    
    Write-ColorOutput "🚀 Starting deployment: $deploymentName" "Green"
    Write-ColorOutput "📄 Template: $templateFile" "White"
    Write-ColorOutput "📍 Target: Subscription level" "White"
    Write-ColorOutput "⏰ Start time: $(Get-Date)" "White"
    
    try {
        $deploymentArgs = @(
            "deployment", "sub", "create",
            "--name", $deploymentName,
            "--location", $Location,
            "--template-file", $templateFile,
            "--parameters", "resourceGroupName=$ResourceGroupName",
            "--parameters", "primaryLocation=$Location",
            "--parameters", "adminPassword=$AdminPassword",
            "--output", "json"
        )
        
        if ($WhatIf) {
            $deploymentArgs += @("--what-if")
            Write-ColorOutput "🔍 Performing What-If analysis..." "Yellow"
        } else {
            Write-ColorOutput "🏗️  Deploying resources..." "Yellow"
        }
        
        $deploymentResult = az @deploymentArgs
        
        if ($LASTEXITCODE -eq 0) {
            if ($WhatIf) {
                Write-ColorOutput "✅ What-If analysis completed successfully." "Green"
                Write-ColorOutput "📄 Review the output above to see what would be deployed." "White"
            } else {
                $result = $deploymentResult | ConvertFrom-Json
                Write-ColorOutput "✅ Deployment completed successfully!" "Green"
                Write-ColorOutput "⏰ End time: $(Get-Date)" "White"
                
                # Display deployment outputs
                if ($result.properties.outputs) {
                    Write-ColorOutput "`n📋 DEPLOYMENT OUTPUTS" "Cyan"
                    Write-ColorOutput "=====================" "Cyan"
                    
                    $outputs = $result.properties.outputs
                    
                    if ($outputs.vmDetails) {
                        Write-ColorOutput "`n🖥️  Virtual Machine Details:" "Yellow"
                        $vmDetails = $outputs.vmDetails.value
                        foreach ($vmKey in $vmDetails.PSObject.Properties.Name) {
                            $vm = $vmDetails.$vmKey
                            Write-ColorOutput "• $($vm.name) ($($vm.location)):" "White"
                            Write-ColorOutput "  - Public IP: $($vm.publicIP)" "White"
                            Write-ColorOutput "  - Private IP: $($vm.privateIP)" "White"
                            Write-ColorOutput "  - SSH Command: $($vm.sshCommand)" "Green"
                        }
                    }
                    
                    if ($outputs.firewallDetails) {
                        Write-ColorOutput "`n🛡️  Azure Firewall Details:" "Yellow"
                        $fwDetails = $outputs.firewallDetails.value
                        foreach ($fwKey in $fwDetails.PSObject.Properties.Name) {
                            $fw = $fwDetails.$fwKey
                            Write-ColorOutput "• $($fw.name) ($($fw.location)):" "White"
                            Write-ColorOutput "  - Private IP: $($fw.privateIP)" "White"
                        }
                    }
                    
                    if ($outputs.testCommands) {
                        Write-ColorOutput "`n🧪 Test Commands:" "Yellow"
                        Write-ColorOutput "Run these commands from the VMs to test connectivity:" "White"
                        $testCmds = $outputs.testCommands.value
                        foreach ($cmdKey in $testCmds.PSObject.Properties.Name) {
                            Write-ColorOutput "• $cmdKey`: $($testCmds.$cmdKey)" "Green"
                        }
                    }
                }
                
                Write-ColorOutput "`n🎉 Lab deployment completed!" "Green"
                Write-ColorOutput "📖 Check the README.md file for testing instructions." "White"
            }
        } else {
            throw "Deployment failed with exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-ColorOutput "❌ Deployment failed: $($_.Exception.Message)" "Red"
        Write-ColorOutput "💡 Check the Azure portal for detailed error information." "Yellow"
        Write-ColorOutput "💡 Deployment name: $deploymentName" "Yellow"
        exit 1
    }
}

# Function to clean up resources
function Remove-LabResources {
    Write-ColorOutput "`n🗑️  RESOURCE CLEANUP" "Yellow"
    Write-ColorOutput "==================" "Yellow"
    Write-ColorOutput "To clean up the lab resources, run:" "White"
    Write-ColorOutput "az group delete --name $ResourceGroupName --yes --no-wait" "Green"
    Write-ColorOutput "`n⚠️  This will delete ALL resources in the resource group!" "Red"
}

# Main script execution
try {
    Write-ColorOutput "🔥 Azure Virtual WAN Inter-Hub Traffic Inspection Lab Deployer" "Cyan"
    Write-ColorOutput "============================================================`n" "Cyan"
    
    # Validate prerequisites
    Test-Prerequisites
    
    # Set subscription context if specified
    Set-SubscriptionContext -SubId $SubscriptionId
    
    # Validate password complexity
    Test-PasswordComplexity -Password $AdminPassword
    
    # Show deployment information
    Show-DeploymentInfo
    
    # Get user confirmation
    if (-not (Get-UserConfirmation)) {
        Write-ColorOutput "❌ Deployment cancelled by user." "Yellow"
        exit 0
    }
    
    # Start deployment
    Start-Deployment
    
    # Show cleanup information
    if (-not $WhatIf) {
        Remove-LabResources
    }
}
catch {
    Write-ColorOutput "❌ Script execution failed: $($_.Exception.Message)" "Red"
    exit 1
}

Write-ColorOutput "`n✨ Script execution completed." "Green"