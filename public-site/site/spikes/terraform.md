---
title: Terraform
layout: document
toc: true
---

### TL;DR

Terraform seems to be quite powerful and easy to use. The configuration files are clean and easily read and understood.
Supports basically every platform you need.

Azure provider (only one tested) runs into some issues sometimes with resource creation/deletion deadlocks, but this could be due to configuration not being optimal.

Update: this seems to be related to problems in a specific region - once moving to another azure region, it worked again

Can do both infrastructure provisioning and VM configuration, but seems the recommended way would be to use Terraform for infrastructure and then Ansible to configure and set up Kubernetes.

---

Infrastructure as code - Terraform enables you to safely and predictably create, change and improve infrastructure.

Some [best practices](https://www.terraform.io/docs/enterprise/guides/recommended-practices/index.html)

## Pros

* Structured language
  * Terraform language is JSON-like and clean
  * Wide support for various [providers](https://www.terraform.io/docs/providers/index.html)
    * Providers are used to interact with various APIs
    * All essential ones seem to be present 
  * [Customizable](https://www.terraform.io/guides/writing-custom-terraform-providers.html)
    * Terraform allows for writing custom providers
  * State management
    * Terraform uses state to keep track of realized infrastructure
    * Supports storing state remotely
    * If state is lost, Terraform will query the configured resources for its state and attempt a rebuild of its own state
      * This may fail in some cases
      * Best practice: Dont lose state
  * Remote exec of scripts via ssh
    * Terraform supports various [provisioners](https://www.terraform.io/docs/provisioners/index.html) which lets you provision files and run scripts once resources are up and running
  * Supports variables
    * Prevents hard-coding of values and lets you do interpolations and refer to other resource values

```json
resource "azurerm_network_interface" "staasmaster" {
    count               = "${var.master_count}"
    name                = "${var.cluster_name}-master-network-interface-${count.index}"
    location            = "${azurerm_resource_group.staas.location}"
    resource_group_name = "${azurerm_resource_group.staas.name}"
}
```

  * [Customizable](https://www.terraform.io/docs/providers/template/index.html)
    * Allows for generating config files etc using computed values or configured variables

## Cons

  * As noted above: it can get confused if state is lost or corrupted
  * How do we deal with removing and replacing specific resource?
    * Remove faulty k8s node from k8s cluster and tear down its resources -> replace with fresh one
  * Seems to have issues destroying some Azure resources
    * Keeps trying to delete resource and never finishes in some cases - perhaps deadlock?
  * Issues with creation deadlocks
    * Some resources (virtual network) seem to sometimes get stuck in a deadlock and never finish creating
