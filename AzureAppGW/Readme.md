# Quickstart: Create an Azure WAF v2 on Application Gateway using Bicep

This quickstart demonstrates how to use Bicep to deploy an Azure Web Application Firewall (WAF) v2 on Application Gateway.

## Prerequisites

- An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/).
- Azure CLI or Azure PowerShell installed.

## Deployment

1. Save the Bicep file as **main.bicep** to your local computer.
2. Deploy the Bicep file using the following commands:

   ### Azure CLI
   ```azurecli
   az group create --name <resourcegroupname> --location <location>
   az deployment group create --resource-group <resourcegroupname> --template-file main.bicep --parameters adminUsername=<admin-user>
   ```

   ### Azure PowerShell
   ```azurepowershell
   New-AzResourceGroup -Name <resourcegroupname> -Location <location>
   New-AzResourceGroupDeployment -ResourceGroupName <resourcegroupname> -TemplateFile ./main.bicep -adminUsername "<admin-user>"
   ```

> **Note:** You'll be prompted to enter **adminPassword** for the backend servers. The password must meet Azure's complexity requirements.

## Validate the Deployment

1. Find the public IP address of the application gateway on its **Overview** page.
2. Paste the IP address into your browser. A **403 Forbidden** response confirms the WAF is blocking traffic.
3. To allow traffic, update the WAF policy using Azure PowerShell:
   ```azurepowershell
   $rgName = "<resourcegroupname>"
   $appGWName = "<appgatewayname>"
   $fwPolicyName = "<wafpolicyname>"

   $pol = Get-AzApplicationGatewayFirewallPolicy -Name $fwPolicyName -ResourceGroupName $rgName
   $pol[0].CustomRules[0].Action = "allow"
   Set-AzApplicationGatewayFirewallPolicy -Name $fwPolicyName -ResourceGroupName $rgName -CustomRule $pol.CustomRules
   ```

## Clean Up Resources

To delete the resource group and all associated resources:

### Azure CLI
```azurecli
az group delete --name <resourcegroupname> --yes --no-wait
```

### Azure PowerShell
```azurepowershell
Remove-AzResourceGroup -Name <resourcegroupname>
```

## Next Steps

Learn more about creating an application gateway with a Web Application Firewall using the [Azure portal](https://learn.microsoft.com/azure/application-gateway/application-gateway-web-application-firewall-portal).
