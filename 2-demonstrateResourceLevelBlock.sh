#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

set -euo pipefail

main() {
  local rg_name="${1:-denyActionDemo01}"
  local stack_name="${2:-${rg_name}-sub-stack}"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if ! command -v az >/dev/null 2>&1; then
    echo "ERROR: Azure CLI (az) is required." >&2
    exit 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required." >&2
    exit 1
  fi

  local rg_location
  rg_location="$(az group show --name "$rg_name" --query location -o tsv)"

  local storage_account_name
  storage_account_name="$(az storage account list --resource-group "$rg_name" --query '[0].name' -o tsv)"

  if [[ -z "$storage_account_name" ]]; then
    echo "ERROR: No storage account found in '$rg_name' to test deny behavior." >&2
    exit 1
  fi

  printf '\033[1;33m%s\033[0m\n' "========== STAGE 2: EFFECTIVE DENY VIA GROUP STACK =========="
  echo "Updating group-scoped deployment stack with denyDelete..."
  az stack group create \
    --name "$stack_name" \
    --resource-group "$rg_name" \
    --template-file "$script_dir/stage1.bicep" \
    --action-on-unmanage 'detachAll' \
    --deny-settings-mode 'denyDelete' --yes  \
    >/dev/null

  local conf
  conf="$(az stack group show --resource-group "$rg_name" --name "$stack_name")"

  local provisioning_state
  provisioning_state="$(echo "$conf" | jq -r '(.properties.provisioningState // .provisioningState // "unknown")')"

  local conf_test
  conf_test="$(echo "$provisioning_state" | tr '[:upper:]' '[:lower:]')"

  if [[ "$conf_test" == "succeeded" ]]; then
    echo "Subscription-scoped denyDelete applied successfully."
  else
    echo "Failed to apply subscription-scoped denyDelete. provisioningState=$provisioning_state"
    exit 1
  fi

  echo
  printf '\033[1;33m%s\033[0m\n' "========== EXPECTED RESULT: STORAGE ACCOUNT DELETE SHOULD BE BLOCKED =========="
  echo "Attempting storage account deletion for '$storage_account_name'; this stage should block the delete."
  bash "$script_dir/attemptStorageAccountDelete.sh" "$rg_name" "$storage_account_name" blocked

  echo
  printf '\033[1;33m%s\033[0m\n' "========== RESOURCE LOCK TEST: RG DELETE WITH VNET LOCK =========="
  local vnet_name
  vnet_name="$(az network vnet list --resource-group "$rg_name" --query '[0].name' -o tsv)"

  if [[ -z "$vnet_name" ]]; then
    echo "ERROR: No VNet found in '$rg_name'; skipping lock test." >&2
  else
    local vnet_id
    vnet_id="$(az network vnet show --resource-group "$rg_name" --name "$vnet_name" --query id -o tsv)"

    echo "Adding CanNotDelete lock to VNet '$vnet_name'..."
    az lock create \
      --name "vnet-lock" \
      --resource "$vnet_id" \
      --lock-type 'CanNotDelete' \
      >/dev/null
    echo "az lock create: success"

    echo
    echo "========== EXPECTED RESULT: RESOURCE GROUP DELETE SHOULD BE BLOCKED =========="
    echo "Attempting RG deletion; the VNet resource lock should prevent the deletion of the resource group."
    bash "$script_dir/attemptResourceGroupDelete.sh" "$rg_name" blocked

    echo
    echo "Removing VNet lock before continuing..."
    az lock delete \
      --name "vnet-lock" \
      --resource "$vnet_id" \
      >/dev/null
    echo "az lock delete: success"
  fi

  local continue_response
  read -r -p "Continue to stage 3 (resource group delete test on existing sub stack)? [y/N] " continue_response
  if [[ "$continue_response" =~ ^[Yy]$ ]]; then
    bash "$script_dir/3-applyGroupDenyAction.sh" "$rg_name" "$stack_name"
  fi
}

main "$@"

