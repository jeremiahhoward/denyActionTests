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

  echo "========== STAGE 2: EFFECTIVE DENY VIA SUBSCRIPTION STACK =========="
  echo "Creating subscription-scoped deployment stack with denyDelete..."
  az stack sub create \
    --name "$stack_name" \
    --location "$rg_location" \
    --deployment-resource-group "$rg_name" \
    --template-file "$script_dir/stage1.bicep" \
    --action-on-unmanage 'detachAll' \
    --deny-settings-mode 'denyDelete' --yes  \
    >/dev/null

  local conf
  conf="$(az stack sub show --name "$stack_name")"

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

  echo "$conf" | jq '{name, provisioningState, denySettings: .denySettings, resources: .resources}'
  echo
  echo "========== EXPECTED RESULT: STORAGE ACCOUNT DELETE SHOULD BE BLOCKED =========="
  echo "Attempting storage account deletion for '$storage_account_name'; this stage should block the delete."
  bash "$script_dir/attemptStorageAccountDelete.sh" "$rg_name" "$storage_account_name" blocked

  local continue_response
  read -r -p "Continue to stage 3 (resource group delete test on existing sub stack)? [y/N] " continue_response
  if [[ "$continue_response" =~ ^[Yy]$ ]]; then
    bash "$script_dir/4-applyCascadeIneffective.sh" "$rg_name" "$stack_name"
  fi
}

main "$@"

