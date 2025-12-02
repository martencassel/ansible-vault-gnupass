FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install packages
RUN apt update && \
    apt install -y locales pass gnupg pinentry-curses screen vim less python3 python3-pip git && \
    rm -rf /var/lib/apt/lists/*

# Configure locale automatically
RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=en_US.UTF-8

# Install Ansible
RUN pip3 install --break-system-packages ansible passlib

# Generate a GPG key in batch mode
RUN gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 2048
Name-Real: Docker Test User
Name-Email: docker@example.com
Expire-Date: 0
%no-protection
%commit
EOF

# Vault password helper script
RUN echo '#!/bin/bash\npass show ansible/vault' > /usr/local/bin/ansible-vault-pass && \
    chmod +x /usr/local/bin/ansible-vault-pass

# Configure Ansible to use helper
RUN mkdir -p /etc/ansible && \
    echo '[defaults]\nvault_password_file = /usr/local/bin/ansible-vault-pass' > /etc/ansible/ansible.cfg

# Initialize pass with the generated key and insert vault password
RUN KEYID=$(gpg --list-keys --with-colons docker@example.com | awk -F: '/^pub/ {print $5; exit}') && \
    pass init "$KEYID"

RUN echo "MyVaultPassword123" | pass insert --multiline --force ansible/vault


# Create a sample file and encrypt it with Ansible Vault
RUN echo "secret_content: super_secret_value" > /root/secret.yml && \
    ansible-vault encrypt /root/secret.yml

# After start helper
RUN echo "ansible-vault view /root/secret.yml" > /root/after_start.sh && \
    chmod +x /root/after_start.sh

CMD ["bash"]
