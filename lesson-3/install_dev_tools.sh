#!/usr/bin/env bash
# Installs Docker, Docker Compose, Python 3.9+ and Django on Ubuntu/Debian.

set -euo pipefail

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if [[ "$(id -u)" -eq 0 ]]; then
    SUDO=""
else
    if ! command_exists sudo; then
        echo "Error: sudo is required when the script is not run as root." >&2
        exit 1
    fi

    SUDO="sudo"
fi

if [[ ! -f /etc/os-release ]]; then
    echo "Error: cannot determine the operating system." >&2
    exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

case "${ID:-}" in
    ubuntu|debian)
        DISTRIBUTION="$ID"
        ;;
    *)
        echo "Error: this script supports Ubuntu and Debian only." >&2
        exit 1
        ;;
esac

# Docker and Docker Compose
if command_exists docker && docker --version >/dev/null 2>&1; then
    echo "Docker is already installed: $(docker --version)"
else
    echo "Installing Docker..."

    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq \
        ca-certificates \
        curl \
        gnupg

    $SUDO install -m 0755 -d /etc/apt/keyrings

    curl -fsSL "https://download.docker.com/linux/${DISTRIBUTION}/gpg" |
        $SUDO gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg

    $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

    ARCHITECTURE="$(dpkg --print-architecture)"
    CODENAME="${VERSION_CODENAME:-}"

    if [[ -z "$CODENAME" ]]; then
        echo "Error: cannot determine the distribution codename." >&2
        exit 1
    fi

    echo \
        "deb [arch=${ARCHITECTURE} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRIBUTION} ${CODENAME} stable" |
        $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    if command_exists systemctl && [[ "$(ps -p 1 -o comm=)" == "systemd" ]]; then
        $SUDO systemctl enable --now docker
    else
        echo "systemd is not running. Docker service was not started automatically."
    fi

    if [[ "$(id -u)" -ne 0 ]] && ! id -nG "$USER" | grep -qw docker; then
        $SUDO usermod -aG docker "$USER"
        echo "User '$USER' was added to the docker group."
        echo "Log out and log in again to apply the group membership."
    fi

    echo "Docker installed: $(docker --version)"
fi

if docker compose version >/dev/null 2>&1; then
    echo "Docker Compose is already installed: $(docker compose version)"
else
    echo "Installing Docker Compose..."

    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq docker-compose-plugin

    echo "Docker Compose installed: $(docker compose version)"
fi

# Python 3.9+
if command_exists python3 &&
    python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 9))'; then
    echo "Python is already installed: $(python3 --version)"
else
    echo "Installing Python 3..."

    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq \
        python3 \
        python3-pip \
        python3-venv

    if ! python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 9))'; then
        echo "Error: the installed Python version is older than 3.9." >&2
        exit 1
    fi

    echo "Python installed: $(python3 --version)"
fi

# pip and venv may be missing even when Python is already installed.
if ! python3 -m pip --version >/dev/null 2>&1; then
    echo "Installing pip..."
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq python3-pip
fi

if ! python3 -m venv --help >/dev/null 2>&1 || ! python3 -c 'import ensurepip' >/dev/null 2>&1; then
    echo "Installing Python venv support..."
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq python3-venv
fi

# Django
DJANGO_VENV="${HOME}/.django-venv"
DJANGO_PYTHON="${DJANGO_VENV}/bin/python"
DJANGO_ADMIN="${DJANGO_VENV}/bin/django-admin"

if [[ -x "$DJANGO_PYTHON" ]] &&
    "$DJANGO_PYTHON" -m django --version >/dev/null 2>&1; then
    echo "Django is already installed: $("$DJANGO_PYTHON" -m django --version)"
else
    echo "Installing Django through pip..."

    python3 -m venv "$DJANGO_VENV"
    "$DJANGO_PYTHON" -m pip install --upgrade pip
    "$DJANGO_PYTHON" -m pip install django

    echo "Django installed: $("$DJANGO_PYTHON" -m django --version)"
fi

echo ""
echo "All tools are ready:"
echo "  Docker:         $(docker --version)"
echo "  Docker Compose: $(docker compose version)"
echo "  Python:         $(python3 --version)"
echo "  pip:            $(python3 -m pip --version)"
echo "  Django:         $("$DJANGO_PYTHON" -m django --version)"
echo ""
echo "Django executable:"
echo "  ${DJANGO_ADMIN}"
