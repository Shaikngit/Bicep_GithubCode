#Requires -Version 7.0
param(
    [Parameter(Mandatory=$false)][string]$ResourceGroupName = "rg-pe-pls-vm-intlb",
    [Parameter(Mandatory=$false)][switch]$Force,
    [Parameter(Mandatory=$false)][switch]$WhatIf
)

function Write-ColorOutput { param([string]$Message, [string]$Color = "White")
    $colors = @{ "Red" = [ConsoleColor]::Red; "Green" = [ConsoleColor]::Green; "Yellow" = [ConsoleColor]::Yellow; "Cyan" = [ConsoleColor]::Cyan; "White" = [ConsoleColor]::White; "Magenta" = [ConsoleColor]::Magenta }
    Write-Host $Message -ForegroundColor $colors[$Color] }

Write-ColorOutput "🧹 Private Endpoint + Private Link Service Cleanup" "Magenta"
Write-ColorOutput "================================================" "Magenta"

$rgExists = az group exists --name $ResourceGroupName --output tsv
if ($rgExists -eq "false") { Write-ColorOutput "✅ Nothing to clean up - resource group doesn't exist" "Green"; exit 0 }

$resources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
Write-ColorOutput "📦 Resource group: $ResourceGroupName ($($resources.Count) resources)" "Cyan"
if ($resources.Count -gt 0) {
    Write-ColorOutput "🗂️  Resources:" "Cyan"
    foreach ($resource in $resources) { Write-ColorOutput "   • $($resource.type): $($resource.name)" "White" }
}

if ($WhatIf) { Write-ColorOutput "🔍 What-if mode: Resources above would be deleted" "Yellow"; exit 0 }

if (-not $Force) {
    Write-ColorOutput "⚠️  WARNING: This will permanently delete ALL resources!" "Red"
    $response = Read-Host "Type 'yes' to confirm deletion"
    if ($response -ne "yes") { Write-ColorOutput "❌ Cleanup cancelled" "Yellow"; exit 0 }
}

Write-ColorOutput "🗑️  Deleting resource group: $ResourceGroupName" "Yellow"
az group delete --name $ResourceGroupName --yes --no-wait
if ($LASTEXITCODE -eq 0) { Write-ColorOutput "✅ Deletion initiated successfully!" "Green" } else { Write-ColorOutput "❌ Failed to delete resource group" "Red"; exit 1 }