# Project 3 (Terraform Edition) — README

## Overview

This is the Terraform rebuild of the Project 3 network architecture originally built in Bicep — a segmented two-tier network with a load balancer, NAT Gateway, and a second web VM added along the way. Built as a direct comparison exercise: same target architecture, different IaC tool, in order to be able to speak to both in an interview rather than just one.

---

## Objectives Completed

- **Provider and resource group setup**, validated incrementally with `terraform validate` before adding more resources
- **VNet, two subnets, and two NSGs** — including the NSG-to-subnet association modeled as its own resource, a genuine structural difference from how Bicep expresses the same relationship inline
- **Two VMs on the original design** (web + data tier), each authenticated with the same SSH key pair used in the Bicep version, deployed with `terraform plan` reviewed before every `apply`
- **Load balancer** added on top of the original two-VM design, with a backend pool, health probe, and load-balancing rule
- **NAT Gateway** added to restore outbound internet access for backend-pool VMs without their own public IP — the same real-world gotcha first discovered in the Bicep/portal version of this project, this time solved in code from the start
- **A second web VM** (`vm-web2-dev`) provisioned entirely through Terraform, using `custom_data` (cloud-init) to automatically install Nginx and write a distinguishing page on first boot — no manual SSH-and-install step required, unlike the original portal-built second VM in Project 1
- **Inbound NAT rule on the load balancer** to preserve SSH access after removing the web VM's direct public IP, once traffic was properly routed through the load balancer
- **Verified segmentation and load distribution** using the same jump-box SSH proof and `curl`-loop distribution test established in the Bicep/portal versions
- **Full drift reconciliation** — later audited and imported every resource that had drifted outside this configuration (see the separate Terraform Reconciliation README for that work in full)

---

## Challenges We Ran Into (and How We Resolved Them)

### 1. An incorrect output attribute name
**Problem:** `outputs.tf` referenced `azurerm_network_interface.data_nic.private_ip_configuration[0].private_ip_address`, which doesn't exist on that resource.
**Fix:** Corrected it to `ip_configuration[0].private_ip_address` — matching the actual block name declared on the resource itself, since Terraform lets you reference a nested block's attributes back out using the same name you gave the block.

### 2. Relationships modeled as separate resources instead of inline properties
**Problem:** Coming from Bicep, where a subnet's NSG association is just a nested property, it wasn't obvious at first why Terraform's `azurerm` provider required a completely separate `azurerm_subnet_network_security_group_association` resource, and later the same pattern reappeared for `azurerm_network_interface_backend_address_pool_association`.
**Fix:** Recognized this as a consistent design pattern in this provider — relationships between two resources are frequently modeled as their own standalone resource rather than a property of either side — rather than treating each occurrence as a new, separate confusion.

### 3. Standard Load Balancer's outbound connectivity issue reappeared
**Problem:** Adding `vm-web2-dev` to the load balancer's backend pool (with no public IP of its own) broke its outbound internet access, causing the cloud-init `apt install nginx` step to fail silently on first boot — identical root cause to the issue first hit in Project 1's portal build.
**Fix:** Added the NAT Gateway resources (public IP, gateway, and the two association resources linking it to the subnet) to `main.tf` before deploying the second VM, this time solving it proactively in code rather than reactively after a failed deployment.

### 4. Missing required argument on the load balancer NAT rule
**Problem:** `azurerm_lb_nat_rule` failed validation with "The argument 'resource_group_name' is required" — a genuine omission when the resource block was first written, since not every `azurerm` resource infers its resource group from a parent reference the way some others do.
**Fix:** Added the missing `resource_group_name = azurerm_resource_group.rg.name` line, matching the pattern already used consistently elsewhere in the file.

### 5. PowerShell command syntax errors while running Terraform commands
**Problem:** Backtick line-continuation characters with trailing whitespace caused `az` and `terraform` commands to be misparsed as separate, invalid commands — most visibly on a `terraform plan`/`apply` command that PowerShell split apart, producing a confusing "missing expression after unary operator" error.
**Fix:** Defaulted to single-line commands rather than backtick-continued multi-line ones for the rest of the project, eliminating this entire class of copy-paste failure.

---

## What We Learned

- **Rebuilding an already-understood architecture in a second tool is a genuinely efficient way to learn that tool.** Since the network design itself was already reasoned through in the Bicep version, this project was really about learning Terraform's idioms specifically — which made real differences (like the separate-resource relationship pattern) much easier to spot and internalize than building both from scratch simultaneously would have been.
- **Some infrastructure gotchas are tool-agnostic.** The Standard Load Balancer outbound connectivity issue wasn't a Bicep problem or a Terraform problem — it's an Azure networking behavior that shows up regardless of which IaC tool is used, and recognizing that let it be solved proactively the second time instead of being rediscovered as a surprise.
- **`terraform plan` is worth running after every single resource block addition, not just at the end.** Validating incrementally (per the network module, then VMs, then load balancer, then NAT Gateway) caught issues like the missing `resource_group_name` argument immediately, rather than after a much larger batch of changes.
- **cloud-init (`custom_data`) is a meaningfully better pattern than manual post-deployment configuration.** The second web VM configuring itself automatically on first boot, versus the original Project 1 second VM requiring a manual SSH-and-install step, is a real demonstration of infrastructure-as-code maturity worth calling out explicitly in an interview.

---

## Files in This Project

```
azure-terraform-project/
├── main.tf                # Provider, resource group, network, VMs, LB, NAT Gateway
├── monitoring.tf           # Added later during drift reconciliation (Project 4 resources)
├── automation.tf           # Added later during drift reconciliation (Project 5 resources)
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
└── .gitignore
```

See the separate **Project 3 README** for the Bicep version of this same architecture, and the **Terraform Reconciliation README** for the drift-detection and import work that brought Projects 4 and 5's resources under this same configuration.
