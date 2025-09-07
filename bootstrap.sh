#!/bin/bash
#
# bootstrap.sh - One-time setup for GitHub Actions Runner on Raspberry Pi 5
# Author: <your-handle>
# Version: 0.1.0
# Date: 2025-09-06
#
# What this does:
#   - Creates secure storage for your GitHub token (root-only)
#   - Prepares /opt/edge/app-runner and puts the ARM64 runner there
#   - Verifies the runner binary is for aarch64
#   - Installs & starts the systemd service (AFTER you configure the runner)
#
# Run it ONCE on a fresh Pi. On reboots, systemd will auto-start the runner.
#
# IMPORTANT:
#   - This script expects you to run ./config.sh manually (or previously)
#     to register the runner with GitHub. We detect that via the ".runner"
#     file and will refuse to install the service until configured.
#
# Usage:
#   chmod +x bootstrap.sh
#   ./bootstrap.sh
#
# Notes:
#   - Do NOT hardcode secrets in this file.
#   - Requires tools: curl, jq, tar, file
#   - Architecture must be aarch64 (Pi OS 64-bit)

set -euo pipefail

# ------------ SETTINGS (change if you like) ------------
PAT_PATH="/opt/edge/github/pat"
RUNNER_ROOT="/opt/edge/app-runner"
# If you want to pin a version, set RUNNER_VERSION (e.g., "2.317.0").
# Leave empty to fetch the latest at runtime.
RUNNER_VERSION="${RUNNER_VERSION:-}"
# -------------------------------------------------------

info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required tool: $1"
    exit 1
  fi
}

# 0) PRECHECKS
info "Running prechecks…"

# Arch check
ARCH="$(uname -m)"
if [[ "$ARCH" != "aarch64" ]]; then
  error "This script requires ARM64 (aarch64). Detected: $ARCH"
  exit 1
fi

# Tools check
for cmd in curl jq tar file; do
  require_cmd "$cmd"
done

# Network sanity (GitHub API ping)
if ! curl -fsSL --connect-timeout 5 https://api.github.com/ >/dev/null; then
  error "Network/GitHub API not reachable. Check internet/time (NTP) and try again."
  exit 1
fi

# 1) TOKEN HANDLING (root-only file at /opt/edge/github/pat)
info "Setting up secure token storage at $PAT_PATH…"
sudo mkdir -p "$(dirname "$PAT_PATH")"

if [[ ! -f "$PAT_PATH" ]]; then
  # Prompt silently; nothing echoed on screen
  read -s -p "GitHub PAT (or token) for registering the runner/repo: " PAT; echo
  # Store token in a root-owned file with 600 perms
  echo -n "$PAT" | sudo tee "$PAT_PATH" >/dev/null
  sudo chmod 600 "$PAT_PATH"
  sudo chown root:root "$PAT_PATH"
  unset PAT
  info "Token saved securely to $PAT_PATH (root:root, 600)."
else
  warn "Token file already exists at $PAT_PATH. Skipping prompt."
fi

# 2) RUNNER DIRECTORY
info "Preparing runner directory at $RUNNER_ROOT…"
sudo mkdir -p "$RUNNER_ROOT"
# Make the working directory owned by the current user so we can extract files there
sudo chown -R "$USER:$USER" "$RUNNER_ROOT"
cd "$RUNNER_ROOT"

# 3) DOWNLOAD ARM64 RUNNER (latest or pinned)
if [[ -z "$RUNNER_VERSION" ]]; then
  info "Fetching latest runner version from GitHub…"
  RUNNER_VERSION="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest \
                    | jq -r .tag_name | sed 's/^v//')"
fi
info "Target runner version: $RUNNER_VERSION"

TARBALL="actions-runner-linux-arm64-${RUNNER_VERSION}.tar.gz"
URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${TARBALL}"

if [[ ! -f "bin/Runner.Listener" ]]; then
  info "Downloading runner tarball…"
  curl -fsSL -o "$TARBALL" "$URL"
  info "Extracting runner…"
  tar xzf "$TARBALL"
else
  warn "Runner files already present (bin/Runner.Listener exists). Skipping download/extract."
fi

# 4) SANITY CHECK (binary should be aarch64)
if file bin/Runner.Listener | grep -qi "ARM aarch64"; then
  info "Binary check OK: Runner.Listener is ARM aarch64."
else
  error "Runner.Listener does not look like ARM aarch64. Aborting."
  exit 1
fi

# 5) SERVICE INSTALL & START
# IMPORTANT: The runner MUST be configured first (./config.sh), which creates a ".runner" file.
# We intentionally *stop here* if not configured, so you can run:
#   ./config.sh --url https://github.com/<owner>/<repo> --token <registration_token> [other flags]
if [[ ! -f ".runner" ]]; then
  warn "Runner is not configured yet (.runner file missing)."
  echo "Next step:"
  echo "  1) Obtain a registration token from GitHub (Repo or Org > Settings > Actions > Runners > New runner)."
  echo "  2) Run the config interactively:"
  echo "       ./config.sh --url https://github.com/<owner>/<repo> --token <registration_token>"
  echo "  3) Re-run this script (or run the two lines below) to install/start the service:"
  echo "       sudo ./svc.sh install"
  echo "       sudo ./svc.sh start"
  exit 0
fi

# If configured, install and start service (idempotent: install will fail if it already exists)
info "Installing and starting the runner systemd service…"
if ! sudo ./svc.sh install; then
  warn "Service may already exist; attempting to start it."
fi

# Start (safe to run if already started)
if sudo ./svc.sh start; then
  info "Runner service started."
else
  warn "Failed to start via svc.sh; showing systemd status for clues…"
  SYSTEMD_UNIT="$(systemctl list-units --type=service | awk '/actions\.runner/{print $1; exit}')"
  if [[ -n "${SYSTEMD_UNIT:-}" ]]; then
    systemctl status "$SYSTEMD_UNIT" || true
  else
    warn "No actions.runner.* service found. You may need to uninstall and reconfigure."
  fi
fi

info "Done. The runner service will now auto-start on every reboot."
