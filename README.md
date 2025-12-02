# ansible-vault-gnupass

A simple tutorial for integrating Ansible Vault with GnuPG and pass.

## Features
- Encrypt and decrypt Ansible Vault files using GnuPG keys
- Store secrets securely with pass
- Streamline secret management for Ansible projects

## Usage

### 1. Build the Docker image
```sh
make build
```

### 2. Encrypt a file with Ansible Vault
```sh
ansible-vault encrypt --vault-password-file <(pass show my/ansible/password) secrets.yml
```

### 3. Decrypt a file with Ansible Vault
```sh
ansible-vault decrypt --vault-password-file <(pass show my/ansible/password) secrets.yml
```

### 4. Using with GnuPG and pass
- Store your vault password in pass: `pass insert my/ansible/password`
- Ensure your GPG key is set up and pass is initialized.

### 5. Run inside Docker (if applicable)
```sh
docker run --rm -it \
   -v "$PWD:/workspace" \
   -v "$HOME/.gnupg:/root/.gnupg:ro" \
   -v "$HOME/.password-store:/root/.password-store:ro" \
   ansible-vault-gnupass
```

## Requirements
- Docker
- GnuPG
- pass
- Ansible

## License
MIT
# ansible-vault-gnupass
