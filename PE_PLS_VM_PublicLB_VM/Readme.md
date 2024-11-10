# Bicep Deployment Script

This repository contains a Bicep script for Lab purpose of Private End point / Private Link Service

The PLS is associated to ALB of the backend VM 

## File Structure

- `main.bicep`: The main Bicep script that defines the infrastructure.
  
## Prerequisites

- VS Code installed
- Azure CLI installed
- Bicep Extension installed in VS Code

## Deployment

To deploy the resources defined in the `main.bicep` file, use the following command:

```Terminal

az group create --name <resourcegroupname> --location <location>

az deployment group create --resource-group <resourcegroupname> --template-file main.bicep 
```
To deploy the resources with custom image defined in the `main.bicep` file, use the following command:

```Terminal 

az deployment group create --resource-group peplspublicshaiknlab --template-file main.bicep --parameters useCustomImage=Yes
```

## Input 

- Admin Username
- Admin Password
- Public IP Address of your machine to allow RDP

## Output

- Public IP Address of the VM to connect via RDP

## Clean up deployment

To remove the resources that were created as part of this deployment, use the following command:

```Terminal
az group delete --name <resourcegroupname> --yes --no-wait
```

## Notes

Multiple Azure resources are defined in the Bicep file:

- Microsoft.Network/virtualNetworks: There's one virtual network for each virtual machine.
- Microsoft.Network/loadBalancers: The load balancer that exposes the virtual machines that host the service.
- Microsoft.Network/networkInterfaces: There are two network interfaces, one for each virtual machine.
- Microsoft.Compute/virtualMachines: There are two virtual machines, one that hosts the service and one that tests the connection to the private endpoint.
- Microsoft.Compute/virtualMachines/extensions: The extension that installs a web server.
- Microsoft.Network/privateLinkServices: The private link service to expose the service.
- Microsoft.Network/publicIpAddresses: There is a public IP address for the test virtual machine.
- Microsoft.Network/privateendpoints: The private endpoint to access the service.

## Connect 

## Connect to a VM from the Internet

There are two VMs in this lab: mySvcVm{uniqueid} and myCnsmrvm{uniqueid}. You'll connect to myCnsmrvm{uniqueid} from the internet and access the HTTP service privately from the VM. mySvcVm{uniqueid} hosts the HTTP service which is behind the private link service and exposed through the private endpoint. myCnsmrvm{uniqueid} is used to access the HTTP service privately.

Connect to the VM `myCnsmrvm{uniqueid}` from the internet as follows:

Access the http service privately from the VM
## Access the HTTP Service Privately from the VM

Here's how to connect to the HTTP service from the VM by using the private endpoint:
Go to the Remote Desktop of myConsumerVm{uniqueid}.
Open a browser, and enter the private endpoint address: http://10.0.0.5/.
The default IIS page appears.
