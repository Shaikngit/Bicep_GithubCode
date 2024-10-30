# SimpleVM-Linux

This repository contains a Bicep template to deploy a simple Linux Virtual Machine (VM) on Azure.

## Prerequisites

- Azure subscription
- Azure CLI installed
- Bicep CLI installed

## Deployment

To deploy the VM, follow these steps:

1. Clone the repository:
    ```sh
    git clone https://github.com/yourusername/SimpleVM-Linux.git
    cd SimpleVM-Linux
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

## Template Details

The Bicep template (`main.bicep`) includes the following resources:
- A Linux Virtual Machine
- A Virtual Network
- A Network Interface
- A Public IP Address
- A Network Security Group

## Cleanup

To remove the deployed resources, delete the resource group:
```sh
az group delete --name myResourceGroup --no-wait --yes
```

