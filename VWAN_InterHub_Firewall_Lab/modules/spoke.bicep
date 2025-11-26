// =============================================================================
// Spoke VNet and VM Module
// =============================================================================
// Creates spoke VNet, VM, and connects to Virtual Hub

targetScope = 'resourceGroup'

// =============================================================================
// PARAMETERS
// =============================================================================

@description('Spoke configuration object') 
param spokeConfig object

@description('VM configuration object')
param vmConfig object

@description('Admin password for VM')
@secure()
param adminPassword string

@description('Virtual Hub resource ID for connection')
param hubId string

@description('Resource tags')
param tags object = {}

// =============================================================================
// NETWORK SECURITY GROUP
// =============================================================================

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${spokeConfig.name}-nsg'
  location: spokeConfig.location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowSSH-AzurePlatform'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '168.63.129.16'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'Allow SSH from Azure platform for Bastion native client'
        }
      }
      {
        name: 'AllowRDP-AzurePlatform'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '168.63.129.16'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          description: 'Allow RDP from Azure platform for Bastion native client'
        }
      }
      {
        name: 'AllowICMP-VNet'
        properties: {
          priority: 200
          protocol: 'Icmp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Allow ICMP from VNet for internal connectivity testing'
        }
      }
    ]
  }
}

// =============================================================================
// VIRTUAL NETWORK
// =============================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: spokeConfig.name
  location: spokeConfig.location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeConfig.addressPrefix
      ]
    }
    subnets: [
      {
        name: spokeConfig.subnets.vm.name
        properties: {
          addressPrefix: spokeConfig.subnets.vm.addressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// =============================================================================
// PUBLIC IP FOR VM
// =============================================================================

resource vmPublicIP 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${spokeConfig.name}-vm-pip'
  location: spokeConfig.location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${spokeConfig.name}-vm-${uniqueString(resourceGroup().id)}')
    }
  }
}

// =============================================================================
// NETWORK INTERFACE
// =============================================================================

resource vmNetworkInterface 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${spokeConfig.name}-vm-nic'
  location: spokeConfig.location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
          publicIPAddress: {
            id: vmPublicIP.id
          }
        }
      }
    ]
    enableIPForwarding: false
  }
}

// =============================================================================
// VIRTUAL MACHINE
// =============================================================================

resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: '${spokeConfig.name}-vm'
  location: spokeConfig.location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmConfig.vmSize
    }
    osProfile: {
      computerName: '${spokeConfig.name}-vm'
      adminUsername: vmConfig.adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'ImageDefault'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: vmConfig.imageReference
      osDisk: {
        name: '${spokeConfig.name}-vm-osdisk'
        caching: 'ReadWrite'
        createOption: vmConfig.osDisk.createOption
        managedDisk: {
          storageAccountType: vmConfig.osDisk.storageAccountType
        }
        diskSizeGB: vmConfig.osDisk.diskSizeGB
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNetworkInterface.id
        }
      ]
    }
  }
}

// =============================================================================
// VM EXTENSION FOR TESTING TOOLS
// =============================================================================

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: virtualMachine
  name: 'InstallTestingTools'
  location: spokeConfig.location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      script: base64('''#!/bin/bash
# Update package list
apt-get update

# Install network tools
apt-get install -y curl wget telnet netcat-openbsd tcpdump traceroute mtr-tiny nmap

# Install htop for monitoring
apt-get install -y htop

# Enable IP forwarding (for testing purposes)
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Create test script
cat > /home/${vmConfig.adminUsername}/test-connectivity.sh << 'EOF'
#!/bin/bash
echo "=== Network Connectivity Test Script ==="
echo "VM Hostname: $(hostname)"
echo "VM IP Address: $(hostname -I)"
echo "Date: $(date)"
echo ""

if [ $# -eq 0 ]; then
    echo "Usage: $0 <target_ip>"
    echo "Example: $0 10.20.1.4"
    exit 1
fi

TARGET=$1
echo "Testing connectivity to: $TARGET"
echo ""

echo "1. Ping test (ICMP):"
ping -c 4 $TARGET
echo ""

echo "2. TCP connectivity test (SSH port 22):"
nc -zv $TARGET 22
echo ""

echo "3. Traceroute:"
traceroute $TARGET
echo ""

echo "4. MTR (My TraceRoute):"
mtr -r -c 4 $TARGET
echo ""

echo "Test completed."
EOF

chmod +x /home/${vmConfig.adminUsername}/test-connectivity.sh
chown ${vmConfig.adminUsername}:${vmConfig.adminUsername} /home/${vmConfig.adminUsername}/test-connectivity.sh

# Create firewall monitoring script
cat > /home/${vmConfig.adminUsername}/monitor-traffic.sh << 'EOF'
#!/bin/bash
echo "=== Network Traffic Monitor ==="
echo "Press Ctrl+C to stop monitoring"
echo ""

# Monitor all network interfaces
tcpdump -i any -n -v
EOF

chmod +x /home/${vmConfig.adminUsername}/monitor-traffic.sh
chown ${vmConfig.adminUsername}:${vmConfig.adminUsername} /home/${vmConfig.adminUsername}/monitor-traffic.sh

echo "Setup completed successfully" > /var/log/vm-setup.log
''')
    }
  }
}

// =============================================================================
// VIRTUAL HUB CONNECTION
// =============================================================================

resource hubConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-09-01' = {
  name: '${split(hubId, '/')[8]}/connection-${spokeConfig.name}'
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

@description('Virtual Network resource ID')
output vnetId string = virtualNetwork.id

@description('Virtual Network name')
output vnetName string = virtualNetwork.name

@description('VM resource ID')
output vmId string = virtualMachine.id

@description('VM name')
output vmName string = virtualMachine.name

@description('VM public IP address')
output vmPublicIP string = vmPublicIP.properties.ipAddress

@description('VM private IP address')
output vmPrivateIP string = vmNetworkInterface.properties.ipConfigurations[0].properties.privateIPAddress

@description('VM network interface ID')
output vmNicId string = vmNetworkInterface.id

@description('Hub connection ID')
output hubConnectionId string = hubConnection.id

@description('Network Security Group ID')
output nsgId string = nsg.id
