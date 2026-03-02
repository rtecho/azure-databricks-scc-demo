// ============================================================================
// Azure Databricks with Secure Cluster Connectivity (No Public IP)
// and VNet Injection
// ============================================================================
// This template deploys an Azure Databricks workspace configured for Secure
// Cluster Connectivity (SCC). With SCC enabled (enableNoPublicIp: true),
// cluster nodes do not receive public IP addresses. Instead, the control plane
// communicates with clusters through a secure relay, eliminating the need for
// inbound NSG rules on ports 22 and 5557. A NAT Gateway provides stable,
// predictable egress IPs for the injected VNet subnets.
// ============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Name of the Azure Databricks workspace.')
param workspaceName string = 'dbw-scc-demo'

@description('Pricing tier for the Databricks workspace. Premium is required for Private Link and SCC features.')
@allowed([
  'premium'
  'standard'
  'trial'
])
param pricingTier string = 'premium'

@description('Enable Secure Cluster Connectivity (No Public IP). When true, cluster nodes have no public IPs and the control plane uses a relay.')
param enableNoPublicIp bool = true

@description('Address prefix for the virtual network.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix for the Databricks host (public) subnet.')
param hostSubnetPrefix string = '10.0.1.0/24'

@description('Address prefix for the Databricks container (private) subnet.')
param containerSubnetPrefix string = '10.0.2.0/24'

@description('Address prefix for the private endpoint subnet.')
param privateEndpointSubnetPrefix string = '10.0.3.0/24'

@description('Prefix used to derive names for all child resources.')
param resourcePrefix string = 'dbwscc'

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var nsgName = '${resourcePrefix}-nsg'
var vnetName = '${resourcePrefix}-vnet'
var natGatewayName = '${resourcePrefix}-natgw'
var natGatewayPublicIpName = '${resourcePrefix}-natgw-pip'
var hostSubnetName = '${resourcePrefix}-host-sn'
var containerSubnetName = '${resourcePrefix}-container-sn'
var privateEndpointSubnetName = '${resourcePrefix}-pe-sn'
var managedResourceGroupName = 'databricks-rg-${workspaceName}-${uniqueString(workspaceName, resourceGroup().id)}'

// ---------------------------------------------------------------------------
// NAT Gateway Public IP
// ---------------------------------------------------------------------------

resource natGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: natGatewayPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// ---------------------------------------------------------------------------
// NAT Gateway
// ---------------------------------------------------------------------------
// A NAT Gateway is recommended for SCC + VNet injection deployments to provide
// stable, predictable egress IP addresses for cluster traffic. Without it,
// egress IPs can be unpredictable, making firewall allowlisting difficult.
// ---------------------------------------------------------------------------

