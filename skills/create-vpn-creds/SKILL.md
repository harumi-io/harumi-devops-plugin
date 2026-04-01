---
name: create-vpn-creds
description: "Generate VPN client certificate and export .ovpn config file for a user. Use when: user wants to create VPN credentials, generate VPN access, or set up VPN for someone."
---

# Create VPN Credentials

Generate a VPN client certificate and export the `.ovpn` configuration file.

## Inputs

Ask for the username if not provided. Use the hyphenated format (e.g., `joao-silva`).

## Execution Steps

### Step 1: Generate client certificate

```bash
./scripts/generate-vpn-certs.sh client {username}
```

If the script reports the certificate already exists and asks about regeneration, relay the question to the user.

### Step 2: Export .ovpn config

```bash
./scripts/generate-vpn-certs.sh export {username}
```

### Step 3: Report

```
VPN credentials created!

Config file: .vpn-pki/client-configs/{username}.ovpn
Distribute via 1Password or encrypted channel — never send credentials over email or Slack.

The user should import the .ovpn file into the AWS VPN Client app.
```
