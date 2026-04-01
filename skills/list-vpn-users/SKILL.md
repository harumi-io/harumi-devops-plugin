---
name: list-vpn-users
description: "List all VPN client certificates and their status. Use when: user wants to see VPN users, list VPN certificates, or check who has VPN access."
---

# List VPN Users

List all issued VPN client certificates and their validity status.

## Execution Steps

### Step 1: List certificates

```bash
./scripts/generate-vpn-certs.sh list
```

### Step 2: Display results

Display the formatted output showing all certificates with their status and validity dates.