resource natGateway 'Microsoft.Network/natGateways@2023-11-01' = {
  name: natGatewayName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: natGatewayPublicIp.id
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Network Security Group
// ---------------------------------------------------------------------------
// With Secure Cluster Connectivity enabled, there is NO need for inbound rules
// on ports 22 (SSH) or 5557 (worker proxy). The control plane reaches cluster
// nodes through a secure relay instead of direct SSH.
//
// The outbound rules allow traffic to the required Azure service tags that
// Databricks depends on for control plane communication, metastore access,
// artifact/log storage, and structured streaming.
// ---------------------------------------------------------------------------

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      // --- Outbound rules ---
      {
        name: 'AllowOutbound-AzureDatabricks-HTTPS'
        properties: {
          description: 'Required for Databricks control plane communication (REST API, webapp).'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureDatabricks'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowOutbound-AzureDatabricks-MySQL'
        properties: {
          description: 'Required for Databricks metastore communication.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3306'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureDatabricks'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowOutbound-AzureDatabricks-WorkerTunnel'
        properties: {
          description: 'Required for Databricks secure cluster connectivity relay.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8443-8451'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureDatabricks'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowOutbound-SQL'
        properties: {
          description: 'Required for Databricks metastore access via SQL service tag.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3306'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Sql'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowOutbound-Storage-HTTPS'
        properties: {
          description: 'Required for access to Azure Storage (DBFS, artifacts, logs).'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowOutbound-EventHub-Kafka'
        properties: {
          description: 'Required for Databricks log and metrics shipping via Event Hub.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '9093'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'EventHub'
          access: 'Allow'
          priority: 150
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowOutbound-VNet-Internal'
        properties: {
          description: 'Allow all traffic within the VNet for inter-node communication.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 160
          direction: 'Outbound'
        }
      }
      // --- Inbound rules ---
      {
        name: 'AllowInbound-VNet-Internal'
        properties: {
          description: 'Allow all inbound traffic within the VNet for inter-node communication.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Virtual Network
// ---------------------------------------------------------------------------
// The VNet contains three subnets:
//   1. Host subnet      - Databricks driver/host nodes (delegated)
//   2. Container subnet  - Databricks worker containers (delegated)
//   3. Private endpoint  - For optional Private Link endpoints
//
// Both Databricks subnets are delegated to Microsoft.Databricks/workspaces,
// which grants the Databricks resource provider permission to manage NICs and
// other resources within those subnets.
// ---------------------------------------------------------------------------

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: hostSubnetName
        properties: {
          addressPrefix: hostSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          natGateway: {
            id: natGateway.id
          }
          delegations: [
            {
              name: 'databricks-host-delegation'
              properties: {
                serviceName: 'Microsoft.Databricks/workspaces'
              }
            }
          ]
          serviceEndpoints: [
            { service: 'Microsoft.Storage' }
            { service: 'Microsoft.Sql' }
            { service: 'Microsoft.EventHub' }
            { service: 'Microsoft.KeyVault' }
          ]
        }
      }
      {
        name: containerSubnetName
        properties: {
          addressPrefix: containerSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          natGateway: {
            id: natGateway.id
          }
          delegations: [
            {
              name: 'databricks-container-delegation'
              properties: {
                serviceName: 'Microsoft.Databricks/workspaces'
              }
            }
          ]
          serviceEndpoints: [
            { service: 'Microsoft.Storage' }
            { service: 'Microsoft.Sql' }
            { service: 'Microsoft.EventHub' }
            { service: 'Microsoft.KeyVault' }
          ]
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Azure Databricks Workspace
// ---------------------------------------------------------------------------
// Key SCC configuration:
//   - enableNoPublicIp: true  -- Cluster nodes get NO public IPs. The control
//     plane communicates through a secure relay (SCC).
//   - customVirtualNetworkId  -- Injects the workspace into our custom VNet.
//   - customPublicSubnetName / customPrivateSubnetName -- Maps to the host and
//     container subnets respectively.
//   - publicNetworkAccess: 'Enabled' -- Users can reach the workspace UI over
//     the internet. Set to 'Disabled' for full Private Link lockdown.
//   - requiredNsgRules: 'AllRules' -- Azure Databricks manages NSG rules. Use
//     'NoAzureDatabricksRules' when using your own NSG rules exclusively.
// ---------------------------------------------------------------------------

resource databricksWorkspace 'Microsoft.Databricks/workspaces@2024-05-01' = {
  name: workspaceName
  location: location
  sku: {
    name: pricingTier
  }
  properties: {
    managedResourceGroupId: subscriptionResourceId('Microsoft.Resources/resourceGroups', managedResourceGroupName)
    publicNetworkAccess: 'Enabled'
    requiredNsgRules: 'AllRules'
    parameters: {
      enableNoPublicIp: {
        value: enableNoPublicIp
      }
      customVirtualNetworkId: {
        value: vnet.id
      }
      customPublicSubnetName: {
        value: hostSubnetName
      }
      customPrivateSubnetName: {
        value: containerSubnetName
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('The URL of the Databricks workspace (e.g., https://adb-<id>.azuredatabricks.net).')
output workspaceUrl string = databricksWorkspace.properties.workspaceUrl

@description('The resource ID of the Databricks workspace.')
output workspaceId string = databricksWorkspace.id

@description('The resource ID of the virtual network.')
output vnetId string = vnet.id

@description('The public IP address assigned to the NAT Gateway for stable egress.')
output natGatewayPublicIp string = natGatewayPublicIp.properties.ipAddress
