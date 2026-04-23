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

  printf '\033[1;33m%s\033[0m\n' "========== STAGE 4: CASCADE TEST ON EXISTING SUB BASED STACK =========="
  echo "Creating subscription-scoped stack '$stack_name' for stage 4 cascade test."

  local rg_location
  rg_location="$(az group show --name "$rg_name" --query location -o tsv)"

  az stack sub create \
    --name "$stack_name" \
    --location "$rg_location" \
    --deployment-resource-group "$rg_name" \
    --template-file "$script_dir/stage1.bicep" \
    --action-on-unmanage 'detachAll' \
    --deny-settings-mode 'denyDelete' \
    --yes \
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

  echo
  printf '\033[1;33m%s\033[0m\n' "========== EXPECTED RESULT: RESOURCE GROUP DELETE SHOULD SUCCEED =========="
  echo "Attempting RG deletion; the subscription scoped denyDelete setting should not prevent the deletion of the resource group."

  bash "$script_dir/attemptResourceGroupDelete.sh" "$rg_name" deleted


  printf '\033[1;32m%s\033[0m\n' "========== DEMO COMPLETE =========="
  echo "Stage 4 confirmed RG delete outcome with the existing subscription-scoped stack."
}

main "$@"
