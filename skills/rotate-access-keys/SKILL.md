---
name: rotate-access-keys
description: "Rotate IAM access keys for a user or service account. Creates new key, deactivates old key. Use when: user wants to rotate access keys, renew credentials, or replace an access key."
---

# Rotate Access Keys

Rotate IAM access keys for a user or service account. Creates a new key before deactivating the old one to avoid downtime.

## Inputs

Ask for the IAM username if not provided.

## Execution Steps

### Step 1: List current access keys

```bash
aws iam list-access-keys --user-name {username}
```

If no keys found, report: "No access keys found for {username}. Nothing to rotate." and stop.

If the user already has 2 access keys (AWS maximum), report:

```
User {username} already has 2 access keys (AWS limit).
You must delete one before creating a new one.

Keys:
- {key1_id} (Status: {status}, Created: {date})
- {key2_id} (Status: {status}, Created: {date})

Which key should I delete first?
```

Wait for the user's choice, then delete that key before proceeding:

```bash
aws iam delete-access-key --user-name {username} --access-key-id {chosen_key_id}
```

### Step 2: Create new access key

```bash
aws iam create-access-key --user-name {username}
```

### Step 3: Display new credentials

```
New access key created:

Access Key ID:     {new_access_key_id}
Secret Access Key: {new_secret_access_key}

IMPORTANT: Save these credentials now. The secret access key cannot be retrieved again.
Update all services using this account before deactivating the old key.
```

### Step 4: Confirm old key deactivation

If there was a previous key still active:

```
Ready to deactivate old key {old_key_id}? Make sure all services have been updated first.
Type 'yes' to deactivate.
```

Do NOT proceed without "yes".

### Step 5: Deactivate old key

```bash
aws iam update-access-key --user-name {username} --access-key-id {old_key_id} --status Inactive
```

### Step 6: Report

```
Old key {old_key_id} deactivated (not deleted).

To delete it permanently after verification:
aws iam delete-access-key --user-name {username} --access-key-id {old_key_id}
```
