#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

set -euo pipefail

main() {
  local rg_name="${1:-denyActionDemo01}"
  local expected_outcome="${2:-blocked}"

  if ! command -v az >/dev/null 2>&1; then
    echo "ERROR: Azure CLI (az) is required." >&2
    exit 1
  fi

  local delete_output
  local delete_exit_code
  local group_show_output
  local group_show_exit_code

  set +e
  delete_output="$(az group delete --name "$rg_name" --yes 2>&1)"
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
  group_show_output="$(az group show --name "$rg_name" -o json 2>&1)"
  group_show_exit_code=$?
  set -e

  echo "Resource group query exit code: $group_show_exit_code"
  if [[ -n "$group_show_output" ]]; then
    echo "Resource group query result:"
    echo "$group_show_output"
  else
    echo "Resource group query result: <none>"
  fi

  if [[ "$expected_outcome" == "blocked" ]]; then
    local exists_after_blocked_test
    exists_after_blocked_test="$(az group exists --name "$rg_name")"
    echo "Resource group exists after blocked test: $exists_after_blocked_test"

    if [[ $delete_exit_code -ne 0 && $group_show_exit_code -eq 0 && "$exists_after_blocked_test" == "true" ]]; then
      printf '\033[1;32m%s\033[0m\n' "Delete attempt was blocked as expected; resource group still exists."
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

    az group wait --name "$rg_name" --deleted

    local exists_after_deleted_test
    exists_after_deleted_test="$(az group exists --name "$rg_name")"
    echo "Resource group exists after deleted test: $exists_after_deleted_test"

    if [[ $group_show_exit_code -ne 0 && "$exists_after_deleted_test" == "false" ]]; then
      printf '\033[1;32m%s\033[0m\n' "Delete attempt succeeded as expected; resource group has been removed."
      exit 0
    fi

    echo "Delete attempt was accepted, but the resource group still exists."
    exit 1
  fi

  echo "ERROR: expected_outcome must be 'blocked' or 'deleted'." >&2
  exit 1
}

main "$@"