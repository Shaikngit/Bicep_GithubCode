$resourceGroupName = "dpdk-lab-rg"

Write-Host "Deleting resource group '$resourceGroupName'..." -ForegroundColor Yellow
az group delete --name $resourceGroupName --yes --no-wait

Write-Host "Resource group deletion initiated. This may take a few minutes." -ForegroundColor Cyan
