# Homelab Ansible Monorepo

This repository centralizes playbooks, roles, inventories, and collections for a single production homelab environment.

## Structure

- inventories/production: production inventory, group vars, and host vars
- playbooks: entry-point playbooks
- roles: reusable role definitions
- collections: Ansible collections and requirements

## Quick start

1) Edit the inventory in inventories/production/hosts.yml
2) Add variables in inventories/production/group_vars/all.yml
3) Run the main playbook:

ansible-playbook playbooks/site.yml

## Notes for Semaphore UI

- Set the working directory to the ansible/ folder
- Use playbooks/site.yml as the playbook path
- Inventory defaults to inventories/production/hosts.yml via ansible.cfg


## Working and WIP

### Working
 - bootstrap
 - test (for testing stuff, may change but in general will never actually DO anything)
 - configure-vault
 - garage-s3-setup
 - loki and associated role
 - mimir and role

### WIP
 - alloy
