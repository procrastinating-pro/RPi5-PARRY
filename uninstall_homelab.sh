#!/bin/bash
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${RED}======================================================${NC}"
echo -e "${RED}       DEINSTALATOR DOCKER HOMELAB & NAS (RPi 5)      ${NC}"
echo -e "${RED}======================================================${NC}"

ACTUAL_USER=${SUDO_USER:-$USER}
DEFAULT_DOCKER_DIR="/home/$ACTUAL_USER/docker/homelab"
DEFAULT_NAS_DIR="/srv/nas/pliki"

read -p "1. Katalog konfiguracji Dockera [$DEFAULT_DOCKER_DIR]: " DOCKER_DIR
DOCKER_DIR=${DOCKER_DIR:-$DEFAULT_DOCKER_DIR}

read -p "2. Katalog danych na dysku NAS [$DEFAULT_NAS_DIR]: " NAS_DIR
NAS_DIR=${NAS_DIR:-$DEFAULT_NAS_DIR}

echo -e "\n${YELLOW}[!] UWAGA: Ta operacja zatrzyma i usunie wszystkie kontenery HomeLab,"
echo -e "    dedykowaną sieć bridge, nieużywane obrazy, reguły sysctl/cron oraz konfigurację!${NC}"
read -p "    Wpisz 'TAK' wielkimi literami, aby potwierdzić: " CONFIRM_APP

if [ "$CONFIRM_APP" != "TAK" ]; then
    echo -e "${GREEN}[*] Anulowano. Żadne zmiany nie zostały wprowadzone.${NC}"
    exit 0
fi

# ================= 1. WYLOGOWANIE TAILSCALE I ZATRZYMANIE KONTENERÓW =================
echo -e "\n${YELLOW}[1/6] Zatrzymywanie i usuwanie kontenerów Docker...${NC}"
if docker ps -q -f name="^tailscale$" | grep -q .; then
    echo -e "${YELLOW}   -> Wylogowywanie węzła Tailscale z panelu (tailscale logout)...${NC}"
    sudo docker exec tailscale tailscale logout >/dev/null 2>&1 || true
fi

if [ -f "$DOCKER_DIR/docker-compose.yml" ]; then
    cd "$DOCKER_DIR"
    sudo docker compose down -v --remove-orphans || true
fi

# Awaryjne usunięcie po nazwach kontenerów, gdyby plik compose został wcześniej skasowany
for cname in pihole samba-nas tailscale vaultwarden gitea gitea-db caddy watchtower filebrowser-nas; do
    if docker ps -a -q -f name="^${cname}$" | grep -q .; then
        sudo docker rm -f "$cname" >/dev/null 2>&1 || true
    fi
done

sudo docker network rm homelab-net >/dev/null 2>&1 || true

# ================= 2. CZYSZCZENIE CRON, SYSCTL I KONFIGURACJI =================
echo -e "${YELLOW}[2/6] Usuwanie zadań Cron, reguł sysctl oraz katalogu $DOCKER_DIR...${NC}"
sudo rm -f /etc/cron.d/pihole-gravity
sudo rm -f /etc/sysctl.d/99-tailscale.conf /etc/sysctl.d/99-twingate.conf
sudo sysctl --system >/dev/null 2>&1 || true

if [ -d "$DOCKER_DIR" ]; then
    sudo rm -rf "$DOCKER_DIR"
    echo -e "${GREEN}   [+] Usunięto katalog: $DOCKER_DIR${NC}"
fi

# ================= 3. CZYSZCZENIE NIEUŻYWANYCH OBRAZÓW I WOLUMENÓW =================
echo -e "${YELLOW}[3/6] Czyszczenie nieużywanych obrazów i sieci Docker...${NC}"
sudo docker system prune -a -f --volumes >/dev/null 2>&1 || true

# ================= 4. OPCJONALNE WYŁĄCZENIE DOCKER USERNS-REMAP =================
echo -e "${YELLOW}[4/6] Sprawdzanie izolacji Docker userns-remap...${NC}"
if grep -q '"userns-remap"' /etc/docker/daemon.json 2>/dev/null; then
    read -p "   -> Wykryto aktywne 'userns-remap' w /etc/docker/daemon.json. Wyłączyć je? [t/N]: " DISABLE_USERNS
    DISABLE_USERNS=${DISABLE_USERNS:-N}
    if [[ "$DISABLE_USERNS" =~ ^[TtYy]$ ]]; then
        sudo python3 - <<'PYEOF'
import json
path = "/etc/docker/daemon.json"
try:
    with open(path, "r") as f:
        data = json.load(f)
    data.pop("userns-remap", None)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
except Exception:
    pass
PYEOF
        sudo systemctl restart docker
        echo -e "${GREEN}   [+] Wyłączono userns-remap i zrestartowano demona Docker.${NC}"
    else
        echo -e "${CYAN}   [*] Pozostawiono userns-remap w /etc/docker/daemon.json.${NC}"
    fi
fi

# ================= 5. PRZYWRÓCENIE SYSTEMD-RESOLVED (PORT 53) =================
echo -e "${YELLOW}[5/6] Przywracanie domyślnej obsługi DNS (systemd-resolved)...${NC}"
if [ -f /etc/systemd/resolved.conf ]; then
    sudo sed -i 's/DNSStubListener=no/#DNSStubListener=yes/g' /etc/systemd/resolved.conf
    if [ -f /run/systemd/resolve/stub-resolv.conf ]; then
        sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    fi
    sudo systemctl restart systemd-resolved || true
    echo -e "${GREEN}   [+] Przywrócono systemd-resolved.${NC}"
fi

# ================= 6. OCHRONA DANYCH NAS (PODWÓJNE POTWIERDZENIE) =================
echo -e "\n${YELLOW}[6/6] Ochrona danych na dysku NAS ($NAS_DIR):${NC}"
if [ -d "$NAS_DIR" ]; then
    echo -e "${RED}[!] Katalog $NAS_DIR z Twoimi plikami jest domyślnie ZACHOWYWANY.${NC}"
    read -p "    Czy chcesz BEZPOWROTNIE usunąć wszystkie pliki z $NAS_DIR? (wpisz 'USUN_DANE' lub wciśnij Enter, aby zachować): " CONFIRM_NAS
    if [ "$CONFIRM_NAS" == "USUN_DANE" ]; then
        sudo rm -rf "$NAS_DIR"
        echo -e "${RED}   [!] Bezpowrotnie usunięto katalog: $NAS_DIR${NC}"
    else
        echo -e "${GREEN}   [+] Zachowano Twoje pliki w: $NAS_DIR${NC}"
    fi
else
    echo -e "${CYAN}   [*] Katalog $NAS_DIR nie istnieje (pominięto).${NC}"
fi

echo -e "\n${CYAN}======================================================${NC}"
echo -e "${GREEN}[SUKCES] Środowisko HomeLab zostało wyczyszczone!${NC}"
echo -e "${CYAN}======================================================${NC}"
