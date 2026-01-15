# Ansible Configuration Management

This directory contains Ansible playbooks, roles, and inventory for homelab configuration management.

## Directory Structure

```
ansible/
├── playbooks/       # Ansible playbooks
├── roles/          # Custom Ansible roles
├── inventory/      # Inventory files
├── group_vars/     # Group-specific variables
├── host_vars/      # Host-specific variables
└── ansible.cfg     # Ansible configuration
```

## Prerequisites

### Install Ansible

```bash
# macOS
brew install ansible

# Linux (Ubuntu/Debian)
sudo apt update
sudo apt install ansible

# Using pip
pip3 install ansible

# Verify installation
ansible --version
```

### Install Required Collections

```bash
# Install community collections
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix

# Install roles
ansible-galaxy install -r requirements.yml
```

## Configuration

### ansible.cfg

```ini
[defaults]
inventory = ./inventory/production
remote_user = ansible
host_key_checking = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 86400
retry_files_enabled = False
roles_path = ./roles

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
```

## Inventory

### Static Inventory (inventory/production)

```ini
[proxmox_hosts]
pve-node-01 ansible_host=192.168.1.10
pve-node-02 ansible_host=192.168.1.11
pve-node-03 ansible_host=192.168.1.12

[web_servers]
web-01 ansible_host=192.168.10.10
web-02 ansible_host=192.168.10.11
web-03 ansible_host=192.168.10.12

[database_servers]
db-01 ansible_host=192.168.10.20

[docker_hosts]
docker-01 ansible_host=192.168.10.30

[monitoring]
prometheus-01 ansible_host=192.168.10.40
grafana-01 ansible_host=192.168.10.41

[nas]
truenas-01 ansible_host=192.168.10.50

[homelab:children]
proxmox_hosts
web_servers
database_servers
docker_hosts
monitoring
nas

[homelab:vars]
ansible_user=ansible
ansible_python_interpreter=/usr/bin/python3
```

### Dynamic Inventory

For cloud or dynamic environments:

```python
#!/usr/bin/env python3
# inventory/dynamic_proxmox.py

import json
import sys
from proxmoxer import ProxmoxAPI

proxmox = ProxmoxAPI('proxmox.homelab.local',
                     user='ansible@pam',
                     token_name='ansible',
                     token_value='secret')

inventory = {
    '_meta': {'hostvars': {}},
    'all': {'children': ['ungrouped']}
}

# Populate inventory from Proxmox
for node in proxmox.nodes.get():
    for vm in proxmox.nodes(node['node']).qemu.get():
        # Add VM to inventory
        pass

print(json.dumps(inventory))
```

## Playbooks

### Basic Server Setup

**playbooks/setup-server.yml**

```yaml
---
- name: Setup new server
  hosts: all
  become: yes

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"

    - name: Install essential packages
      apt:
        name:
          - vim
          - git
          - curl
          - htop
          - net-tools
          - python3-pip
        state: present

    - name: Configure timezone
      timezone:
        name: America/New_York

    - name: Set hostname
      hostname:
        name: "{{ inventory_hostname }}"

    - name: Configure SSH
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: "{{ item.regexp }}"
        line: "{{ item.line }}"
      loop:
        - { regexp: '^#?PermitRootLogin', line: 'PermitRootLogin no' }
        - { regexp: '^#?PasswordAuthentication', line: 'PasswordAuthentication no' }
      notify: Restart SSH

    - name: Setup firewall
      ufw:
        rule: "{{ item.rule }}"
        port: "{{ item.port }}"
        proto: "{{ item.proto }}"
      loop:
        - { rule: 'allow', port: '22', proto: 'tcp' }
        - { rule: 'allow', port: '443', proto: 'tcp' }

    - name: Enable firewall
      ufw:
        state: enabled

  handlers:
    - name: Restart SSH
      service:
        name: sshd
        state: restarted
```

### Docker Installation

**playbooks/install-docker.yml**

```yaml
---
- name: Install Docker
  hosts: docker_hosts
  become: yes

  tasks:
    - name: Install dependencies
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - gnupg
          - lsb-release
        state: present

    - name: Add Docker GPG key
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Add Docker repository
      apt_repository:
        repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
        state: present

    - name: Install Docker
      apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
          - docker-compose-plugin
        state: present
        update_cache: yes

    - name: Add user to docker group
      user:
        name: "{{ ansible_user }}"
        groups: docker
        append: yes

    - name: Enable Docker service
      systemd:
        name: docker
        enabled: yes
        state: started
```

### Application Deployment

**playbooks/deploy-app.yml**

```yaml
---
- name: Deploy application
  hosts: web_servers
  become: yes

  vars:
    app_name: myapp
    app_port: 8080
    app_dir: /opt/{{ app_name }}

  tasks:
    - name: Create application directory
      file:
        path: "{{ app_dir }}"
        state: directory
        owner: www-data
        group: www-data
        mode: '0755'

    - name: Copy application files
      copy:
        src: "{{ item }}"
        dest: "{{ app_dir }}/"
        owner: www-data
        group: www-data
      loop:
        - app.py
        - requirements.txt
      notify: Restart application

    - name: Install Python dependencies
      pip:
        requirements: "{{ app_dir }}/requirements.txt"
        virtualenv: "{{ app_dir }}/venv"

    - name: Configure systemd service
      template:
        src: templates/app.service.j2
        dest: /etc/systemd/system/{{ app_name }}.service
      notify: Restart application

    - name: Enable application service
      systemd:
        name: "{{ app_name }}"
        enabled: yes
        state: started
        daemon_reload: yes

  handlers:
    - name: Restart application
      systemd:
        name: "{{ app_name }}"
        state: restarted
```

