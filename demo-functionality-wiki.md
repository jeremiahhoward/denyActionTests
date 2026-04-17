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

That quote is the center of the demo.

## What the demo does

The demo creates a resource group, deploys a storage account and virtual network, applies deployment stack deny settings, and then attempts deletion operations to observe the result.

The scripts currently work as a staged walkthrough.

* [1-newDeploymentStack.sh](./1-newDeploymentStack.sh) creates the initial resource group and deploys [stage1.bicep](./stage1.bicep) with no deny settings.
* [2-applySubDenyAction.sh](./2-applySubDenyAction.sh) creates a subscription-scoped deployment stack with `denyDelete` and attempts to delete the managed storage account.
* [4-applyCascadeIneffective.sh](./4-applyCascadeIneffective.sh) uses the existing subscription-scoped stack from stage 2 and attempts to delete the resource group.
* [3-applyGroupDenyAction.sh](./3-applyGroupDenyAction.sh) removes the subscription-scoped stack, creates a resource-group-scoped deployment stack with `denyDelete`, and then attempts to delete the resource group.
* [attemptStorageAccountDelete.sh](./attemptStorageAccountDelete.sh) performs the storage account delete test and prints the delete result plus a follow-up query.
* [attemptResourceGroupDelete.sh](./attemptResourceGroupDelete.sh) performs the resource group delete test and prints the delete result plus a follow-up query.

## What each stage proves

### Stage 1

Stage 1 establishes the baseline.

It creates the target resource group and deploys the managed resources without deny settings. This gives the later stages a consistent starting point.

### Stage 2

Stage 2 uses `az stack sub create` to create the deployment stack at subscription scope.

That means the deny assignment is anchored above the target resource group. The stack still deploys the managed resources into the resource group through `--deployment-resource-group`, but the stack resource itself exists at the parent scope.

This stage proves that subscription-scoped deployment stack deny settings can effectively block deletion of managed resources. *In the current demo, the managed resource under test is the storage account.* **Note that the storage account cannot be directly deleted.**
Relevant Microsoft Learn links:

* [Create deployment stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks#create-deployment-stacks)
* [Protect managed resources](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks?tabs=azure-powershell#protect-managed-resources)

### Stage 3

Stage 3, which is implemented in [4-applyCascadeIneffective.sh](./4-applyCascadeIneffective.sh), keeps using the existing subscription-scoped stack from stage 2 and tests resource group deletion.

This stage demonstrates an important distinction: blocking delete of a managed child resource is not the same thing as guaranteeing that a resource group delete will always be blocked in every path you test.

It helps isolate how the current environment behaves when the parent-scoped deny setting is already in place and the delete target is the resource group itself.

### Stage 4

Stage 4, implemented in [3-applyGroupDenyAction.sh](./3-applyGroupDenyAction.sh), removes the subscription-scoped stack, creates an RG-scoped stack with `az stack group create`, and then attempts resource group deletion.

This is the stage that directly demonstrates the documented Microsoft Learn limitation. The RG-scoped deny setting is present, but the resource group delete still succeeds.

That is the behavior described in the Learn quote above.

## Why scope matters

Azure deployment stacks create deny assignments at the scope where the stack exists.

Microsoft Learn explains this clearly in the deployment stacks documentation.

* A stack at resource group scope exists inside that resource group.
* A stack at subscription scope exists at the subscription and can deploy resources into a resource group.
* The deny assignment is created where the stack exists.

Relevant Microsoft Learn links:

* [Create deployment stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks#create-deployment-stacks)
* [Why use deployment stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks#why-use-deployment-stacks)

In practice, that means:

* Subscription-scoped stacks are better suited to protecting resources deployed into a resource group.
* Resource-group-scoped stacks do not protect the resource group itself from the documented bypass behavior.

## What this demo proves

This demo proves several concrete points.

* Deployment stack deny settings are real and observable. They can block delete operations against managed resources.
* Scope is not a cosmetic detail. It changes where the deny assignment exists and what protection pattern you actually get.
* A subscription-scoped deployment stack can successfully demonstrate deny protection on managed resources such as the storage account in this repo.
* A resource-group-scoped deployment stack does not reliably prevent deletion of the resource group itself, because Microsoft documents that this scenario currently bypasses deny assignments.

## What this demo does not prove

This repo does not claim that every resource group delete is always blocked by every subscription-scoped stack configuration.

Instead, it demonstrates the narrower and more defensible point: managed resource deletion and resource group deletion are not equivalent tests, and RG-scoped stack deny behavior has a documented limitation.

If you need hard protection for the resource group itself, you should evaluate management locks in addition to deployment stack deny settings.

Relevant Microsoft Learn link:

* [Lock your Azure resources to protect your infrastructure](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/lock-resources)

## Suggested way to read the results

When you run the demo, focus on the delete target and the stack scope together.

* If the target is a managed storage account and the stack is subscription-scoped, deletion should be blocked.
* If the target is the resource group and the stack is resource-group-scoped, the delete can still succeed.
* If a lock is applied to a resource in the group, the behavior changes because the lock introduces a different protection mechanism.

That combination of observations is the value of the demo.

## Conclusion

The ability to delete resources by targetting the resource group limits the functional usefulness of this tool. Resource Delete locks will prevent the deletion of the resource, but are independent of this functionality.

## Related Microsoft Learn resources

* [Create and deploy Azure deployment stacks in Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks)
* [Protect managed resources](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks?tabs=azure-powershell#protect-managed-resources)
* [Why use deployment stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks#why-use-deployment-stacks)
* [Create deployment stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks#create-deployment-stacks)
* [Delete deployment stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks#delete-deployment-stacks)
* [Lock your Azure resources to protect your infrastructure](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/lock-resources)
