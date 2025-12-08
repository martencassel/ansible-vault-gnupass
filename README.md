# Ansible Vault Password Helper

## Problem
By default, **Ansible Vault** requires you to type a password every time you encrypt, decrypt, or edit a file.
Sharing that password among teammates or storing it in plaintext is both inconvenient and insecure.

## Goal
Automate vault password retrieval by pulling it from a secure store (such as a GnuPG‑backed password manager like [`pass`](https://www.passwordstore.org/)).
This way, you avoid typing the password repeatedly or keeping it in your repository.

## Approach
A small helper script is used as Ansible’s `--vault-password-file`.
The script simply prints the vault password to `stdout`:

- If [`pass`](https://www.passwordstore.org/) is available, it fetches the secret from there.
- Otherwise, it can fall back to decrypting a GPG‑encrypted file.

Ansible reads the script’s output as the vault password.

---

## Setup

### 1. Create a GPG key (if you don’t already have one)
```bash
gpg --full-generate-key
gpg --list-secret-keys
```

### 2. Install and configure `pass` (recommended)
```bash
sudo apt install pass
pass init "Your Key ID"
```

Store the vault passphrase:
```bash
pass insert ansible/vault-password
```
Enter the vault password when prompted.

### 3. Add the helper script
Save the script as `~/bin/vault_pass_helper.sh`, make it executable, and secure it:
```bash
chmod 700 ~/bin/vault_pass_helper.sh
```

### 4. Configure Ansible to use the helper
Export the environment variable for convenience:
```bash
export ANSIBLE_VAULT_PASSWORD_FILE="$(pwd)/bin/vault_pass_helper.sh"
```

---

## Usage

### Encrypt a file
```bash
ansible-vault encrypt secrets.yaml
```

### Decrypt a file
```bash
ansible-vault decrypt secrets.yaml
```

### Edit a file
```bash
ansible-vault edit secrets.yaml
```

### Use with `--vault-password-file` directly
```bash
ansible-vault encrypt --vault-password-file ./bin/vault_pass_helper.sh secrets.yaml
```

### Run playbooks
```bash
ansible-playbook site.yaml
```

Whenever a vault secret is needed, Ansible will execute the helper script and use its output as the passphrase.

---

## How GPG Unlocking Works
When you use GPG to decrypt secrets (either directly or via `pass`), GPG must unlock your private key.
This typically involves:

- **Passphrase prompt**: The first time you use your key in a session, GPG will ask for your key’s passphrase.
- **GPG Agent caching**: Once entered, the passphrase is cached by `gpg-agent` for a configurable period (often minutes to hours).
- **Graphical dialogs**: On desktop systems, you may see a pinentry dialog window asking for your passphrase. On servers, it may prompt in the terminal.
- **Subsequent use**: As long as the agent cache is valid, you won’t be prompted again. This makes repeated Ansible runs seamless.

In practice, this means you’ll only type your GPG key’s passphrase occasionally, not every time Ansible Vault is used.

---

## Notes
- Keep your helper script private (`chmod 700`).
- Use `pass` for convenience and security; it integrates seamlessly with GPG.
- Expect to unlock your GPG key once per session; the agent will handle caching.
- This setup avoids storing plaintext passwords in repositories or sharing them manually.

