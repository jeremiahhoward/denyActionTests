#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

set -euo pipefail

main() {
  local rg_name="${1:-denyActionDemo01}"
  local stack_name="${2:-${rg_name}-rg-stack}"
  local prior_success_stack_name="${3:-${rg_name}-sub-stack}"
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

  echo "========== STAGE 4: RG-SCOPED DENY COMPARISON =========="
  echo "Removing the subscription-scoped stack so only RG-scoped deny behavior remains..."
  if az stack sub show --name "$prior_success_stack_name" >/dev/null 2>&1; then
    az stack sub delete \
      --name "$prior_success_stack_name" \
      --action-on-unmanage 'detachAll' \
      --yes \
      >/dev/null
  else
    echo "Stage 2 subscription-scoped stack not found; continuing."
  fi

  echo "Updating RG-scoped deployment stack with denyDelete..."
  az stack group create \
    --name "$stack_name" \
    --resource-group "$rg_name" \
    --template-file "$script_dir/stage1.bicep" \
    --action-on-unmanage 'detachAll' \
    --deny-settings-mode 'denyDelete' --yes \
    >/dev/null

  local conf
  conf="$(az stack group show --resource-group "$rg_name" --name "$stack_name")"

  local provisioning_state
  provisioning_state="$(echo "$conf" | jq -r '(.properties.provisioningState // .provisioningState // "unknown")')"

  local conf_test
  conf_test="$(echo "$provisioning_state" | tr '[:upper:]' '[:lower:]')"

  if [[ "$conf_test" == "succeeded" ]]; then
    echo "RG-scoped denyDelete applied successfully."
  else
    echo "Failed to apply RG-scoped denyDelete. provisioningState=$provisioning_state"
    exit 1
  fi

  echo "$conf" | jq '{name, provisioningState, denySettings: .denySettings, resources: .resources}'
  echo
  echo "This setup is intentionally ineffective for protecting the resource group itself."
  echo "Per Azure deployment stacks known issues, deleting the RG can bypass RG-scoped deny assignments."
  echo
  echo "========== EXPECTED RESULT: RESOURCE GROUP DELETE SHOULD SUCCEED =========="
  echo "Attempting RG deletion; the group scoped denyDelete setting should not prevent the deletion of the resource group."
  bash "$script_dir/attemptResourceGroupDelete.sh" "$rg_name" deleted
  echo
  echo "========== DEMO COMPLETE =========="
  echo "Stage 2 blocked storage account deletion, stage 3 validated sub-stack cascade behavior, and stage 4 showed RG-scoped comparison cleanup."
}

main "$@"
