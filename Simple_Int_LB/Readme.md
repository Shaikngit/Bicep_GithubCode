# SimpleVM-Linux

This repository contains a Bicep template to to create a Internal Azure load balancer

The internal load balancer distributes traffic to virtual machines in a virtual network located in the load balancer's backend pool. 

Along with the internal load balancer, this template creates a virtual network, network interfaces, a NAT Gateway, and an Azure Bastion instance

## Prerequisites

- Azure subscription
- Azure CLI installed
- Bicep CLI installed

## Deployment

To deploy the VM, follow these steps:

1. Clone the repository:
    ```sh
    git clone https://github.com/yourusername/SimpleVM_Int_LB
    cd SimpleVM_Int_LB
    ```

2. Log in to your Azure account:
    ```sh
    az login
    ```

3. Create a resource group:
    ```sh
    az group create --name myResourceGroup --location eastus
    ```

4. Deploy the Bicep template:
    ```sh
    az deployment group create --resource-group myResourceGroup --template-file main.bicep
    ```

## Input 

- Resource Group Name
- Location
- Admin Username
- Admin Password
- Public IP Address of your machine to allow RDP


## Template Details

Multiple Azure resources have been defined in the bicep file:

Microsoft.Network/virtualNetworks: Virtual network for load balancer and virtual machines.
Microsoft.Network/networkInterfaces: Network interfaces for virtual machines.
Microsoft.Network/loadBalancers: Internal load balancer.
Microsoft.Network/natGateways
Microsoft.Network/publicIPAddresses: Public IP addresses for the NAT Gateway and Azure Bastion.
Microsoft.Compute/virtualMachines: Virtual machines in the backend pool.
Microsoft.Network/bastionHosts: Azure Bastion instance.
Microsoft.Network/virtualNetworks/subnets: Subnets for the virtual network.
Microsoft.Storage/storageAccounts: Storage account for the virtual machines.

## Architecture Diagram

![Public Load Balancer Architecture](./internal-load-balancer-resources.png)

## Cleanup

To remove the deployed resources, delete the resource group:
```sh
az group delete --name myResourceGroup --no-wait --yes
```

