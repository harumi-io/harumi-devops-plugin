---
name: revoke-vpn-creds
description: "Revoke a VPN client certificate. Use when: user wants to revoke VPN access, remove VPN credentials, or disable VPN for someone."
---

# Revoke VPN Credentials

Revoke a VPN client certificate, removing the user's ability to connect.

## Inputs

Ask for the username if not provided.

## Execution Steps

### Step 1: List current certificates

Run the list command to show who currently has VPN access:

```bash
./scripts/generate-vpn-certs.sh list
```

Display the output to the user.

### Step 2: Confirm revocation

Ask for explicit confirmation:

```
Revoke VPN access for {username}? This will invalidate their certificate.
Type 'yes' to confirm.
```

Do NOT proceed without "yes".

### Step 3: Revoke certificate

```bash
./scripts/generate-vpn-certs.sh revoke {username}
```

### Step 4: Report

Report the result of the revocation command.
