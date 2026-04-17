#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

set -euo pipefail

main() {
  local rg_name="${1:-denyActionDemo01}"
  local storage_account_name="${2:-}"
  local expected_outcome="${3:-blocked}"

  if ! command -v az >/dev/null 2>&1; then
    echo "ERROR: Azure CLI (az) is required." >&2
    exit 1
  fi

  if [[ -z "$storage_account_name" ]]; then
    storage_account_name="$(az storage account list --resource-group "$rg_name" --query '[0].name' -o tsv)"
  fi

  if [[ -z "$storage_account_name" ]]; then
    echo "ERROR: No storage account found in resource group '$rg_name'." >&2
    exit 1
  fi

  local delete_output
  local delete_exit_code
  local show_output
  local show_exit_code

  set +e
  delete_output="$(az storage account delete --name "$storage_account_name" --resource-group "$rg_name" --yes 2>&1)"
  delete_exit_code=$?
  set -e

  echo "Delete command exit code: $delete_exit_code"
  if [[ -n "$delete_output" ]]; then
    echo "Delete command output:"
    echo "$delete_output"
  else
    echo "Delete command output: <none>"
  fi

  set +e
  show_output="$(az storage account show --name "$storage_account_name" --resource-group "$rg_name" -o json 2>&1)"
  show_exit_code=$?
  set -e

  echo "Storage account query exit code: $show_exit_code"
  if [[ -n "$show_output" ]]; then
    echo "Storage account query result:"
    echo "$show_output"
  else
    echo "Storage account query result: <none>"
  fi

  if [[ "$expected_outcome" == "blocked" ]]; then
    if [[ $delete_exit_code -ne 0 && $show_exit_code -eq 0 ]]; then
      echo "Delete attempt was blocked as expected; storage account still exists."
      exit 0
    fi

    echo "Delete attempt was expected to be blocked, but the result did not match."
    exit 1
  fi

  if [[ "$expected_outcome" == "deleted" ]]; then
    if [[ $delete_exit_code -ne 0 ]]; then
      echo "Delete attempt was expected to succeed, but Azure CLI returned an error."
      exit 1
    fi

    if [[ $show_exit_code -ne 0 ]]; then
      echo "Delete attempt succeeded as expected; storage account has been removed."
      exit 0
    fi

    echo "Delete attempt was accepted, but the storage account still exists."
    exit 1
  fi

  echo "ERROR: expected_outcome must be 'blocked' or 'deleted'." >&2
  exit 1
}

main "$@"
