#Requires -Version 7.0

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-AzureLogin {
    try {
        $context = Get-AzContext -ErrorAction SilentlyContinue
        if (-not $context) {
            Write-Log "No Azure session found. Launching Connect-AzAccount..." "WARNING"
            Connect-AzAccount -ErrorAction Stop | Out-Null
        }

        $context = Get-AzContext
        Write-Log "Connected to Azure subscription: $($context.Subscription.Name)" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Azure authentication failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Remove-LabResourceGroup {
    param([string]$Name)

    $rg = Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Log "Resource group '$Name' does not exist." "WARNING"
        return $false
    }

    $resources = Get-AzResource -ResourceGroupName $Name -ErrorAction SilentlyContinue
    Write-Log "Found $($resources.Count) resource(s) in '$Name'." "INFO"
    foreach ($resource in $resources) {
        Write-Log " - $($resource.Name) [$($resource.ResourceType)]" "INFO"
    }

    if (-not $Force) {
        $confirmation = Read-Host "Type 'DELETE' to permanently remove resource group '$Name'"
        if ($confirmation -ne 'DELETE') {
            Write-Log "Cleanup canceled by user." "WARNING"
            return $false
        }
    }

    try {
        $startTime = Get-Date
        Write-Log "Starting deletion of resource group '$Name'..." "INFO"
        Remove-AzResourceGroup -Name $Name -Force -AsJob | Out-Null
        $duration = New-TimeSpan -Start $startTime -End (Get-Date)
        Write-Log "Deletion job started for '$Name' in $($duration.TotalSeconds.ToString('F1')) seconds." "SUCCESS"
        Write-Log "Use 'Get-AzResourceGroup -Name $Name' to check when deletion completes." "INFO"
        return $true
    }
    catch {
        Write-Log "Failed to start deletion: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

Write-Log "=== Cross-Region VNet Peering Lab Cleanup ===" "INFO"

if (-not (Test-AzureLogin)) {
    exit 1
}

if (-not (Remove-LabResourceGroup -Name $ResourceGroupName)) {
    exit 1
}

Write-Log "Cleanup workflow completed." "SUCCESS"
exit 0
