#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys two VMSS behind Public Load Balancers across Southeast Asia and East Asia regions

.DESCRIPTION
    This script deploys:
    - VMSS in Southeast Asia behind a Public Load Balancer (no instance public IPs)
    - VMSS in East Asia behind a Public Load Balancer (no instance public IPs)
    - Azure Bastion in both regions for secure VM access
    - NSG rules allowing SSH (22), HTTP (80), and HTTPS (443)
    - Custom script extension to install nginx with self-signed SSL
    - Outbound SNAT via Load Balancer VIP
    
    Traffic flow: SEA VMs -> SEA LB (SNAT) -> Internet -> EA LB VIP -> EA VMs

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to (default: rg-vmss-crossregion)

.PARAMETER AdminUsername
    Administrator username for the VMs

.PARAMETER AdminPassword
    Administrator password for the VMs

.PARAMETER ResourcePrefix
    Prefix for resource names (default: vmss)

.PARAMETER InstanceCount
    Number of VM instances per VMSS (default: 2)

.PARAMETER UbuntuOSVersion
    Ubuntu OS version (Ubuntu-2004 or Ubuntu-2204, default: Ubuntu-2204)

.PARAMETER VmSize
    VM SKU size (default: Standard_D2s_v4)

.PARAMETER SubscriptionId
    Azure subscription ID (optional)

.PARAMETER WhatIf
    Preview deployment without making changes

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPassword "YourP@ssword123!"

.EXAMPLE
    .\deploy.ps1 -AdminUsername "azureuser" -AdminPassword "YourP@ssword123!" -InstanceCount 3
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-vmss-crossregion",
    
    [Parameter(Mandatory=$true)]
    [string]$AdminUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourcePrefix = "vmss",
    
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 10)]
    [int]$InstanceCount = 2,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Ubuntu-2004", "Ubuntu-2204")]
    [string]$UbuntuOSVersion = "Ubuntu-2204",
    
    [Parameter(Mandatory=$false)]
    [string]$VmSize = "Standard_D2s_v4",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# =============================================================================
# VARIABLES
# =============================================================================
$Location1 = "southeastasia"
$Location2 = "eastasia"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colors = @{
        "Red" = [ConsoleColor]::Red
        "Green" = [ConsoleColor]::Green
        "Yellow" = [ConsoleColor]::Yellow
        "Cyan" = [ConsoleColor]::Cyan
        "White" = [ConsoleColor]::White
        "Magenta" = [ConsoleColor]::Magenta
    }
    
    Write-Host $Message -ForegroundColor $colors[$Color]
}

function Test-AzureCLI {
    try {
        $version = az version --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Azure CLI version: $($version.'azure-cli')" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "❌ Azure CLI not found. Please install Azure CLI." "Red"
        return $false
    }
}

function Test-AzureLogin {
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✅ Logged into Azure as: $($account.user.name)" "Green"
        Write-ColorOutput "✅ Current subscription: $($account.name) ($($account.id))" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "❌ Not logged into Azure. Please run 'az login'." "Red"
        return $false
    }
}

function Test-BicepCLI {
    try {
        $version = az bicep version 2>$null
        Write-ColorOutput "✅ Azure Bicep version: $version" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "❌ Bicep CLI not found. Installing..." "Yellow"
        az bicep install
        return $true
    }
}

function Test-PasswordComplexity {
    param([string]$Password)
    
    $hasUpper = $Password -cmatch '[A-Z]'
    $hasLower = $Password -cmatch '[a-z]'
    $hasDigit = $Password -match '\d'
    $hasSpecial = $Password -match '[^A-Za-z0-9]'
    $hasLength = $Password.Length -ge 12
    
    if ($hasUpper -and $hasLower -and $hasDigit -and $hasSpecial -and $hasLength) {
        Write-ColorOutput "✅ Password meets complexity requirements." "Green"
        return $true
    } else {
        Write-ColorOutput "❌ Password must be 12+ characters with uppercase, lowercase, digit, and special character." "Red"
        return $false
    }
}

