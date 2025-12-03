@description('Username for the Virtual Machines.')
param adminUsername string

@description('Password for the Virtual Machines.')
@secure()
param adminPassword string

@description('Unique prefix for resource names.')
param resourcePrefix string = 'vmss'

@description('Location for the Southeast Asia VMSS.')
param location1 string = 'southeastasia'

@description('Location for the East Asia VMSS.')
param location2 string = 'eastasia'

@description('Number of VM instances per VMSS.')
@minValue(1)
@maxValue(10)
param instanceCount int = 2

@description('The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version.')
@allowed([
  'Ubuntu-2004'
  'Ubuntu-2204'
])
param ubuntuOSVersion string = 'Ubuntu-2204'

@description('VM SKU size.')
param vmSize string = 'Standard_D2s_v4'

// Image reference mapping
var imageReference = {
  'Ubuntu-2004': {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-focal'
    sku: '20_04-lts-gen2'
    version: 'latest'
  }
  'Ubuntu-2204': {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    version: 'latest'
  }
}

// Custom script to install nginx for HTTPS endpoint testing
var customScript = '''
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Wait for cloud-init and apt to finish
sleep 30
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
  sleep 10
done

# Enable universe repository (required for nginx on Ubuntu 22.04)
add-apt-repository -y universe

# Update package lists
apt-get update -y

# Install nginx
apt-get install -y nginx

# Create SSL directory and generate self-signed certificate
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/nginx.key \
  -out /etc/nginx/ssl/nginx.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Get hostname for response
MYHOSTNAME=$(hostname)

# Configure nginx with SSL
cat > /etc/nginx/sites-available/default << NGINXEOF
server {
    listen 443 ssl;
    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;
    location / {
        return 200 "Hello from VMSS instance: ${MYHOSTNAME}\n";
        add_header Content-Type text/plain;
    }
}
server {
    listen 80;
    location / {
        return 200 "Hello from VMSS instance: ${MYHOSTNAME} - HTTP\n";
        add_header Content-Type text/plain;
    }
}
NGINXEOF

# Restart and enable nginx
systemctl restart nginx
systemctl enable nginx
echo "Nginx installation completed successfully"
'''

// ============================================================================
// SOUTHEAST ASIA RESOURCES
// ============================================================================

resource vnet1 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${resourcePrefix}-vnet-sea'
  location: location1
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'vmss-subnet'
        properties: {
          addressPrefix: '10.1.0.0/24'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.1.1.0/26'
        }
      }
    ]
  }
}

// Azure Bastion Public IP - Southeast Asia
resource bastionPip1 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${resourcePrefix}-bastion-pip-sea'
  location: location1
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Azure Bastion - Southeast Asia
resource bastion1 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: '${resourcePrefix}-bastion-sea'
  location: location1
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          publicIPAddress: {
            id: bastionPip1.id
          }
          subnet: {
            id: vnet1.properties.subnets[1].id
          }
        }
      }
    ]
  }
}

// Load Balancer Public IP - Southeast Asia
resource lbPip1 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${resourcePrefix}-lb-pip-sea'
  location: location1
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Public Load Balancer - Southeast Asia
resource lb1 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: '${resourcePrefix}-lb-sea'
  location: location1
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          publicIPAddress: {
            id: lbPip1.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendpool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'HTTP-Rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${resourcePrefix}-lb-sea', 'frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${resourcePrefix}-lb-sea', 'backendpool')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${resourcePrefix}-lb-sea', 'http-probe')
          }
          disableOutboundSnat: true
        }
      }
      {
        name: 'HTTPS-Rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${resourcePrefix}-lb-sea', 'frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${resourcePrefix}-lb-sea', 'backendpool')
          }
          protocol: 'Tcp'
          frontendPort: 443
          backendPort: 443
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${resourcePrefix}-lb-sea', 'https-probe')
          }
          disableOutboundSnat: true
        }
      }
    ]
    probes: [
      {
        name: 'http-probe'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
      {
        name: 'https-probe'
        properties: {
          protocol: 'Tcp'
          port: 443
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    outboundRules: [
      {
        name: 'outbound-rule'
        properties: {
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${resourcePrefix}-lb-sea', 'frontend')
            }
          ]
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${resourcePrefix}-lb-sea', 'backendpool')
          }
          protocol: 'All'
          enableTcpReset: true
          idleTimeoutInMinutes: 4
          allocatedOutboundPorts: 10000
        }
      }
    ]
  }
}

