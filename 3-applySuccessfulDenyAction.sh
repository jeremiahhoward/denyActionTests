#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

set -euo pipefail

main() {
	local rg_name="${1:-denyActionDemo01}"
	local policy_def_name="deny-rg-delete-at-rg-scope"
	local policy_assignment_name="deny-rg-delete-assignment"

	if ! command -v az >/dev/null 2>&1; then
		echo "ERROR: Azure CLI (az) is required." >&2
		exit 1
	fi

	local subscription_id
	subscription_id="$(az account show --query id -o tsv)"

	local rg_id
	rg_id="$(az group show --name "$rg_name" --query id -o tsv)"

	local temp_rule_file
	temp_rule_file="$(mktemp)"

	cat > "$temp_rule_file" <<'EOF'
{
	"if": {
		"field": "type",
		"like": "*"
	},
	"then": {
		"effect": "denyAction",
		"details": {
			"actionNames": [
				"delete"
			],
			"cascadeBehaviors": {
				"resourceGroup": "deny"
			}
		}
	}
}
EOF

	echo "Creating or updating policy definition: $policy_def_name"
	az policy definition create \
		--name "$policy_def_name" \
		--display-name "Deny delete of Resource Group at RG scope" \
		--description "Blocks RG delete at RG scope through denyAction cascade behavior." \
		--mode Indexed \
		--rules "$temp_rule_file" \
		--subscription "$subscription_id" \
		>/dev/null

	rm -f "$temp_rule_file"

	local policy_definition_id
	policy_definition_id="/subscriptions/$subscription_id/providers/Microsoft.Authorization/policyDefinitions/$policy_def_name"

	echo "Creating policy assignment '$policy_assignment_name' at scope: $rg_id"
	az policy assignment create \
		--name "$policy_assignment_name" \
		--display-name "Deny Resource Group Delete" \
		--policy "$policy_definition_id" \
		--scope "$rg_id" \
		>/dev/null

	echo "Verifying assignment..."
	az policy assignment show \
		--name "$policy_assignment_name" \
		--scope "$rg_id" \
		--query '{name:name,scope:scope,enforcementMode:enforcementMode,policyDefinitionId:policyDefinitionId}' \
		-o json

	echo
	echo "Policy assigned successfully."
	echo "Note: denyAction blocks RG deletion when applicable indexed resources are present in the group."
	echo "For absolute delete protection (including empty RGs), use a CanNotDelete management lock as well."
}

main "$@"