function Test-Prerequisites {
    Write-ColorOutput "🔍 Checking prerequisites..." "Cyan"
    
    $azCliOk = Test-AzureCLI
    $azLoginOk = Test-AzureLogin
    $bicepOk = Test-BicepCLI
    $passwordOk = Test-PasswordComplexity -Password $AdminPassword
    
    return ($azCliOk -and $azLoginOk -and $bicepOk -and $passwordOk)
}

function Get-UserConfirmation {
    if ($Force) {
        return $true
    }
    
    Write-ColorOutput "⚠️  This deployment will create Azure resources and may incur costs." "Yellow"
    Write-ColorOutput "⚠️  2x VMSS with $InstanceCount instances each, 2x Load Balancers, 2x Bastion" "Yellow"
    Write-ColorOutput "" "White"
    
    $response = Read-Host "Do you want to continue? (y/N)"
    return ($response -eq 'y' -or $response -eq 'Y' -or $response -eq 'yes' -or $response -eq 'YES')
}

function Start-Deployment {
    $deploymentName = "vmss-crossregion-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $templateFile = Join-Path $PSScriptRoot "main.bicep"
    
    # Set subscription if provided
    if ($SubscriptionId) {
        Write-ColorOutput "🎯 Setting subscription: $SubscriptionId" "Cyan"
        az account set --subscription $SubscriptionId
    }
    
    # Create resource group in the primary location
    Write-ColorOutput "📦 Creating resource group: $ResourceGroupName in $Location1" "Cyan"
    az group create --name $ResourceGroupName --location $Location1 --output none
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Failed to create resource group" "Red"
        exit 1
    }
    
    # Build deployment command
    $deployParams = @(
        "adminUsername=$AdminUsername"
        "adminPassword=$AdminPassword"
        "resourcePrefix=$ResourcePrefix"
        "location1=$Location1"
        "location2=$Location2"
        "instanceCount=$InstanceCount"
        "ubuntuOSVersion=$UbuntuOSVersion"
        "vmSize=$VmSize"
    )
    
    if ($WhatIf) {
        Write-ColorOutput "🔍 Running what-if analysis..." "Cyan"
        az deployment group create `
            --resource-group $ResourceGroupName `
            --template-file $templateFile `
            --name $deploymentName `
            --parameters $deployParams `
            --what-if
    } else {
        Write-ColorOutput "🚀 Starting deployment: $deploymentName" "Cyan"
        Write-ColorOutput "📄 Template: $templateFile" "White"
        Write-ColorOutput "📍 Target: Resource Group '$ResourceGroupName'" "White"
        Write-ColorOutput "🌏 Regions: $Location1, $Location2" "White"
        Write-ColorOutput "⏰ Start time: $(Get-Date)" "White"
        Write-ColorOutput "🏗️  Deploying resources (this may take 10-15 minutes)..." "Cyan"
        
        az deployment group create `
            --resource-group $ResourceGroupName `
            --template-file $templateFile `
            --name $deploymentName `
            --parameters $deployParams `
            --output none
    }
    
    if ($LASTEXITCODE -eq 0) {
        if ($WhatIf) {
            Write-ColorOutput "✅ What-if analysis completed successfully!" "Green"
        } else {
            Write-ColorOutput "✅ Deployment completed successfully!" "Green"
            Write-ColorOutput "⏰ End time: $(Get-Date)" "White"
            
            # Wait for extensions to complete
            Write-ColorOutput "⏳ Waiting for custom script extensions to complete (nginx installation)..." "Yellow"
            Start-Sleep -Seconds 60
            
            # Get Load Balancer Public IPs
            Write-ColorOutput "" "White"
            Write-ColorOutput "📊 LOAD BALANCER PUBLIC IPs:" "Cyan"
            Write-ColorOutput "=============================" "Cyan"
            
            $seaLbIP = az network public-ip show --resource-group $ResourceGroupName --name "$ResourcePrefix-lb-pip-sea" --query "ipAddress" -o tsv 2>$null
            $eaLbIP = az network public-ip show --resource-group $ResourceGroupName --name "$ResourcePrefix-lb-pip-ea" --query "ipAddress" -o tsv 2>$null
            
            Write-ColorOutput "" "White"
            Write-ColorOutput "🌏 Southeast Asia Load Balancer VIP: $seaLbIP" "Magenta"
            Write-ColorOutput "🌏 East Asia Load Balancer VIP:      $eaLbIP" "Magenta"
            
            # Display architecture
            Write-ColorOutput "" "White"
            Write-ColorOutput "📐 ARCHITECTURE:" "Cyan"
            Write-ColorOutput "================" "Cyan"
            Write-ColorOutput "" "White"
            Write-ColorOutput "┌─────────────────────────────────────────────────────────────────────┐" "White"
            Write-ColorOutput "│  Southeast Asia                    East Asia                       │" "White"
            Write-ColorOutput "│  ┌─────────────────────┐          ┌─────────────────────┐          │" "White"
            Write-ColorOutput "│  │ VMSS (no public IP) │          │ VMSS (no public IP) │          │" "White"
            Write-ColorOutput "│  │    ┌───┐ ┌───┐      │          │    ┌───┐ ┌───┐      │          │" "White"
            Write-ColorOutput "│  │    │VM0│ │VM1│      │          │    │VM0│ │VM1│      │          │" "White"
            Write-ColorOutput "│  │    └─┬─┘ └─┬─┘      │          │    └─┬─┘ └─┬─┘      │          │" "White"
            Write-ColorOutput "│  │      └──┬──┘        │          │      └──┬──┘        │          │" "White"
            Write-ColorOutput "│  │    ┌────┴────┐      │          │    ┌────┴────┐      │          │" "White"
            Write-ColorOutput "│  │    │   LB    │      │          │    │   LB    │      │          │" "White"
            Write-ColorOutput "│  │    │ (SNAT)  │      │          │    │ (SNAT)  │      │          │" "White"
            Write-ColorOutput "│  │    └────┬────┘      │          │    └────┬────┘      │          │" "White"
            Write-ColorOutput "│  │         │           │          │         │           │          │" "White"
            Write-ColorOutput "│  │    ┌────┴────┐      │          │    ┌────┴────┐      │          │" "White"
            Write-ColorOutput "│  │    │$seaLbIP│      │  <---->  │    │$eaLbIP│      │          │" "White"
            Write-ColorOutput "│  │    └─────────┘      │          │    └─────────┘      │          │" "White"
            Write-ColorOutput "│  └─────────────────────┘          └─────────────────────┘          │" "White"
            Write-ColorOutput "│                        Public Internet                             │" "White"
            Write-ColorOutput "└─────────────────────────────────────────────────────────────────────┘" "White"
            
            # Display connectivity test instructions
            Write-ColorOutput "" "White"
            Write-ColorOutput "🔗 CONNECTIVITY TEST INSTRUCTIONS:" "Cyan"
            Write-ColorOutput "===================================" "Cyan"
            Write-ColorOutput "" "White"
            Write-ColorOutput "1️⃣  Connect to a Southeast Asia VM via Azure Bastion:" "Yellow"
            Write-ColorOutput "    → Azure Portal → VMSS '$ResourcePrefix-vmss-sea' → Instances → Select Instance → Connect → Bastion" "White"
            Write-ColorOutput "    → Username: $AdminUsername" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "2️⃣  From the SEA VM, test connectivity to East Asia Load Balancer (port 443):" "Yellow"
            Write-ColorOutput "" "White"
            Write-ColorOutput "    # Test HTTPS (port 443) - traffic SNATs via SEA LB VIP ($seaLbIP)" "Green"
            Write-ColorOutput "    curl -k https://$eaLbIP" "Green"
            Write-ColorOutput "" "White"
            Write-ColorOutput "    # Test HTTP (port 80)" "Green"
            Write-ColorOutput "    curl http://$eaLbIP" "Green"
            Write-ColorOutput "" "White"
            Write-ColorOutput "    # Multiple requests to see load balancing across EA VMs" "Green"
            Write-ColorOutput "    for i in {1..5}; do curl -s http://$eaLbIP; done" "Green"
            Write-ColorOutput "" "White"
            Write-ColorOutput "3️⃣  Verify your outbound IP (should be SEA LB VIP):" "Yellow"
            Write-ColorOutput "" "White"
            Write-ColorOutput "    curl ifconfig.me" "Green"
            Write-ColorOutput "    # Expected output: $seaLbIP" "White"
            Write-ColorOutput "" "White"
            Write-ColorOutput "4️⃣  Test from East Asia to Southeast Asia (reverse direction):" "Yellow"
            Write-ColorOutput "" "White"
            Write-ColorOutput "    # From EA VM (via Bastion):" "Green"
            Write-ColorOutput "    curl -k https://$seaLbIP" "Green"
            Write-ColorOutput "    curl http://$seaLbIP" "Green"
            Write-ColorOutput "" "White"
            Write-ColorOutput "📋 NOTES:" "Yellow"
            Write-ColorOutput "• VMs have NO public IPs - all outbound traffic SNATs via Load Balancer VIP" "White"
            Write-ColorOutput "• Use Azure Bastion to SSH into VMs (no direct SSH from internet)" "White"
            Write-ColorOutput "• Self-signed SSL certificate (use -k flag with curl)" "White"
            Write-ColorOutput "• Traffic flow: SEA VM → SEA LB (SNAT: $seaLbIP) → Internet → EA LB ($eaLbIP) → EA VM" "White"
        }
    } else {
        Write-ColorOutput "❌ Deployment failed with exit code: $LASTEXITCODE" "Red"
        Write-ColorOutput "💡 Check the Azure portal for detailed error information." "Yellow"
        Write-ColorOutput "💡 Deployment name: $deploymentName" "Yellow"
        exit 1
    }
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

