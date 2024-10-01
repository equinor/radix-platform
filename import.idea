#!/usr/bin/env bash
ALL_PVS=$(az network private-endpoint list --resource-group cluster-vnet-hub-prod | jq -r '.[].name')
# for SINGLE_PV in $ALL_PVS; do
#   PROPERTY=$(az network private-endpoint show --name "$SINGLE_PV" --resource-group cluster-vnet-hub-prod)
#   groupIds=$(jq -n "$PROPERTY" | jq -r .manualPrivateLinkServiceConnections[].groupIds[])
#   privateLinkServiceId=$(jq -n "$PROPERTY" | jq -r .manualPrivateLinkServiceConnections[].privateLinkServiceId)
#   manualPrivateLinkServiceConnectionsname=$(jq -n "$PROPERTY" | jq -r .manualPrivateLinkServiceConnections[].name)
#   echo "${SINGLE_PV/pe-/}:"
#   echo "  subresourcename : \"$groupIds\""
#   echo "  resource_id : \"$privateLinkServiceId\""
# done

# for TERRAFORM in $ALL_PVS; do
#   PROPERTY=$(az network private-endpoint show --name "$TERRAFORM" --resource-group cluster-vnet-hub-prod)
#   manualPrivateLinkServiceConnections=$(jq -n "$PROPERTY" | jq -r .id)
#   echo "terraform import module.private_endpoints[\\\"${TERRAFORM/pe-/}\\\"].azurerm_private_endpoint.this $manualPrivateLinkServiceConnections"
# done

for DNSTERRAFORM in $ALL_PVS; do
  PROPERTY=$(az network private-endpoint show --name "$DNSTERRAFORM" --resource-group cluster-vnet-hub-prod)
    privateLinkServiceId=$(jq -n "$PROPERTY" | jq -r .manualPrivateLinkServiceConnections[].privateLinkServiceId)
    groupIds=$(jq -n "$PROPERTY" | jq -r .manualPrivateLinkServiceConnections[].groupIds[])
    dns_name="${privateLinkServiceId##*/}"
  echo "terraform import module.private_endpoints[\\\"${DNSTERRAFORM/pe-/}\\\"].azurerm_private_dns_a_record.this /subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/cluster-vnet-hub-prod/providers/Microsoft.Network/privateDnsZones/privatelink.$groupIds/A/$dns_name"
done
