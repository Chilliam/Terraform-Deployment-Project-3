# Project 3: Infrastructure as Code — README

## Overview

This project rebuilt the Project 1 network architecture as code — first in Bicep, then again in Terraform — adding a load balancer, a second web VM, and a NAT Gateway along the way. It ended up being the most technically demanding project in the series, spanning two full IaC toolchains, cross-machine access issues, and eventually a full drift-reconciliation exercise.

---

## Objectives Completed

- **Modular Bicep template** — a reusable network module and a single VM module that deploys both the public web tier and the private data tier from the same code, using a conditional public IP
- **Modular Terraform configuration** rebuilding the identical architecture, including a working comparison of how each tool models resource relationships differently
- **Load balancer, second web VM, and NAT Gateway** added to both the Bicep and Terraform versions, extending the original two-VM design into a more realistic environment
- **Dry-run discipline throughout** — `az deployment group what-if` and `terraform plan` used consistently before every real deployment
- **Cross-machine access** — successfully reconnected to the environment from a second computer, requiring new SSH keys, updated NSG rules, and re-authentication
- **Full Terraform drift reconciliation** — later audited the live environment against the Terraform state and imported every drifted resource (see the separate Terraform Reconciliation README)

---

## Challenges We Ran Into (and How We Resolved Them)

### 1. Local environment setup friction (Windows/PowerShell specific)
**Problem:** Several early steps failed due to Windows-specific quirks: `New-Item` creating empty files that needed separate content-writing steps, `ssh-keygen` failing with "no such file or directory" because the `.ssh` folder didn't exist yet, and PowerShell's backtick line-continuation syntax silently breaking commands when a trailing space followed the backtick.
**Fix:** Established reliable patterns for each — explicitly creating the `.ssh` directory before key generation, and defaulting to single-line commands rather than backtick-continued multi-line ones to eliminate an entire category of copy-paste failure.

### 2. Bicep deployment failed claiming the template had no parameters
**Problem:** `InvalidTemplate` error stating the template defined zero parameters, despite `main.bicep` clearly containing several.
**Fix:** Traced to the file never actually being saved — confirmed via `Get-Content` returning empty, then re-populated and saved the file correctly.

### 3. A Project 2 governance policy blocked deployment
**Problem:** Deployment failed due to a required-tag policy — the same subscription-scoped policy from Project 2 surfaced again here, blocking an unrelated project's deployment.
**Fix:** Narrowed the policy assignment's scope back to its intended resource group, confirmed via `az policy assignment list` before retrying.

### 4. SSH access broke repeatedly across key rotations, agent state, and NSG scope changes
**Problem:** A recurring cluster of related SSH failures: "Permission denied (publickey)" after switching from portal-built to Bicep-deployed VMs (key mismatch), the local `ssh-agent` Windows service found stopped and disabled, `ssh-add` reporting "no identities" even once the service was running, and later a connection timeout after switching to a second physical computer (NSG rule still scoped to the original machine's IP).
**Fix:** Diagnosed each layer independently — enabled and started the `ssh-agent` service, explicitly loaded the key with `ssh-add`, used agent forwarding (`-A`) consistently for jump-box access, and updated the NSG's `Allow-SSH` rule's source IP whenever switching networks/machines.

### 5. Removing the web VM's public IP (to route through the load balancer) broke direct SSH entirely
**Problem:** After removing the VM's own public IP as part of properly routing traffic through the load balancer, SSH access had no path in at all — the load balancer only had an HTTP rule.
**Fix:** Added an **Inbound NAT Rule** on the load balancer, forwarding a custom port to the VM's private port 22 — the standard pattern for SSH access to VMs sitting behind a load balancer without their own public IP.

### 6. Terraform-specific modeling differences caused repeated early confusion
**Problem:** Several Bicep-to-Terraform translation issues: an incorrect output attribute name (`private_ip_configuration` vs. the correct `ip_configuration`), and initial confusion about why NSG-to-subnet and NIC-to-backend-pool relationships required separate association resources rather than inline properties like in Bicep.
**Fix:** Corrected the attribute reference, and recognized the recurring "relationships are their own resource" pattern in Terraform's `azurerm` provider — a pattern that came up again later in the drift-reconciliation work with runbook-to-schedule links.

### 7. Standard Load Balancer's outbound connectivity issue resurfaced in Terraform
**Problem:** The same NAT Gateway requirement from Project 1 reappeared when adding a second web VM via Terraform.
**Fix:** Added the NAT Gateway resources (public IP, gateway, and both association resources) directly to the Terraform configuration, this time as reusable code rather than a one-off portal fix.

### 8. Azure CLI itself was blocked by a corrupted extension
**Problem:** A Windows file-permission lock on the `ssh` CLI extension's folder caused every single `az` command to fail with a Python traceback, including completely unrelated commands like automation account creation.
**Fix:** Removed the corrupted extension folder directly after closing all terminal sessions to release the file lock.

### 9. Authentication failures when switching to a different computer
**Problem:** `az login` failed with a Conditional Access-related tenant authentication error on a new machine.
**Fix:** Specified the tenant explicitly with `--tenant`, and used device code authentication as a more reliable fallback when the automatic browser flow didn't behave as expected.

---

## What We Learned

- **Windows-specific tooling friction is real and worth planning for**, not a sign of doing something wrong — execution policy, PATH refreshes after installs, and PowerShell syntax quirks (backticks, here-strings) came up repeatedly and each had a specific, learnable fix.
- **The same conceptual mistake can resurface in a different tool.** The Standard Load Balancer outbound connectivity issue and the "relationships as separate resources" pattern both appeared first in one context (portal/Bicep) and then again in another (Terraform) — recognizing a previously-solved problem in a new context is faster than re-diagnosing from scratch.
- **SSH/jump-box troubleshooting benefits from isolating each layer**: is the agent running, is the key loaded, is agent forwarding active, does the NSG allow the current source IP, does the target actually trust this key. Treating "SSH isn't working" as one problem rather than five stacked possibilities would have made this much slower to resolve.
- **Removing a public IP has downstream consequences that need their own fix** — routing web traffic through a load balancer "the right way" introduced a new, real problem (no SSH path) that needed its own deliberate solution (inbound NAT rule), not just an assumption that the LB would handle everything.
- **Bicep and Terraform solve the same problems with different idioms**, and knowing both well enough to translate between them — including their respective rough edges — is a genuine differentiator worth having in a portfolio.

---

## Files in This Project

```
azure-iac-project/                  # Bicep version
├── main.bicep
├── modules/
│   ├── network.bicep
│   └── vm.bicep
└── main.parameters.dev.json

azure-terraform-project/            # Terraform version
├── main.tf
├── monitoring.tf
├── automation.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars.example
```

See the separate **Terraform Reconciliation README** for the drift-detection and `terraform import` work that followed this project.