resource nsg1 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${resourcePrefix}-nsg-sea'
  location: location1
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Allow-HTTP'
        properties: {
          priority: 1100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'Allow-HTTPS'
        properties: {
          priority: 1200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

resource vmss1 'Microsoft.Compute/virtualMachineScaleSets@2023-09-01' = {
  name: '${resourcePrefix}-vmss-sea'
  location: location1
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: instanceCount
  }
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
        imageReference: imageReference[ubuntuOSVersion]
      }
      osProfile: {
        computerNamePrefix: '${resourcePrefix}sea'
        adminUsername: adminUsername
        adminPassword: adminPassword
        linuxConfiguration: {
          disablePasswordAuthentication: false
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic-config'
            properties: {
              primary: true
              networkSecurityGroup: {
                id: nsg1.id
              }
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    primary: true
                    subnet: {
                      id: vnet1.properties.subnets[0].id
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: lb1.properties.backendAddressPools[0].id
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'InstallNginx'
            properties: {
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              typeHandlerVersion: '2.1'
              autoUpgradeMinorVersion: true
              settings: {
                script: base64(customScript)
              }
            }
          }
        ]
      }
    }
  }
}

// ============================================================================
// EAST ASIA RESOURCES
// ============================================================================

resource vnet2 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${resourcePrefix}-vnet-ea'
  location: location2
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.2.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'vmss-subnet'
        properties: {
          addressPrefix: '10.2.0.0/24'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.2.1.0/26'
        }
      }
    ]
  }
}

// Azure Bastion Public IP - East Asia
resource bastionPip2 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${resourcePrefix}-bastion-pip-ea'
  location: location2
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Azure Bastion - East Asia
resource bastion2 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: '${resourcePrefix}-bastion-ea'
  location: location2
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          publicIPAddress: {
            id: bastionPip2.id
          }
          subnet: {
            id: vnet2.properties.subnets[1].id
          }
        }
      }
    ]
  }
}

// Load Balancer Public IP - East Asia
resource lbPip2 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${resourcePrefix}-lb-pip-ea'
  location: location2
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Public Load Balancer - East Asia
resource lb2 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: '${resourcePrefix}-lb-ea'
  location: location2
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          publicIPAddress: {
            id: lbPip2.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendpool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'HTTP-Rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${resourcePrefix}-lb-ea', 'frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${resourcePrefix}-lb-ea', 'backendpool')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${resourcePrefix}-lb-ea', 'http-probe')
          }
          disableOutboundSnat: true
        }
      }
      {
        name: 'HTTPS-Rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${resourcePrefix}-lb-ea', 'frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${resourcePrefix}-lb-ea', 'backendpool')
          }
          protocol: 'Tcp'
          frontendPort: 443
          backendPort: 443
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${resourcePrefix}-lb-ea', 'https-probe')
          }
          disableOutboundSnat: true
        }
      }
    ]
    probes: [
      {
        name: 'http-probe'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
      {
        name: 'https-probe'
        properties: {
          protocol: 'Tcp'
          port: 443
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    outboundRules: [
      {
        name: 'outbound-rule'
        properties: {
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', '${resourcePrefix}-lb-ea', 'frontend')
            }
          ]
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${resourcePrefix}-lb-ea', 'backendpool')
          }
          protocol: 'All'
          enableTcpReset: true
          idleTimeoutInMinutes: 4
          allocatedOutboundPorts: 10000
        }
      }
    ]
  }
}

resource nsg2 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${resourcePrefix}-nsg-ea'
  location: location2
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Allow-HTTP'
        properties: {
          priority: 1100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'Allow-HTTPS'
        properties: {
          priority: 1200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

resource vmss2 'Microsoft.Compute/virtualMachineScaleSets@2023-09-01' = {
  name: '${resourcePrefix}-vmss-ea'
  location: location2
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: instanceCount
  }
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
        imageReference: imageReference[ubuntuOSVersion]
      }
      osProfile: {
        computerNamePrefix: '${resourcePrefix}ea'
        adminUsername: adminUsername
        adminPassword: adminPassword
        linuxConfiguration: {
          disablePasswordAuthentication: false
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic-config'
            properties: {
              primary: true
              networkSecurityGroup: {
                id: nsg2.id
              }
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    primary: true
                    subnet: {
                      id: vnet2.properties.subnets[0].id
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: lb2.properties.backendAddressPools[0].id
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'InstallNginx'
            properties: {
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              typeHandlerVersion: '2.1'
              autoUpgradeMinorVersion: true
              settings: {
                script: base64(customScript)
              }
            }
          }
        ]
      }
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Name of the Southeast Asia VMSS')
output vmss1Name string = vmss1.name

@description('Name of the East Asia VMSS')
output vmss2Name string = vmss2.name

@description('Southeast Asia Load Balancer Public IP')
output lb1PublicIP string = lbPip1.properties.ipAddress

@description('East Asia Load Balancer Public IP')
output lb2PublicIP string = lbPip2.properties.ipAddress

@description('Southeast Asia Bastion name')
output bastion1Name string = bastion1.name

@description('East Asia Bastion name')
output bastion2Name string = bastion2.name

@description('Southeast Asia VNet ID')
output vnet1Id string = vnet1.id

@description('East Asia VNet ID')
output vnet2Id string = vnet2.id
