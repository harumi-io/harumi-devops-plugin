---
name: remove-iam-user
description: "Remove an IAM user from the Harumi infrastructure repo. Deletes Terraform files, removes the module registration, and runs terraform plan. Use when: user wants to remove, delete, or offboard an AWS user."
---

# Remove IAM User

Remove an IAM user by deleting their Terraform directory and module registration.

## Inputs

Ask for the username if not provided. Optionally list current users first.

## Execution Steps

### Step 1: List current users

Read the directories under `iam/users/` and display them:

```
Current IAM users:
- andre-koga
- erick-jesus
- italo-rocha
- leandro-bandeira
- marcel-nicolay
- miriam-koga
- rafael-chuluc
- ricardo-leao
- wagner-souza
```

Ask which user to remove (or accept from the user's original request).

### Step 2: Verify user exists

Check that `iam/users/{directory_name}/` exists. If not, report and stop.

### Step 3: Confirm removal

Ask for explicit confirmation:

```
Remove user {user_name}? This will:
- Delete iam/users/{directory_name}/ directory
- Remove the module block from iam/main.tf
- On apply: delete the IAM user from AWS

Type 'yes' to confirm.
```

Do NOT proceed without "yes".

### Step 4: Remove module from iam/main.tf

Find and remove the `module "iam_users_{module_suffix}"` block from `iam/main.tf`. Remove the entire block including all its arguments and closing brace.

### Step 5: Delete user directory

Delete the entire `iam/users/{directory_name}/` directory.

### Step 6: Plan

```bash
cd iam && terraform plan -var-file=prod.tfvars
```

### Step 7: Hand off apply

```
Configuration ready for apply!

Execute: cd iam && terraform apply -var-file=prod.tfvars
Changes: Remove IAM user {user_name}
Verification: aws iam get-user --user-name {user_name} (should return NoSuchEntity)
```

Remind: "If this user has VPN access, also run `/revoke-vpn-creds` to revoke their certificate."
