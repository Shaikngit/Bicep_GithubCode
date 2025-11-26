# ============================================================================
# VWAN Route Table Isolation Lab - Deployment Script
# ============================================================================
# This script deploys the Virtual WAN Route Table Isolation Lab using Azure CLI
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "southeastasia",

    [Parameter(Mandatory = $true)]
    [string]$AdminUsername,

    [Parameter(Mandatory = $true)]
    [string]$AdminPassword,

    [Parameter(Mandatory = $false)]
    [string]$VmSize = "Standard_B2s",

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# ============================================================================
# Functions
# ============================================================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." "INFO"
    
    # Check if Azure CLI is installed
    try {
        $azVersion = az version --output json 2>$null | ConvertFrom-Json
        Write-Log "Azure CLI version: $($azVersion.'azure-cli')" "SUCCESS"
    }
    catch {
        Write-Log "Azure CLI is not installed. Please install Azure CLI first." "ERROR"
        exit 1
    }
    
    # Check if logged into Azure
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        Write-Log "Logged in as: $($account.user.name)" "SUCCESS"
        Write-Log "Subscription: $($account.name) ($($account.id))" "INFO"
    }
    catch {
        Write-Log "Not logged into Azure. Please run 'az login' first." "ERROR"
        exit 1
    }
    
    # Check if Bicep is available
    try {
        $bicepVersion = az bicep version 2>$null
        Write-Log "Bicep version: $bicepVersion" "SUCCESS"
    }
    catch {
        Write-Log "Bicep not found. Installing Bicep..." "WARNING"
        az bicep install
        Write-Log "Bicep installed successfully." "SUCCESS"
    }
}

# ============================================================================
# Main Script
# ============================================================================
Write-Log "========================================" "INFO"
Write-Log "VWAN Route Table Isolation Lab Deployment" "INFO"
Write-Log "========================================" "INFO"

# Check prerequisites
Test-Prerequisites

# Display deployment info
Write-Log "" "INFO"
Write-Log "Deployment Details:" "INFO"
Write-Log "  Resource Group: $ResourceGroupName" "INFO"
Write-Log "  Location: $Location" "INFO"
Write-Log "  VM Size: $VmSize" "INFO"
Write-Log "" "INFO"
Write-Log "Resources to be deployed:" "INFO"
Write-Log "  - Virtual WAN: vwan-test (SoutheastAsia)" "INFO"
Write-Log "  - Virtual Hub: vhub-test (SoutheastAsia)" "INFO"
Write-Log "  - Hub VPN Gateway (SoutheastAsia)" "INFO"
Write-Log "  - 3 VNets with VMs: VNet_A, VNet_B, VNet_C (SoutheastAsia)" "INFO"
Write-Log "  - 2 Branch VNets with VPN Gateways: Branch_A, Branch_B (EastAsia)" "INFO"
Write-Log "  - Custom Route Tables: RouteTable_A, RouteTable_B" "INFO"
Write-Log "" "INFO"
Write-Log "This deployment will take approximately 45-60 minutes" "WARNING"
Write-Log "" "INFO"

# Confirmation
if (-not $Force -and -not $WhatIf) {
    Write-Log "This deployment will create multiple Azure resources and may incur costs." "WARNING"
    Write-Log "  - VPN Gateways (VpnGw1): ~$140/month each x 3" "WARNING"
    Write-Log "  - Virtual Hub: ~$0.25/hour" "WARNING"
    Write-Log "  - VMs (Standard_B2s): ~$30/month each x 5" "WARNING"
    Write-Log "" "INFO"
    
    $response = Read-Host "Do you want to continue? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y' -and $response -ne 'yes') {
        Write-Log "Deployment cancelled by user." "INFO"
        exit 0
    }
}

# Create resource group
Write-Log "Creating resource group: $ResourceGroupName in $Location" "INFO"
az group create --name $ResourceGroupName --location $Location --output none
if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to create resource group." "ERROR"
    exit 1
}
Write-Log "Resource group created successfully" "SUCCESS"

# Deploy Bicep template
$deploymentName = "vwan-isolation-lab-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$templateFile = Join-Path $PSScriptRoot "main.bicep"

Write-Log "" "INFO"
Write-Log "Starting deployment: $deploymentName" "INFO"
Write-Log "Template: $templateFile" "INFO"
Write-Log "Start time: $(Get-Date)" "INFO"
Write-Log "" "INFO"

$startTime = Get-Date

