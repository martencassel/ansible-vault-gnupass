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
- **GPG Agent caching**: Once entered, the passphrase is cached by `gpg-agent` for a configurable period (<often minutes to hours).
- **Graphical dialogs**: On desktop systems, you may see a pinentry dialog window asking for your passphrase. On servers, it may prompt in the terminal.
- **Subsequent use**: As long as the agent cache is valid, you won’t be prompted again. This makes repeated Ansible runs seamless.

In practice, this means you’ll only type your GPG key’s passphrase occasionally, not every time Ansible Vault is used.

---

## Notes
- Keep your helper script private (`chmod 700`).
- Use `pass` for convenience and security; it integrates seamlessly with GPG.
- Expect to unlock your GPG key once per session; the agent will handle caching.
- This setup avoids storing plaintext passwords in repositories or sharing them manually.

Here’s a streamlined, text‑only version of the troubleshooting checklist:

---

## Troubleshooting Checklist

1. **Verify GPG**
   - `gpg --list-secret-keys` to confirm keys exist
   - Test encryption/decryption manually

2. **Check Pinentry**
   - Ensure a pinentry program is installed (`pinentry-tty`, `pinentry-curses`, `pinentry-gtk`)
   - Run `echo GETPIN | pinentry` to test

3. **Inspect gpg-agent**
   - Confirm agent is running (`ps -ef | grep gpg-agent`)
   - Restart with `gpgconf --kill gpg-agent && gpgconf --launch gpg-agent`
   - Check socket with `gpgconf --list-dirs agent-socket`

4. **IPC Resources**
   - Use `ipcs` to list message queues, semaphores, shared memory
   - Remove stale entries with `ipcrm` if needed

5. **Validate pass**
   - Run `pass ansible/vault-password` to confirm retrieval
   - Re‑init with `pass init <KeyID>` if failing

6. **Test Helper Script**
   - Execute `~/bin/vault_pass_helper.sh` directly
   - Ensure correct permissions (`chmod 700`)

7. **Confirm Ansible Integration**
   - Check `ANSIBLE_VAULT_PASSWORD_FILE` env var
   - Run `ansible-vault view secrets.yaml` to verify helper is used

---

Alright, let’s walk through what actually happens under the hood when you run something like:

```bash
ansible-vault edit secrets.yaml
```

with your helper script, `pass`, GPG, pinentry, and gpg-agent all in play. Think of it as a chain of cooperating processes:

---

## Low-Level Flow

1. **Ansible Vault starts**
   - You invoke `ansible-vault edit secrets.yaml`.
   - Ansible checks how to obtain the vault password. It sees the environment variable:
     ```
     ANSIBLE_VAULT_PASSWORD_FILE=~/bin/vault_pass_helper.sh
     ```
   - Instead of prompting you, Ansible spawns the helper script as a subprocess.

2. **Helper script runs**
   - The script executes and tries to fetch the vault password.
   - Typical logic:
     - First, call `pass ansible/vault-password`.
     - If `pass` is not available, fall back to decrypting a GPG‑encrypted file.

3. **`pass` program executes**
   - `pass` is just a thin wrapper around GPG.
   - It looks up the entry `ansible/vault-password` in its password store (a directory of `.gpg` files).
   - It calls GPG to decrypt the corresponding file.

4. **GPG invoked**
   - GPG tries to decrypt the file using your private key.
   - To do this, it needs to unlock your secret key material.
   - GPG contacts the **gpg-agent** process to handle the private key operations.

5. **gpg-agent checks cache**
   - If your key’s passphrase is already cached in memory, gpg-agent can immediately decrypt.
   - If not, gpg-agent needs to ask you for the passphrase.

6. **pinentry triggered**
   - gpg-agent launches the configured **pinentry** program (tty, curses, gtk, qt).
   - Pinentry displays a prompt (terminal full‑screen or graphical dialog).
   - You type your GPG key’s passphrase.
   - Pinentry sends the passphrase securely back to gpg-agent.

7. **gpg-agent unlocks key**
   - gpg-agent uses the passphrase to unlock your private key.
   - It caches the passphrase for a configurable time (minutes to hours).
   - It performs the decryption operation and returns plaintext to GPG.

8. **GPG returns plaintext**
   - GPG hands the decrypted vault password back to `pass`.
   - `pass` prints the password to stdout.

9. **Helper script outputs**
   - The helper script captures the output from `pass` (or GPG fallback).
   - It prints the vault password to stdout.
   - Ansible reads this stdout as the vault password.

10. **Ansible Vault decrypts file**
    - With the password, Ansible decrypts `secrets.yaml` in memory.
    - It opens your editor (e.g., `vim`, `nano`) with the plaintext contents.
    - When you save and exit, Ansible re‑encrypts the file using the same password.

---

## Process Chain Summary

```
ansible-vault
   └─ vault_pass_helper.sh
        └─ pass
             └─ gpg
                  └─ gpg-agent
                       └─ pinentry
```

- **Ansible** → runs helper
- **Helper** → calls `pass`
- **pass** → calls GPG
- **GPG** → asks gpg-agent
- **gpg-agent** → triggers pinentry if needed
- **pinentry** → collects passphrase
- **gpg-agent** → decrypts and caches
- **GPG** → returns plaintext secret
- **pass/helper** → prints vault password
- **Ansible** → uses it to decrypt/edit/re‑encrypt

---

## Why It Matters
- If pinentry fails, you’ll never get the vault password.
- If gpg-agent isn’t running or sockets are broken, GPG can’t unlock keys.
- If `pass` isn’t initialized with your key, it won’t find the secret.
- If the helper script isn’t executable, Ansible can’t call it.

