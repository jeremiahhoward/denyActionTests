---
title: Deployment Stack Demo Functionality Wiki
description: Explains what the deployment stack demo does, what it proves, and why resource group scoped deny settings behave differently from parent scoped deny settings.
author: Microsoft
ms.date: 2026-04-17
ms.topic: concept
keywords:
  - Azure deployment stacks
  - deny settings
  - resource group deletion
  - storage account deletion
  - Bicep
estimated_reading_time: 6
---

## Overview

This demo shows how Azure deployment stack deny settings behave differently depending on where the stack exists.

The repository uses one Bicep template, [stage1.bicep](./stage1.bicep), and several shell scripts to create and test deployment stacks at different scopes.

The key point is simple: parent-scoped protection can block managed resource deletion, but resource-group-scoped protection does not reliably block deletion of the resource group itself.

## The Microsoft Learn behavior this demo proves

> [!IMPORTANT]
> Microsoft Learn explicitly documents the behavior this demo is designed to reproduce:
>
> "Deleting resource groups currently bypasses deny-assignments. When you create a deployment stack in the resource group scope, the Bicep file doesn't contain the definition for the resource group. Despite the deny-assignment setting, you can delete the resource group and its contained stack. However, if a lock is active on any resource within the group, the delete operation fails."
>
> Source: [Protect managed resources](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks?tabs=azure-powershell#protect-managed-resources)

This quote is the center of the demo.

## Process

The demo creates a resource group, deploys a storage account and virtual network, applies deployment stack deny settings, and then attempts deletion operations to observe the result.

The scripts currently work as a staged walkthrough.

* [1-newDeploymentStack.sh](./1-newDeploymentStack.sh) creates the initial resource group and deploys [stage1.bicep](./stage1.bicep) with no deny settings.
* [2-demonstrateResourceLevelBlock.sh](./2-demonstrateResourceLevelBlock.sh) creates a subscription-scoped deployment stack with `denyDelete` and attempts to delete the managed storage account.
* [3-applyGroupDenyAction.sh](./3-applyGroupDenyAction.sh) removes the subscription-scoped stack, creates a resource-group-scoped deployment stack with `denyDelete`, and then attempts to * [4-applySubDeny.sh](./4-applySubDeny.sh) uses the existing subscription-scoped stack from stage 2 and attempts to delete the resource group.
delete the resource group.
* [attemptStorageAccountDelete.sh](./attemptStorageAccountDelete.sh) performs the storage account delete test and prints the delete result plus a follow-up query.
* [attemptResourceGroupDelete.sh](./attemptResourceGroupDelete.sh) performs the resource group delete test and prints the delete result plus a follow-up query.

## What each stage proves

### Stage 1

This creates the target resource group and deploys the managed resources without deny settings. This gives the later stages a consistent starting point. The deployment can be done with either a sub or group scope deployment stack.

### Stage 2

Stage 2 demonstrates a successful block. This is because the deletion is attempted against the resource, rather than the resource group. 


* [Create deployment stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks#create-deployment-stacks)
* [Protect managed resources](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks?tabs=azure-powershell#protect-managed-resources)

### Stage 3 - Demonstrate Resource Group scope denyDelete Action is ineffective at blocking Resource Group deletion

This stage demonstrates an important distinction: blocking delete of a managed child resource is not the same thing as guaranteeing that a resource group delete will always be blocked in every path you test.

It helps isolate how the current environment behaves when the parent-scoped deny setting is already in place and the delete target is the resource group itself.

### Stage 4 - Demonstrate Subscription scope denyDelete Action is ineffective at blocking Resource Group deletion

This is the stage that directly demonstrates the documented Microsoft Learn limitation. The RG-scoped deny setting is present, but the resource group delete still succeeds.

That is the behavior described in the Learn quote above.

## What this demo proves

This demo proves several concrete points.

* Deployment stack deny settings are real and observable. They can block delete operations against managed resources.
* The property is ineffective against Resource Group deletion.

## Conclusion

The ability to delete resources by targetting the resource group limits the functional usefulness of this tool. Resource Delete locks will prevent the deletion of the resource, but are independent of this functionality.

## Related Microsoft Learn resources

* [Create and deploy Azure deployment stacks in Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks)
* [Protect managed resources](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks?tabs=azure-powershell#protect-managed-resources)
* [Why use deployment stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks#why-use-deployment-stacks)
* [Create deployment stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks#create-deployment-stacks)
* [Delete deployment stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks#delete-deployment-stacks)
* [Lock your Azure resources to protect your infrastructure](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/lock-resources)
