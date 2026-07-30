# Terraform AWS Infrastructure (Baseline)

This is the starting point for a Terraform refactoring exercise.

## What this deploys

A single, hardcoded `main.tf` that provisions:

- A VPC and one subnet
- A security group allowing SSH (22) and HTTP (80)
- One EC2 instance
- One S3 bucket
- One CloudWatch CPU utilization alarm

## Known limitations (to be addressed by refactoring)

- Provider region is hardcoded; credentials rely on whatever default AWS CLI profile is active
- No input variables — everything is a literal value inside resource blocks
- No environment separation (dev/staging/prod)
- No workspaces — a single `terraform apply` targets one fixed set of resources
- No loops — subnets and instances are singular, hardcoded resources
- No conditional logic — every resource is always created
- No outputs
- No variable validation

## Running this baseline

```bash
terraform init
terraform plan
terraform apply
```

Update the AMI ID and S3 bucket name in `main.tf` before applying — the AMI may be stale by region/time, and the bucket name must be globally unique.

```bash
terraform destroy
```

---

This README will be replaced with a full architecture writeup once the project has been refactored into a proper multi-file, multi-environment structure (see `feature/readme` for that version).
