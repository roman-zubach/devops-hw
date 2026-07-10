#!/usr/bin/env bash
# Installs Docker, Docker Compose, Python 3.9+ and Django on Ubuntu/Debian.

set -euo pipefail

PYTHON_VERSION="3.9"
PYTHON_BIN="python${PYTHON_VERSION}"

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

install_docker() {
    if command_exists docker && docker --version >/dev/null 2>&1; then
        echo "Docker is already installed: $(docker --version)"
        return
    fi

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

    local architecture codename
    architecture="$(dpkg --print-architecture)"
    codename="${VERSION_CODENAME:-}"

    if [[ -z "$codename" ]]; then
        echo "Error: cannot determine the distribution codename." >&2
        exit 1
    fi

    echo \
        "deb [arch=${architecture} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRIBUTION} ${codename} stable" |
        $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin

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
}

install_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        echo "Docker Compose is already installed: $(docker compose version)"
        return
    fi

    echo "Installing Docker Compose..."

    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq docker-compose-plugin

    echo "Docker Compose installed: $(docker compose version)"
}

install_python() {
    if command_exists "$PYTHON_BIN"; then
        echo "Python is already installed: $("$PYTHON_BIN" --version)"
        return
    fi

    echo "Installing Python ${PYTHON_VERSION}..."

    $SUDO apt-get update -qq

    if ! apt-cache show "python${PYTHON_VERSION}" >/dev/null 2>&1; then
        if [[ "$DISTRIBUTION" == "ubuntu" ]]; then
            echo "python${PYTHON_VERSION} is not available in the default repositories, adding the deadsnakes PPA..."
            $SUDO apt-get install -y -qq software-properties-common
            $SUDO add-apt-repository -y ppa:deadsnakes/ppa
            $SUDO apt-get update -qq
        else
            echo "Error: python${PYTHON_VERSION} is not available in the default repositories for ${DISTRIBUTION} ${VERSION_CODENAME:-}." >&2
            echo "Install it manually (e.g. from backports) and re-run the script." >&2
            exit 1
        fi
    fi

    $SUDO apt-get install -y -qq \
        "python${PYTHON_VERSION}" \
        "python${PYTHON_VERSION}-venv" \
        "python${PYTHON_VERSION}-dev"

    if ! command_exists "$PYTHON_BIN"; then
        echo "Error: failed to install ${PYTHON_BIN}." >&2
        exit 1
    fi

    echo "Python installed: $("$PYTHON_BIN" --version)"
}

install_django() {
    local django_venv="${HOME}/.django-venv"
    DJANGO_PYTHON="${django_venv}/bin/python"
    DJANGO_ADMIN="${django_venv}/bin/django-admin"

    if [[ -x "$DJANGO_PYTHON" ]] &&
        "$DJANGO_PYTHON" -m django --version >/dev/null 2>&1; then
        echo "Django is already installed: $("$DJANGO_PYTHON" -m django --version)"
        return
    fi

    echo "Installing Django through pip..."

    "$PYTHON_BIN" -m venv "$django_venv"
    "$DJANGO_PYTHON" -m pip install --upgrade pip
    "$DJANGO_PYTHON" -m pip install django

    echo "Django installed: $("$DJANGO_PYTHON" -m django --version)"
}

install_docker
install_docker_compose
install_python
install_django

echo ""
echo "All tools are ready:"
echo "  Docker:         $(docker --version)"
echo "  Docker Compose: $(docker compose version)"
echo "  Python:         $("$PYTHON_BIN" --version)"
echo "  pip:            $("$DJANGO_PYTHON" -m pip --version)"
echo "  Django:         $("$DJANGO_PYTHON" -m django --version)"
echo ""
echo "Django executable:"
echo "  ${DJANGO_ADMIN}"
