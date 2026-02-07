#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing Python tooling..."
pip install --no-cache-dir \
  ansible-core \
  ansible-lint \
  yamllint \
  pre-commit \
  jmespath

echo "==> Installing Ansible collections..."
ansible-galaxy collection install -r ansible/collections/requirements.yml --force

echo "==> Installing mimirtool..."
MIMIR_VERSION=$(curl -s https://api.github.com/repos/grafana/mimir/releases/latest | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'].replace('mimir-',''))")
curl -fSL -o /usr/local/bin/mimirtool \
  "https://github.com/grafana/mimir/releases/latest/download/mimirtool-linux-amd64"
chmod +x /usr/local/bin/mimirtool
echo "    mimirtool version: $(mimirtool version 2>/dev/null || echo 'installed')"

echo "==> Setting up pre-commit hooks..."
pre-commit install

echo "==> Dev container setup complete!"
