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
# Try normal install first; if it fails (e.g. pre-release requirement), retry with --pre
if ansible-galaxy collection install -r ansible/collections/requirements.yml --force; then
  echo "Ansible collections installed successfully"
else
  echo "Standard collection install failed; retrying with --pre (may be required for some collections)"
  if ansible-galaxy collection install -r ansible/collections/requirements.yml --force --pre; then
    echo "Ansible collections installed successfully (with --pre)"
  else
    echo "Warning: failed to install some collections. Continuing but you may need to install them manually."
  fi
fi

echo "==> Installing mimirtool..."
MIMIR_VERSION=$(curl -s https://api.github.com/repos/grafana/mimir/releases/latest | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'].replace('mimir-',''))")
# Download to a temporary file then move with sudo so install works when postCreate runs as non-root
TMPFILE=$(mktemp)
curl -fSL -o "$TMPFILE" \
  "https://github.com/grafana/mimir/releases/latest/download/mimirtool-linux-amd64"
sudo mv "$TMPFILE" /usr/local/bin/mimirtool
sudo chmod +x /usr/local/bin/mimirtool
echo "    mimirtool version: $(mimirtool version 2>/dev/null || echo 'installed')"

echo "==> Installing lokitool..."
TMPFILE=$(mktemp -d)
curl -fSL -o "$TMPFILE/lokitool.zip" \
  "https://github.com/grafana/loki/releases/latest/download/lokitool-linux-amd64.zip"
unzip -o "$TMPFILE/lokitool.zip" -d "$TMPFILE"
sudo mv "$TMPFILE/lokitool-linux-amd64" /usr/local/bin/lokitool
sudo chmod +x /usr/local/bin/lokitool
rm -rf "$TMPFILE"
echo "    lokitool version: $(lokitool version 2>/dev/null || echo 'installed')"

echo "==> Setting up pre-commit hooks..."
pre-commit install

echo "==> Dev container setup complete!"
