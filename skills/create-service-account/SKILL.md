---
name: create-service-account
description: "Create a new IAM service account in the Harumi infrastructure repo. Supports simple (no keys) and full (access keys + Secrets Manager) patterns. Use when: user wants to create a new AWS service account."
---

# Create Service Account

Create a new IAM service account. Two patterns available based on whether the account needs programmatic access keys.

## Inputs

Ask for these if not provided:

1. **Service account name** (e.g., `my-service`)
2. **Needs access keys?** (yes/no) — determines which pattern to use

## Naming Derivation

From the service account name:
- `directory_name`: the name as-is, hyphenated (e.g., `my-service`)
- `module_suffix`: underscored (e.g., `my_service`)

## Execution Steps

### Step 1: Verify account does not already exist

Check that `iam/service-accounts/{directory_name}/` does not already exist. If it does, report the conflict and stop.

### Step 2: Create service account directory

**Pattern A: No access keys (simple)**

Create `iam/service-accounts/{directory_name}/main.tf`:

```hcl
module "{module_suffix}" {
  source    = "../_base-module"
  user_name = "{name}"
}
```

Create `iam/service-accounts/{directory_name}/outputs.tf`:

```hcl
output "user_name" {
  value = module.{module_suffix}.user_name
}

output "user_arn" {
  value = module.{module_suffix}.user_arn
}
```

**Pattern B: With access keys (full)**

Create `iam/service-accounts/{directory_name}/main.tf`:

```hcl
resource "aws_iam_user" "this" {
  name = "{name}"
  path = "/service-accounts/"

  tags = {
    Project     = "harumi"
    UserType    = "ServiceAccount"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_access_key" "this" {
  user = aws_iam_user.this.name
}

resource "aws_secretsmanager_secret" "credentials" {
  name                    = "service-account-{name}-credentials"
  description             = "{name} service account AWS credentials"
  recovery_window_in_days = 7

  tags = {
    Project        = "harumi"
    Environment    = var.environment
    ManagedBy      = "terraform"
    ServiceAccount = "{name}"
  }
}

resource "aws_secretsmanager_secret_version" "credentials" {
  secret_id = aws_secretsmanager_secret.credentials.id
  secret_string = jsonencode({
    access_key_id     = aws_iam_access_key.this.id
    secret_access_key = aws_iam_access_key.this.secret
    username          = aws_iam_user.this.name
    region            = var.region
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
```

Create `iam/service-accounts/{directory_name}/variables.tf`:

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}
```

Create `iam/service-accounts/{directory_name}/outputs.tf`:

```hcl
output "user_name" {
  value = aws_iam_user.this.name
}

output "user_arn" {
  value = aws_iam_user.this.arn
}

output "secret_arn" {
  value = aws_secretsmanager_secret.credentials.arn
}
```

### Step 3: Register module in iam/main.tf

Add a module block under the `## Service Accounts` section:

**Pattern A (no keys):**
```hcl
module "iam_service_accounts_{module_suffix}" {
  source = "./service-accounts/{directory_name}"
}
```

**Pattern B (with keys):**
```hcl
module "iam_service_accounts_{module_suffix}" {
  source = "./service-accounts/{directory_name}"

  environment = var.environment
  region      = var.region
}
```

### Step 4: Validate and plan

```bash
cd iam && terraform validate
cd iam && terraform plan -var-file=prod.tfvars
```

### Step 5: Hand off apply

```
Configuration ready for apply!

Execute: cd iam && terraform apply -var-file=prod.tfvars
Changes: New service account {name} [with/without] access keys
Verification: aws iam get-user --user-name {name}
```

If Pattern B was used, add: "After apply, retrieve credentials from Secrets Manager: `aws secretsmanager get-secret-value --secret-id service-account-{name}-credentials`"