try {
    $deploymentArgs = @(
        "deployment", "group", "create",
        "--name", $deploymentName,
        "--resource-group", $ResourceGroupName,
        "--template-file", $templateFile,
        "--parameters", "adminUsername=$AdminUsername",
        "--parameters", "adminPassword=$AdminPassword",
        "--parameters", "vmSize=$VmSize",
        "--output", "json"
    )
    
    if ($WhatIf) {
        $deploymentArgs += @("--what-if")
        Write-Log "Performing What-If analysis..." "INFO"
    } else {
        Write-Log "Deploying resources (this will take 45-60 minutes)..." "INFO"
    }
    
    $deploymentResult = az @deploymentArgs 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        if ($WhatIf) {
            Write-Log "What-If analysis completed successfully." "SUCCESS"
            Write-Host $deploymentResult
        } else {
            $result = $deploymentResult | ConvertFrom-Json
            
            Write-Log "========================================" "SUCCESS"
            Write-Log "Deployment completed successfully!" "SUCCESS"
            Write-Log "Duration: $($duration.Hours)h $($duration.Minutes)m $($duration.Seconds)s" "SUCCESS"
            Write-Log "========================================" "SUCCESS"
            
            # Display outputs
            if ($result.properties.outputs) {
                $outputs = $result.properties.outputs
                
                Write-Log "" "INFO"
                Write-Log "=== DEPLOYMENT OUTPUTS ===" "INFO"
                
                Write-Log "" "INFO"
                Write-Log "Virtual WAN:" "INFO"
                Write-Log "  ID: $($outputs.virtualWanId.value)" "INFO"
                Write-Log "  Name: $($outputs.virtualWanName.value)" "INFO"
                
                Write-Log "" "INFO"
                Write-Log "Virtual Hub:" "INFO"
                Write-Log "  ID: $($outputs.virtualHubId.value)" "INFO"
                Write-Log "  Name: $($outputs.virtualHubName.value)" "INFO"
                
                Write-Log "" "INFO"
                Write-Log "Route Tables:" "INFO"
                $routeTables = $outputs.routeTableNames.value
                Write-Log "  RouteTable_A: $($routeTables.routeTableA)" "INFO"
                Write-Log "  RouteTable_B: $($routeTables.routeTableB)" "INFO"
                Write-Log "  Default: $($routeTables.defaultRouteTable)" "INFO"
                
                Write-Log "" "INFO"
                Write-Log "VPN Gateway Public IPs:" "INFO"
                $vpnIps = $outputs.vpnGatewayPublicIps.value
                Write-Log "  Branch_A Gateway: $($vpnIps.branchAGatewayPip)" "INFO"
                Write-Log "  Branch_B Gateway: $($vpnIps.branchBGatewayPip)" "INFO"
                Write-Log "  Hub VPN Gateway: $($vpnIps.hubVpnGatewayIp)" "INFO"
                
                Write-Log "" "INFO"
                Write-Log "VNet Connection Names:" "INFO"
                foreach ($conn in $outputs.vnetConnectionNames.value) {
                    Write-Log "  - $conn" "INFO"
                }
                
                Write-Log "" "INFO"
                Write-Log "VM Private IPs:" "INFO"
                $vmIps = $outputs.vmPrivateIps.value
                Write-Log "  vm-a (VNet_A): $($vmIps.vmA)" "INFO"
                Write-Log "  vm-b (VNet_B): $($vmIps.vmB)" "INFO"
                Write-Log "  vm-c (VNet_C): $($vmIps.vmC)" "INFO"
                Write-Log "  vm-branchA (Branch_A): $($vmIps.vmBranchA)" "INFO"
                Write-Log "  vm-branchB (Branch_B): $($vmIps.vmBranchB)" "INFO"
                
                Write-Log "" "INFO"
                Write-Log "========================================" "INFO"
                Write-Log "POST-DEPLOYMENT TESTING INSTRUCTIONS" "INFO"
                Write-Log "========================================" "INFO"
                Write-Log "" "INFO"
                Write-Log "IMPORTANT: Wait 5-10 minutes after deployment for BGP routes to propagate" "WARNING"
                Write-Log "" "INFO"
                Write-Log "A. Validate VNet_A Isolation (from vm-a):" "INFO"
                Write-Log "   ping $($vmIps.vmBranchA) --> MUST FAIL (isolated)" "INFO"
                Write-Log "   ping $($vmIps.vmBranchB) --> MUST FAIL (isolated)" "INFO"
                Write-Log "   ping $($vmIps.vmB) --> Should succeed" "INFO"
                Write-Log "   ping $($vmIps.vmC) --> Should succeed" "INFO"
                Write-Log "" "INFO"
                Write-Log "B. Validate Branch Isolation (from vm-branchA/B):" "INFO"
                Write-Log "   ping $($vmIps.vmA) --> MUST FAIL (isolated)" "INFO"
                Write-Log "   ping $($vmIps.vmB) --> Should succeed" "INFO"
                Write-Log "   ping $($vmIps.vmC) --> Should succeed" "INFO"
                Write-Log "" "INFO"
                Write-Log "C. Test Full Mesh (from vm-b and vm-c):" "INFO"
                Write-Log "   Can ping all VMs including branches" "INFO"
                Write-Log "========================================" "INFO"
                
                # Save outputs to file
                $outputFile = Join-Path $PSScriptRoot "deployment-outputs.json"
                $outputs | ConvertTo-Json -Depth 10 | Out-File $outputFile
                Write-Log "Outputs saved to: $outputFile" "SUCCESS"
            }
        }
    }
    else {
        Write-Log "Deployment failed!" "ERROR"
        Write-Host $deploymentResult
        exit 1
    }
}
catch {
    Write-Log "Deployment failed: $_" "ERROR"
    exit 1
}