## Roles

### Creating a Custom Role

```bash
# Create role structure
ansible-galaxy role init roles/nginx

# Role structure
roles/nginx/
├── defaults/          # Default variables
│   └── main.yml
├── files/            # Static files
├── handlers/         # Handlers
│   └── main.yml
├── meta/             # Role metadata
│   └── main.yml
├── tasks/            # Tasks
│   └── main.yml
├── templates/        # Jinja2 templates
├── tests/            # Test playbooks
└── vars/             # Role variables
    └── main.yml
```

### Example Role (roles/nginx/tasks/main.yml)

```yaml
---
- name: Install Nginx
  apt:
    name: nginx
    state: present
    update_cache: yes

- name: Configure Nginx
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Reload Nginx

- name: Ensure Nginx is running
  service:
    name: nginx
    state: started
    enabled: yes

- name: Configure firewall for Nginx
  ufw:
    rule: allow
    port: "{{ item }}"
    proto: tcp
  loop:
    - 80
    - 443
```

## Variables

### Group Variables (group_vars/web_servers.yml)

```yaml
---
nginx_worker_processes: 4
nginx_worker_connections: 1024

ssl_certificate: /etc/ssl/certs/homelab.crt
ssl_certificate_key: /etc/ssl/private/homelab.key

monitoring_enabled: true
backup_enabled: true
```

### Host Variables (host_vars/web-01.yml)

```yaml
---
server_role: primary
backup_priority: high

custom_config:
  max_connections: 100
  cache_size: 512M
```

## Usage

### Running Playbooks

```bash
# Run playbook
ansible-playbook playbooks/setup-server.yml

# Limit to specific hosts
ansible-playbook playbooks/setup-server.yml --limit web_servers

# Dry run (check mode)
ansible-playbook playbooks/setup-server.yml --check

# With tags
ansible-playbook playbooks/deploy-app.yml --tags "configuration"

# Skip tags
ansible-playbook playbooks/deploy-app.yml --skip-tags "database"

# Extra variables
ansible-playbook playbooks/deploy-app.yml -e "app_version=2.0.0"
```

### Ad-hoc Commands

```bash
# Ping all hosts
ansible all -m ping

# Check disk space
ansible web_servers -m shell -a "df -h"

# Update packages
ansible all -m apt -a "update_cache=yes upgrade=dist" -b

# Restart service
ansible web_servers -m service -a "name=nginx state=restarted" -b

# Copy file
ansible all -m copy -a "src=/tmp/file dest=/tmp/file" -b
```

## Best Practices

1. **Idempotency**: Ensure playbooks can run multiple times
2. **Variables**: Use variables for configurable values
3. **Roles**: Create reusable roles
4. **Handlers**: Use handlers for service restarts
5. **Tags**: Tag tasks for selective execution
6. **Vault**: Encrypt sensitive data
7. **Testing**: Test in lab before production

## Ansible Vault

### Encrypting Secrets

```bash
# Create encrypted file
ansible-vault create group_vars/all/vault.yml

# Edit encrypted file
ansible-vault edit group_vars/all/vault.yml

# Encrypt existing file
ansible-vault encrypt secrets.yml

# Run playbook with vault
ansible-playbook playbook.yml --ask-vault-pass

# Use vault password file
ansible-playbook playbook.yml --vault-password-file ~/.vault_pass
```

### Vault File Example

```yaml
---
vault_db_password: "super_secret_password"
vault_api_key: "api_key_here"
```

## Testing

### Syntax Check

```bash
ansible-playbook playbooks/setup-server.yml --syntax-check
```

### Linting

```bash
# Install ansible-lint
pip install ansible-lint

# Lint playbooks
ansible-lint playbooks/
```

### Molecule Testing

```bash
# Install molecule
pip install molecule molecule-docker

# Test role
cd roles/nginx
molecule test
```

## Integration with Terraform

After Terraform provisions VMs:

```bash
# Update inventory from Terraform
cd ../../terraform/compute
terraform output -json > /tmp/terraform-vms.json

# Run Ansible configuration
cd ../../ansible
ansible-playbook playbooks/configure-new-vms.yml
```

## Troubleshooting

### Increase Verbosity

```bash
ansible-playbook playbook.yml -v    # verbose
ansible-playbook playbook.yml -vv   # more verbose
ansible-playbook playbook.yml -vvv  # very verbose
ansible-playbook playbook.yml -vvvv # debug
```

### Common Issues

**SSH Connection Failed**
```bash
# Test SSH connectivity
ansible all -m ping -vvv

# Check inventory
ansible-inventory --list
```

**Permission Denied**
```bash
# Use become
ansible-playbook playbook.yml --become --ask-become-pass
```

## Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Galaxy](https://galaxy.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

## Related Documentation

- **[Main Documentation](../docs/README.md)** - Complete homelab documentation
- **[Terraform Deployments](../terraform/deployments/README.md)** - Infrastructure deployments
- **[Cloud-init Configs](../scripts/deployment/cloud-init/README.md)** - VM provisioning
- **[Scripts](../scripts/README.md)** - Utility scripts and automation

## Future Enhancements

- Implement Ansible Tower/AWX
- Add CI/CD for playbook testing
- Create custom modules
- Enhance error handling
- Add more comprehensive testing
- Integration with cloud-init workflows
- Expand role library
