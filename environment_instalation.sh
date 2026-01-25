#!/usr/bin/env bash
set -euo pipefail

INSTALL_POSTGRES=${INSTALL_POSTGRES:-1}
INSTALL_NODE=${INSTALL_NODE:-1}
INSTALL_FLUTTER=${INSTALL_FLUTTER:-1}
INSTALL_APACHE=${INSTALL_APACHE:-0}

sudo apt-get update -y
sudo apt-get install -y \
  ca-certificates \
  curl \
  git \
  gnupg \
  lsb-release \
  software-properties-common \
  unzip \
  xz-utils \
  zip

if [[ "$INSTALL_POSTGRES" == "1" ]]; then
  sudo apt-get install -y postgresql postgresql-contrib
  sudo systemctl enable --now postgresql
fi

if [[ "$INSTALL_NODE" == "1" ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

if [[ "$INSTALL_FLUTTER" == "1" ]]; then
  sudo apt-get install -y libglu1-mesa
  if ! command -v snap >/dev/null 2>&1; then
    sudo apt-get install -y snapd
  fi
  sudo snap install flutter --classic
  export PATH="/snap/bin:$PATH"
  flutter config --enable-web || true
fi

if [[ "$INSTALL_APACHE" == "1" ]]; then
  sudo apt-get install -y apache2
  sudo systemctl enable --now apache2
fi

echo "Tooling installation complete."