Write-ColorOutput "🔥 VMSS Cross-Region with Load Balancer Deployment Script" "Cyan"
Write-ColorOutput "==========================================================" "Cyan"

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-ColorOutput "❌ Prerequisites check failed. Please resolve the issues above." "Red"
    exit 1
}

Write-ColorOutput "" "White"
Write-ColorOutput "🏗️  VMSS CROSS-REGION WITH LOAD BALANCER DEPLOYMENT" "Cyan"
Write-ColorOutput "====================================================" "Cyan"
Write-ColorOutput "This script will deploy:" "White"
Write-ColorOutput "• VMSS in Southeast Asia with $InstanceCount instances (NO public IPs)" "White"
Write-ColorOutput "• VMSS in East Asia with $InstanceCount instances (NO public IPs)" "White"
Write-ColorOutput "• Public Load Balancer in each region (HTTP/HTTPS + SNAT)" "White"
Write-ColorOutput "• Azure Bastion in each region for secure VM access" "White"
Write-ColorOutput "• Nginx with self-signed SSL on each instance" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "Traffic Flow:" "White"
Write-ColorOutput "• Outbound: VM → Load Balancer (SNAT with LB VIP) → Internet" "White"
Write-ColorOutput "• Inbound: Internet → Load Balancer VIP → Backend VMs" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "Deployment Details:" "White"
Write-ColorOutput "• Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "• Locations: $Location1, $Location2" "White"
Write-ColorOutput "• Ubuntu Version: $UbuntuOSVersion" "White"
Write-ColorOutput "• VM Size: $VmSize" "White"
Write-ColorOutput "• Instance Count per VMSS: $InstanceCount" "White"
if ($WhatIf) {
    Write-ColorOutput "• Deployment Type: What-If Analysis" "Yellow"
} else {
    Write-ColorOutput "• Deployment Type: Full Deployment" "White"
    Write-ColorOutput "• Estimated Duration: 10-15 minutes" "White"
}
Write-ColorOutput "====================================================" "Cyan"
Write-ColorOutput "" "White"

# Get user confirmation
if (-not (Get-UserConfirmation)) {
    Write-ColorOutput "❌ Deployment cancelled by user." "Red"
    exit 1
}

# Start deployment
Start-Deployment

Write-ColorOutput "" "White"
Write-ColorOutput "🎉 Script execution completed!" "Green"
