param vnetname string = 'vnethdi'

resource storage 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: 'storhdi${uniqueString(resourceGroup().id)}'
  location: resourceGroup().location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: vnetname
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = {
  name: '${vnet.name}/subnethdi'
  properties: {
    addressPrefix: '10.0.0.0/24'
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: 'hdinsight_security_group'
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'Required_HDInsight_Host_IPs_Port_443'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefixes: [
            '168.61.49.99'
            '23.99.5.239'
            '168.61.48.131'
            '138.91.141.162'
          ]
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Required_HDInsight_Host_IPs_Port_53'
        properties: {
          priority: 400
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: '168.63.129.16'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Required_HDInsight_ServiceTag'
        properties: {
          priority: 500
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'HDInsight'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowVnetOutBound'
        properties: {
          priority: 500
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'AllowedOutBoundPorts'
        properties: {
          priority: 400
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '1-21'
            '23-2221'
            '2223-65535'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllOutBound'
        properties: {
          priority: 1000
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}
resource cluster 'Microsoft.HDInsight/clusters@2018-06-01-preview' = {
  name: 'hdicluster${uniqueString(resourceGroup().id)}'
  location: resourceGroup().location
  properties: {
    clusterVersion: '3.6'
    osType: 'Linux'
    tier: 'Standard'
    clusterDefinition: {
      kind: 'hadoop'
      configurations: {
        gateway: {
          'restAuthCredential.isEnabled': true
          'restAuthCredential.username': 'acctestusrgw'
          'restAuthCredential.password': 'TerrAform123!'
        }
      }
    }
    storageProfile: {
      storageaccounts: [
        {
          name: replace(replace(storage.properties.primaryEndpoints.blob, 'https://', ''), '/', '')
          isDefault: true
          container: 'hdi'
          key: listKeys(storage.id, '2019-06-01').keys[0].value
        }
      ]
    }
    computeProfile: {
      roles: [
        {
          name: 'headnode'
          targetInstanceCount: 2
          hardwareProfile: {
            vmSize: 'Standard_E2_V3'
          }
          osProfile: {
            linuxOperatingSystemProfile: {
              username: 'acctestusrvm'
              password: 'AccTestvdSC4daf986'
            }
          }
          virtualNetworkProfile: {
            id: vnet.id
            subnet: subnet.id
          }
        }
        {
          name: 'workernode'
          targetInstanceCount: 1
          hardwareProfile: {
            vmSize: 'Standard_E2_V3'
          }
          osProfile: {
            linuxOperatingSystemProfile: {
              username: 'acctestusrvm'
              password: 'AccTestvdSC4daf986'
            }
          }
          virtualNetworkProfile: {
            id: vnet.id
            subnet: subnet.id
          }
        }
      ]
    }
  }
}
