#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

set -euo pipefail

main() {
  local rg_name="${1:-denyActionDemo01}"
  local skip_continue_prompt="${2:-false}"
  local stack_scope="${3:-group}"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ "$stack_scope" != "group" && "$stack_scope" != "sub" ]]; then
    echo "ERROR: stack_scope must be 'group' or 'sub' (got: '$stack_scope')." >&2
    exit 1
  fi

  if ! command -v az >/dev/null 2>&1; then
    echo "ERROR: Azure CLI (az) is required." >&2
    exit 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required." >&2
    exit 1
  fi

  printf '\033[1;33m%s\033[0m\n' "========== DEPLOYING DEMO TEST RESOURCES (stack scope: $stack_scope) =========="
  local rg_exists
  rg_exists="$(az group exists --name "$rg_name")"

  if az group create --name "$rg_name" --location 'centralus' >/dev/null; then
    if [[ "$rg_exists" == "true" ]]; then
      echo "az group create: alreadyExists"
    else
      echo "az group create: success"
    fi
  else
    echo "az group create: failure" >&2
    exit 1
  fi

  local stack_exists="false"
  local conf
  local provisioning_state
  local conf_test

  if [[ "$stack_scope" == "sub" ]]; then
    skip_continue_prompt="true"
    local rg_location
    rg_location="$(az group show --name "$rg_name" --query location -o tsv)"

    if az stack sub show --name "$rg_name" >/dev/null 2>&1; then
      stack_exists="true"
    fi

    if az stack sub create \
      --name "$rg_name" \
      --location "$rg_location" \
      --deployment-resource-group "$rg_name" \
      --template-file "$script_dir/stage1.bicep" \
      --action-on-unmanage 'detachAll' \
      --deny-settings-mode 'none' \
      --yes \
      >/dev/null; then
      if [[ "$stack_exists" == "true" ]]; then
        echo "az stack sub create: alreadyExists"
      else
        echo "az stack sub create: success"
      fi
    else
      echo "az stack sub create: failure" >&2
      exit 1
    fi

    conf="$(az stack sub show --name "$rg_name")"
  else
    if az stack group show --resource-group "$rg_name" --name "$rg_name" >/dev/null 2>&1; then
      stack_exists="true"
    fi

    if az stack group create \
      --name "$rg_name" \
      --resource-group "$rg_name" \
      --template-file "$script_dir/stage1.bicep" \
      --action-on-unmanage 'detachAll' \
      --deny-settings-mode 'none' \
      >/dev/null; then
      if [[ "$stack_exists" == "true" ]]; then
        echo "az stack group create: alreadyExists"
      else
        echo "az stack group create: success"
      fi
    else
      echo "az stack group create: failure" >&2
      exit 1
    fi

    conf="$(az stack group show --resource-group "$rg_name" --name "$rg_name")"
  fi

  provisioning_state="$(echo "$conf" | jq -r '(.properties.provisioningState // .provisioningState // "unknown")')"
  conf_test="$(echo "$provisioning_state" | tr '[:upper:]' '[:lower:]')"

  if [[ "$conf_test" == "succeeded" ]]; then
    printf '\033[1;32m%s\033[0m\n'  "Deployment successful."
  else
    echo "Deployment failed. provisioningState=$provisioning_state"
    exit 1
  fi

  if [[ "$skip_continue_prompt" == "true" ]]; then
    return
  fi

  local continue_response
  read -r -p "Continue to stage 2 (resource level block demo)? [y/N] " continue_response
  if [[ "$continue_response" =~ ^[Yy]$ ]]; then
    bash "$script_dir/2-demonstrateResourceLevelBlock.sh" "$rg_name"
  fi
}

main "$@"

