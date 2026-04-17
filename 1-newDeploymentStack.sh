
RGNAME='denyActionDemo01'
az group create --name "$RGNAME" --location 'centralus'

az stack group create --name "$RGNAME" --resource-group "$RGNAME" --template-file './stage1.bicep' --action-on-unmanage 'detachAll' --deny-settings-mode 'none'

CONF=$(az stack group show  --resource-group "$RGNAME"    --name "$RGNAME")
CONF_TEST=$(echo "$CONF" | jq -r '(.error == null) and (.provisioningState == "Succeeded")')

if [[ "$CONF_TEST" == "true" ]]; then
  echo "Initial Deployment successful"
else
  echo "Initial Deployment failed"
  exit 1
fi

