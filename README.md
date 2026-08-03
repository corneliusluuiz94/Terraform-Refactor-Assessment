# Terraform Multi-Environment AWS Infrastructure

A refactored Terraform project that deploys a small AWS application stack (VPC, subnet(s), EC2 web instances, S3 bucket, CloudWatch alarm) into `dev`, `staging`, and `prod` environments within a single AWS account, using Terraform workspaces.

This project started as a single hardcoded `main.tf` and was incrementally refactored via a `feature/* → review → main` branching workflow — see the closed PRs on this repo for the full step-by-step history of each change.

## What This Deploys

- `aws_vpc.main` — the VPC
- `aws_subnet.public` — one subnet per availability zone (loop-driven)
- `aws_security_group.web_sg` — allows inbound SSH (22) and HTTP (80)
- `aws_instance.web` — one or more web EC2 instances (loop-driven)
- `aws_s3_bucket.app_bucket` + `aws_s3_bucket_versioning.app_bucket` — application storage bucket
- `aws_cloudwatch_metric_alarm.cpu_alarm` — CPU utilization alarm (prod only)

## Project Structure

| File | Purpose |
|---|---|
| `versions.tf` | Terraform and AWS provider version constraints |
| `providers.tf` | AWS provider configuration (region, profile) |
| `variables.tf` | All input variables, including validation rules |
| `main.tf` | All resources: networking, security, compute, storage, monitoring |
| `outputs.tf` | Values exposed after apply |
| `terraform.tfvars` | Variable values used locally |
| `.gitignore` | Excludes `.terraform/`, state files, and crash logs |
| `.terraform.lock.hcl` | Pins exact provider version/checksums (committed intentionally) |

No credentials or environment-specific values are hardcoded inside any resource block — everything environment-dependent flows from `variables.tf`, `terraform.tfvars`, or the active workspace.

## How Workspaces Map to Environments

Environment is **not** a manually-typed variable. It's derived directly from the active Terraform workspace:

```hcl
locals {
  environment = terraform.workspace
}
```

This means the only way to change environment is to actually switch workspaces — there's no free-text field where a typo could sneak into a resource name or tag.

```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

terraform workspace select dev
terraform apply

terraform workspace select prod
terraform apply
```

Each workspace maintains a completely separate state file, so `dev`, `staging`, and `prod` resources never collide or overwrite one another, even though they deploy into the same AWS account. Every resource name/tag includes `${local.environment}` to guarantee uniqueness (e.g. `app-bucket-dev` vs `app-bucket-prod`).

## `for_each` vs `count` — Why Each Was Chosen

| Resource | Construct | Reasoning |
|---|---|---|
| Subnets (`aws_subnet.public`) | `for_each` over `toset(var.availability_zones)` | Each subnet is keyed by something meaningful — its AZ name. If the AZ list is reordered, Terraform still recognizes the same subnet by key and won't destroy/recreate it. `count` would key by index instead, so a list reorder would cause unnecessary resource churn. |
| EC2 instances (`aws_instance.web`) | `count` | Instances are interchangeable and naturally indexed (`web-instance-0`, `web-instance-1`, ...). There's no meaningful key to group them by the way AZ groups subnets, so index-based `count` is the simpler, correct fit. |

Subnet CIDR blocks are derived programmatically with `cidrsubnet(var.vpc_cidr, 4, index(...))` rather than hardcoded per-subnet, so adding or removing an AZ doesn't require manually picking new CIDR ranges.

## Environment-Conditional Behavior

| Behavior | dev | staging | prod |
|---|---|---|---|
| CloudWatch CPU alarm | Not created | Not created | Created |
| S3 bucket versioning | Suspended | Enabled | Enabled |
| EC2 instance type | `t2.micro` | `t3.small` | `t3.medium` |

- The alarm uses `count = local.environment == "prod" ? 1 : 0` — in dev/staging the resource simply doesn't exist, rather than existing in some "disabled" state.
- S3 versioning is its own resource (`aws_s3_bucket_versioning`), since it's not an inline attribute on `aws_s3_bucket` in the current AWS provider. It always exists; only its `status` changes based on environment.
- Instance type comes from `var.instance_type_map[local.environment]` — a single map variable, not separate copies of the `aws_instance` resource.

## Variable Validation

Three variables have `validation` blocks:

- `instance_count` — must be at least 1
- `availability_zones` — must contain at least one AZ
- `instance_type_map` — must include an entry for each of `dev`, `staging`, `prod`, so a missing key fails fast at plan time instead of crashing later during the `local.environment` lookup

`environment` itself isn't a separate validated variable, since it's derived from `terraform.workspace` — you can only ever be in one of the three workspaces that exist, which is a stronger guarantee than input validation on a free-text variable.

## Outputs

| Output | Description |
|---|---|
| `vpc_id` | ID of the VPC |
| `instance_ids` | IDs of all web EC2 instances (list) |
| `instance_public_ips` | Public IPs of all web EC2 instances |
| `s3_bucket_name` | Name of the application S3 bucket |
| `cloudwatch_alarm_created` | `true` only in prod |

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with a **named profile** (not `default`):
  ```bash
  aws configure --profile terraform-refactor
  aws sts get-caller-identity --profile terraform-refactor
  ```

## Running It

A single `terraform.tfvars` covers all three environments — there's no need for separate per-environment `.tfvars` files, since environment-specific differences are already handled by `terraform.workspace` and `instance_type_map`.

```bash
terraform init

terraform workspace select dev      # or staging / prod
terraform plan
terraform apply
```

Update `aws_profile` and `aws_region` in `terraform.tfvars` to match your own AWS CLI profile before applying. Update the S3 bucket name in `main.tf` if it's already taken — bucket names must be globally unique across all of AWS.

To tear down:

```bash
terraform destroy
```

## Development Workflow

Changes were made incrementally via feature branches, merged into a `review` branch, and finally submitted as a single `review → main` PR:

```
feature/project-structure          → review
feature/provider-config            → review
feature/workspaces                 → review
feature/loops-subnets-instances    → review
feature/conditional-resources      → review
feature/variable-validation        → review
feature/outputs                    → review
feature/readme                     → review
                                      review → main   (final PR)
```

See the closed PRs on this repository for the full history of each change.
