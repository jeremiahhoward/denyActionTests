#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

set -euo pipefail

main() {
  local rg_name="${1:-denyActionDemo01}"
  local skip_continue_prompt="${2:-false}"
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

  echo "========== DEPLOYING DEMO TEST RESOURCES =========="
  az group create --name "$rg_name" --location 'centralus'

  az stack group create \
    --name "$rg_name" \
    --resource-group "$rg_name" \
    --template-file "$script_dir/stage1.bicep" \
    --action-on-unmanage 'detachAll' \
    --deny-settings-mode 'none'

  local conf
  conf="$(az stack group show --resource-group "$rg_name" --name "$rg_name")"

  local provisioning_state
  provisioning_state="$(echo "$conf" | jq -r '(.properties.provisioningState // .provisioningState // "unknown")')"

  local conf_test
  conf_test="$(echo "$provisioning_state" | tr '[:upper:]' '[:lower:]')"

  if [[ "$conf_test" == "succeeded" ]]; then
    echo "Initial deployment successful."
  else
    echo "Initial deployment failed. provisioningState=$provisioning_state"
    exit 1
  fi

  if [[ "$skip_continue_prompt" == "true" ]]; then
    return
  fi

  local continue_response
  read -r -p "Continue to stage 2 (subscription deny demo)? [y/N] " continue_response
  if [[ "$continue_response" =~ ^[Yy]$ ]]; then
    bash "$script_dir/2-applySubDenyAction.sh" "$rg_name"
  fi
}

main "$@"

