#!/bin/bash
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}     KONFIGURATOR DOCKER HOMELAB (RPi 5 - PURE BASH)${NC}"
echo -e "${CYAN}======================================================${NC}"

ACTUAL_USER=${SUDO_USER:-$USER}
USER_UID=$(id -u "$ACTUAL_USER")
USER_GID=$(id -g "$ACTUAL_USER")
DEFAULT_IP=$(hostname -I | awk '{print $1}')
DEFAULT_IP=${DEFAULT_IP:-192.168.1.250}

# Dedykowana podsieć Docker bridge (stałe IP ułatwiają routing DNS przez Tailscale)
DOCKER_NET_NAME="homelab-net"
DOCKER_SUBNET="172.28.0.0/24"
PIHOLE_DOCKER_IP="172.28.0.10"
CADDY_DOCKER_IP="172.28.0.20"
TS_DOCKER_IP="172.28.0.30"

# ================= 1. WSPÓLNE ŚCIEŻKI I SIEĆ =================
echo -e "\n${YELLOW}[*] KROK 1: Konfiguracja sieci i katalogów głównych:${NC}"
read -p "1. Adres IP Twojego Raspberry Pi [$DEFAULT_IP]: " RPI_IP
RPI_IP=${RPI_IP:-$DEFAULT_IP}

read -p "2. Katalog główny dla plików NAS [/srv/nas/pliki]: " NAS_DIR
NAS_DIR=${NAS_DIR:-/srv/nas/pliki}

read -p "3. Katalog konfiguracji Dockera [/home/$ACTUAL_USER/docker/homelab]: " DOCKER_DIR
DOCKER_DIR=${DOCKER_DIR:-/home/$ACTUAL_USER/docker/homelab}

# ================= 2. WYBÓR KONTENERÓW (T/N) =================
echo -e "\n${YELLOW}[*] KROK 2: Wybierz kontenery i zabezpieczenia (T/n):${NC}"
read -p "   -> [1/6] Pi-hole (Blokada reklam + Lokalny DNS)? [T/n]: " OPT_PIHOLE
OPT_PIHOLE=${OPT_PIHOLE:-T}

read -p "   -> [2/6] Samba NAS (Udział sieciowy SMB Windows/Linux)? [T/n]: " OPT_SAMBA
OPT_SAMBA=${OPT_SAMBA:-T}

read -p "   -> [3/6] Tailscale (VPN Subnet Router w trybie bridge + Pi-hole na LTE/5G)? [t/N]: " OPT_TS
OPT_TS=${OPT_TS:-N}

read -p "   -> [4/6] Vaultwarden (Lokalny menedżer haseł Bitwarden)? [t/N]: " OPT_VW
OPT_VW=${OPT_VW:-N}

read -p "   -> [5/6] Gitea + PostgreSQL (Lokalny serwer Git)? [t/N]: " OPT_GITEA
OPT_GITEA=${OPT_GITEA:-N}

read -p "   -> [6/6] Caddy Reverse Proxy (Lokalny HTTPS .home + zamknięcie portów webowych na LAN)? [T/n]: " OPT_CADDY
OPT_CADDY=${OPT_CADDY:-T}

read -p "   -> [Extra] Watchtower (Auto-update kontenerów o 04:00)? [T/n]: " OPT_WT
OPT_WT=${OPT_WT:-T}

read -p "   -> [Security] Docker userns-remap (Izolacja przestrzeni nazw UID/GID kontenerów)? [T/n]: " OPT_USERNS
OPT_USERNS=${OPT_USERNS:-T}

# ================= 3. SZCZEGÓŁOWE PYTANIA TYLKO DLA WYBRANYCH =================

if [[ "$OPT_PIHOLE" =~ ^[TtYy]$ ]]; then
    echo -e "\n${YELLOW}[*] Konfiguracja Pi-hole:${NC}"
    if [[ ! "$OPT_CADDY" =~ ^[TtYy]$ ]]; then
        read -p "   -> Port panelu WWW Pi-hole [8080]: " PIHOLE_PORT
        PIHOLE_PORT=${PIHOLE_PORT:-8080}
    else
        echo -e "   ${CYAN}(Panel WWW będzie dostępny wyłącznie przez Caddy: https://pihole.home/admin — port LAN zamknięty)${NC}"
    fi
    while true; do
        read -s -p "   -> Hasło do panelu WWW Pi-hole: " PIHOLE_PASS
        echo ""
        if [ -n "$PIHOLE_PASS" ]; then break; else echo -e "${RED}      Hasło nie może być puste!${NC}"; fi
    done
    read -p "   -> Lokalne domeny DNS [pihole.home rpi.home vault.home git.home]: " LOCAL_DOMAINS
    LOCAL_DOMAINS=${LOCAL_DOMAINS:-"pihole.home rpi.home vault.home git.home"}
fi

if [[ "$OPT_SAMBA" =~ ^[TtYy]$ ]]; then
    echo -e "\n${YELLOW}[*] Konfiguracja Samba NAS:${NC}"
    read -p "   -> Nazwa udziału sieciowego w LAN [DyskNAS]: " SHARE_NAME
    SHARE_NAME=${SHARE_NAME:-DyskNAS}
    read -p "   -> Login do dysku sieciowego Samba [$ACTUAL_USER]: " SAMBA_USER
    SAMBA_USER=${SAMBA_USER:-$ACTUAL_USER}
    while true; do
        read -s -p "   -> Hasło do dysku sieciowego Samba: " SAMBA_PASS
        echo ""
        if [ -n "$SAMBA_PASS" ]; then break; else echo -e "${RED}      Hasło nie może być puste!${NC}"; fi
    done
fi

if [[ "$OPT_TS" =~ ^[TtYy]$ ]]; then
    echo -e "\n${YELLOW}[*] Konfiguracja Tailscale (VPN Subnet Router w sieci bridge):${NC}"
    echo -e "   ${CYAN}(Auth Key wygenerujesz w https://login.tailscale.com/admin/settings/keys -> Generate auth key)${NC}"
    while true; do
        read -p "   -> Wklej TS_AUTHKEY (zaczyna się od tskey-auth-...): " TS_AUTHKEY
        if [ -n "$TS_AUTHKEY" ]; then break; else echo -e "${RED}      Auth Key nie może być pusty!${NC}"; fi
    done
    DEFAULT_ROUTES="${RPI_IP%.*}.0/24,${DOCKER_SUBNET}"
    read -p "   -> Podsieci do rozgłaszania (LAN + Docker bridge) [$DEFAULT_ROUTES]: " TS_ROUTES
    TS_ROUTES=${TS_ROUTES:-$DEFAULT_ROUTES}
fi

if [[ "$OPT_VW" =~ ^[TtYy]$ ]]; then
    echo -e "\n${YELLOW}[*] Konfiguracja Vaultwarden (Bitwarden):${NC}"
    if [[ ! "$OPT_CADDY" =~ ^[TtYy]$ ]]; then
        read -p "   -> Port WWW dla Vaultwarden [8222]: " VW_PORT
        VW_PORT=${VW_PORT:-8222}
    else
        echo -e "   ${CYAN}(Vaultwarden będzie dostępny wyłącznie przez Caddy: https://vault.home — port LAN zamknięty)${NC}"
    fi
fi

if [[ "$OPT_GITEA" =~ ^[TtYy]$ ]]; then
    echo -e "\n${YELLOW}[*] Konfiguracja Gitea (Serwer Git + PostgreSQL):${NC}"
    if [[ ! "$OPT_CADDY" =~ ^[TtYy]$ ]]; then
        read -p "   -> Port WWW dla Gitea [3000]: " GITEA_PORT
        GITEA_PORT=${GITEA_PORT:-3000}
    else
        echo -e "   ${CYAN}(Panel WWW Gitei będzie dostępny wyłącznie przez Caddy: https://git.home — port LAN zamknięty)${NC}"
    fi
    read -p "   -> Port SSH dla Gitea [2222]: " GITEA_SSH_PORT
    GITEA_SSH_PORT=${GITEA_SSH_PORT:-2222}
fi

echo -e "\n${CYAN}======================================================${NC}"

# ================= 4. PRZYGOTOWANIE KATALOGÓW I USERNS-REMAP =================
echo -e "${YELLOW}[1/3] Przygotowanie katalogów oraz konfiguracji Dockera...${NC}"
sudo mkdir -p "$NAS_DIR"
sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "$(dirname "$NAS_DIR")"
sudo chmod -R 775 "$NAS_DIR"

mkdir -p "$DOCKER_DIR"

REMAP_UID=""
REMAP_GID=""
USERNS_HOST_LINE=""

if [[ "$OPT_USERNS" =~ ^[TtYy]$ ]]; then
    echo -e "${YELLOW}   -> Konfiguracja Docker userns-remap (izolacja UID/GID)...${NC}"
    if [ -f "$DOCKER_DIR/docker-compose.yml" ]; then
        (cd "$DOCKER_DIR" && sudo docker compose down >/dev/null 2>&1 || true)
    fi

    sudo mkdir -p /etc/docker
    [ -f /etc/docker/daemon.json ] && sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak

    sudo python3 - <<'PYEOF'
import json
path = "/etc/docker/daemon.json"
try:
    with open(path, "r") as f:
        data = json.load(f)
except Exception:
    data = {}
data["userns-remap"] = "default"
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF

    sudo systemctl restart docker
    sleep 2

    REMAP_UID=$(awk -F: '$1=="dockremap"{print $2; exit}' /etc/subuid)
    REMAP_GID=$(awk -F: '$1=="dockremap"{print $2; exit}' /etc/subgid)
    if [ -z "$REMAP_UID" ] || [ -z "$REMAP_GID" ]; then
        echo -e "${RED}[!] Nie znaleziono zakresu 'dockremap' w /etc/subuid. Sprawdź logi: sudo journalctl -u docker -n 30${NC}"
        exit 1
    fi
    USERNS_HOST_LINE='    userns_mode: "host"'
    echo -e "${GREEN}   [+] Aktywowano userns-remap (dockremap base UID:GID = ${REMAP_UID}:${REMAP_GID}).${NC}"
fi

cat > "$DOCKER_DIR/docker-compose.yml" <<EOF
services:
EOF

# ================= 5. GENEROWANIE USŁUG W DOCKER-COMPOSE =================
echo -e "${YELLOW}[2/3] Generowanie pliku docker-compose.yml dla wybranych usług...${NC}"

# --- PI-HOLE ---
if [[ "$OPT_PIHOLE" =~ ^[TtYy]$ ]]; then
    if sudo ss -tulnp | grep -q ":53 "; then
        if ! sudo ss -tulnp | grep ":53 " | grep -q "docker"; then
            if systemctl is-active --quiet systemd-resolved; then
                echo -e "${YELLOW}   -> Zwalnianie portu 53 (wyłączanie DNSStubListener w systemd-resolved)...${NC}"
                sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
                sudo sed -i 's/DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
                sudo rm -f /etc/resolv.conf
                echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
                sudo systemctl restart systemd-resolved
            fi
        fi
    fi

    sudo mkdir -p "$DOCKER_DIR/pihole/etc-pihole" "$DOCKER_DIR/pihole/etc-dnsmasq.d"
    sudo rm -f "$DOCKER_DIR/pihole/etc-pihole/custom.list"
    EXTRA_HOSTS_YAML=""
    FTL_HOSTS_LIST=""

    for dom in $LOCAL_DOMAINS; do
        echo "${RPI_IP} ${dom}" | sudo tee -a "$DOCKER_DIR/pihole/etc-pihole/custom.list" >/dev/null
        EXTRA_HOSTS_YAML="${EXTRA_HOSTS_YAML}      - \"${dom}:${RPI_IP}\"\n"
        if [ -z "$FTL_HOSTS_LIST" ]; then
            FTL_HOSTS_LIST="${RPI_IP} ${dom}"
        else
            FTL_HOSTS_LIST="${FTL_HOSTS_LIST};${RPI_IP} ${dom}"
        fi
    done

    if [[ "$OPT_USERNS" =~ ^[TtYy]$ ]]; then
        sudo chown -R "${REMAP_UID}:${REMAP_GID}" "$DOCKER_DIR/pihole"
    fi

    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    ports:
      - "53:53/tcp"
      - "53:53/udp"
EOF
    if [[ ! "$OPT_CADDY" =~ ^[TtYy]$ ]]; then
        cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF
      - "${PIHOLE_PORT}:80/tcp"
EOF
    fi
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF
    environment:
      TZ: 'Europe/Warsaw'
      WEBPASSWORD: '${PIHOLE_PASS}'
      FTLCONF_webserver_api_password: '${PIHOLE_PASS}'
      FTLCONF_LOCAL_IPV4: '${RPI_IP}'
      FTLCONF_dns_listeningMode: 'all'
      FTLCONF_dns_hosts: '${FTL_HOSTS_LIST}'
    extra_hosts:
$(echo -ne "$EXTRA_HOSTS_YAML")
    volumes:
      - './pihole/etc-pihole:/etc/pihole'
      - './pihole/etc-dnsmasq.d:/etc/dnsmasq.d'
    cap_add:
      - NET_ADMIN
    networks:
      ${DOCKER_NET_NAME}:
        ipv4_address: ${PIHOLE_DOCKER_IP}
    restart: unless-stopped
EOF

    # Automatyczna aktualizacja list Gravity codziennie o 03:30 (przed Watchtowerem o 04:00)
    echo "30 3 * * * root docker exec pihole pihole -g >/dev/null 2>&1" | sudo tee /etc/cron.d/pihole-gravity >/dev/null
    sudo chmod 644 /etc/cron.d/pihole-gravity
fi

# --- SAMBA ---
if [[ "$OPT_SAMBA" =~ ^[TtYy]$ ]]; then
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

  samba:
    container_name: samba-nas
    image: dperson/samba:latest
EOF
    [ -n "$USERNS_HOST_LINE" ] && echo "$USERNS_HOST_LINE" >> "$DOCKER_DIR/docker-compose.yml"
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF
    ports:
      - "139:139/tcp"
      - "445:445/tcp"
    environment:
      TZ: 'Europe/Warsaw'
      USERID: '${USER_UID}'
      GROUPID: '${USER_GID}'
    volumes:
      - '${NAS_DIR}:/mount:z'
    command: '-u "${SAMBA_USER};${SAMBA_PASS}" -s "${SHARE_NAME};/mount;yes;no;no;${SAMBA_USER}" -p'
    networks:
      - ${DOCKER_NET_NAME}
    restart: unless-stopped
EOF
fi

# --- TAILSCALE (TRYB BRIDGE + USERSPACE DLA JĄDER RPi OS Z NFTABLES) ---
if [[ "$OPT_TS" =~ ^[TtYy]$ ]]; then
    mkdir -p "$DOCKER_DIR/tailscale/state"
    # IP forwarding na hoście dla ruchu do sieci LAN przez bridge
    if [ -d /proc/sys/net/ipv6 ]; then
        printf "net.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1\n" | sudo tee /etc/sysctl.d/99-tailscale.conf >/dev/null
    else
        printf "net.ipv4.ip_forward = 1\n" | sudo tee /etc/sysctl.d/99-tailscale.conf >/dev/null
    fi
    sudo sysctl -p /etc/sysctl.d/99-tailscale.conf >/dev/null 2>&1 || true

    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

  tailscale:
    container_name: tailscale
    image: tailscale/tailscale:latest
    hostname: $(hostname)
EOF
    [ -n "$USERNS_HOST_LINE" ] && echo "$USERNS_HOST_LINE" >> "$DOCKER_DIR/docker-compose.yml"
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF
    environment:
      - TZ=Europe/Warsaw
      - TS_AUTHKEY=${TS_AUTHKEY}
      - TS_STATE_DIR=/var/lib/tailscale
      - TS_USERSPACE=true
      - TS_ROUTES=${TS_ROUTES}
      - TS_EXTRA_ARGS=--accept-dns=false
    volumes:
      - './tailscale/state:/var/lib/tailscale'
    cap_add:
      - NET_ADMIN
    networks:
      ${DOCKER_NET_NAME}:
        ipv4_address: ${TS_DOCKER_IP}
    restart: unless-stopped
EOF
fi

# --- VAULTWARDEN ---
if [[ "$OPT_VW" =~ ^[TtYy]$ ]]; then
    sudo mkdir -p "$DOCKER_DIR/vaultwarden"
    if [[ "$OPT_USERNS" =~ ^[TtYy]$ ]]; then
        sudo chown -R "${REMAP_UID}:${REMAP_GID}" "$DOCKER_DIR/vaultwarden"
    fi

    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

  vaultwarden:
    container_name: vaultwarden
    image: vaultwarden/server:latest
EOF
    if [[ ! "$OPT_CADDY" =~ ^[TtYy]$ ]]; then
        cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF
    ports:
      - "${VW_PORT}:80"
EOF
    fi
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF
    environment:
      - TZ=Europe/Warsaw
      - SIGNUPS_ALLOWED=true
      - WEBSOCKET_ENABLED=true
EOF
    if [[ "$OPT_CADDY" =~ ^[TtYy]$ ]]; then
        cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF
      - DOMAIN=https://vault.home
EOF
    fi
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF
    volumes:
      - './vaultwarden:/data'
    networks:
      - ${DOCKER_NET_NAME}
    restart: unless-stopped
EOF
fi

# --- GITEA + POSTGRESQL ---
if [[ "$OPT_GITEA" =~ ^[TtYy]$ ]]; then
    mkdir -p "$DOCKER_DIR/gitea"
    sudo mkdir -p "$DOCKER_DIR/gitea/data" "$DOCKER_DIR/gitea/postgres"

    GITEA_PASS_FILE="$DOCKER_DIR/gitea/.db_pass"
    if [ -f "$GITEA_PASS_FILE" ]; then
        GITEA_DB_PASS=$(cat "$GITEA_PASS_FILE")
    else
        if command -v openssl >/dev/null 2>&1; then
            GITEA_DB_PASS=$(openssl rand -hex 16)
        else
            GITEA_DB_PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
        fi
        echo "$GITEA_DB_PASS" > "$GITEA_PASS_FILE"
        chmod 600 "$GITEA_PASS_FILE"
    fi

    if [[ "$OPT_USERNS" =~ ^[TtYy]$ ]]; then
        sudo chown -R "${REMAP_UID}:${REMAP_GID}" "$DOCKER_DIR/gitea/data" "$DOCKER_DIR/gitea/postgres"
    else
        sudo chown -R "$USER_UID:$USER_GID" "$DOCKER_DIR/gitea/data"
    fi

    if [[ "$OPT_CADDY" =~ ^[TtYy]$ ]]; then
        GITEA_DOMAIN="git.home"
        GITEA_ROOT_URL="https://git.home/"
    else
        GITEA_DOMAIN="${RPI_IP}"
        GITEA_ROOT_URL="http://${RPI_IP}:${GITEA_PORT}/"
    fi

    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

  gitea-db:
    container_name: gitea-db
    image: postgres:16-alpine
    environment:
      - TZ=Europe/Warsaw
      - POSTGRES_USER=gitea
      - POSTGRES_PASSWORD=${GITEA_DB_PASS}
      - POSTGRES_DB=gitea
    volumes:
      - './gitea/postgres:/var/lib/postgresql/data'
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U gitea -d gitea"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - ${DOCKER_NET_NAME}
    restart: unless-stopped

  gitea:
    container_name: gitea
    image: gitea/gitea:latest
    depends_on:
      gitea-db:
        condition: service_healthy
    environment:
      - TZ=Europe/Warsaw
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=postgres
      - GITEA__database__HOST=gitea-db:5432
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD=${GITEA_DB_PASS}
      - GITEA__server__DOMAIN=${GITEA_DOMAIN}
      - GITEA__server__SSH_DOMAIN=${GITEA_DOMAIN}
      - GITEA__server__ROOT_URL=${GITEA_ROOT_URL}
      - GITEA__server__SSH_PORT=${GITEA_SSH_PORT}
    ports:
EOF
    if [[ ! "$OPT_CADDY" =~ ^[TtYy]$ ]]; then
        cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF
      - "${GITEA_PORT}:3000"
EOF
    fi
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF
      - "${GITEA_SSH_PORT}:22"
    volumes:
      - './gitea/data:/data'
      - '/etc/timezone:/etc/timezone:ro'
      - '/etc/localtime:/etc/localtime:ro'
    networks:
      - ${DOCKER_NET_NAME}
    restart: unless-stopped
EOF
fi

# --- CADDY (LOKALNY HTTPS DLA DOMEN .home) ---
if [[ "$OPT_CADDY" =~ ^[TtYy]$ ]]; then
    mkdir -p "$DOCKER_DIR/caddy"
    sudo mkdir -p "$DOCKER_DIR/caddy/data" "$DOCKER_DIR/caddy/config"
    CADDYFILE="$DOCKER_DIR/caddy/Caddyfile"
    : > "$CADDYFILE"

    if [[ "$OPT_PIHOLE" =~ ^[TtYy]$ ]]; then
        cat >> "$CADDYFILE" <<'EOF'
pihole.home {
    tls internal
    reverse_proxy pihole:80
}

EOF
    fi

    if [[ "$OPT_VW" =~ ^[TtYy]$ ]]; then
        cat >> "$CADDYFILE" <<'EOF'
vault.home {
    tls internal
    reverse_proxy vaultwarden:80
}

EOF
    fi

    if [[ "$OPT_GITEA" =~ ^[TtYy]$ ]]; then
        cat >> "$CADDYFILE" <<'EOF'
git.home {
    tls internal
    reverse_proxy gitea:3000
}

EOF
    fi

    chmod 644 "$CADDYFILE"
    if [[ "$OPT_USERNS" =~ ^[TtYy]$ ]]; then
        sudo chown -R "${REMAP_UID}:${REMAP_GID}" "$DOCKER_DIR/caddy/data" "$DOCKER_DIR/caddy/config"
    fi

    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

  caddy:
    container_name: caddy
    image: caddy:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - './caddy/Caddyfile:/etc/caddy/Caddyfile:ro'
      - './caddy/data:/data'
      - './caddy/config:/config'
    networks:
      ${DOCKER_NET_NAME}:
        ipv4_address: ${CADDY_DOCKER_IP}
    restart: unless-stopped
EOF
fi

# --- WATCHTOWER ---
if [[ "$OPT_WT" =~ ^[TtYy]$ ]]; then
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

  watchtower:
    container_name: watchtower
    image: containrrr/watchtower:latest
EOF
    [ -n "$USERNS_HOST_LINE" ] && echo "$USERNS_HOST_LINE" >> "$DOCKER_DIR/docker-compose.yml"
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF
    environment:
      - TZ=Europe/Warsaw
      - DOCKER_API_VERSION=1.44
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_INCLUDE_STOPPED=true
      - WATCHTOWER_SCHEDULE=0 0 4 * * *
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - ${DOCKER_NET_NAME}
    restart: unless-stopped
EOF
fi

# --- DEDYKOWANA SIEĆ BRIDGE ---
cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

networks:
  ${DOCKER_NET_NAME}:
    name: ${DOCKER_NET_NAME}
    driver: bridge
    ipam:
      config:
        - subnet: ${DOCKER_SUBNET}
EOF

chmod 600 "$DOCKER_DIR/docker-compose.yml"
echo -e "${GREEN}[+] Plik $DOCKER_DIR/docker-compose.yml został wygenerowany.${NC}"

# ================= 6. URUCHOMIENIE KONTENERÓW =================
cd "$DOCKER_DIR"
echo -e "${YELLOW}[3/3] Uruchamianie wybranych kontenerów w tle...${NC}"
sudo docker compose up -d --remove-orphans

# Eksport certyfikatu Root CA z Caddy (do jednorazowego wgrania na telefon/laptop)
CA_EXPORTED=""
if [[ "$OPT_CADDY" =~ ^[TtYy]$ ]]; then
    echo -e "${YELLOW}[*] Oczekiwanie na wygenerowanie lokalnego certyfikatu CA przez Caddy...${NC}"
    for i in $(seq 1 15); do
        if sudo docker exec caddy test -f /data/caddy/pki/authorities/local/root.crt 2>/dev/null; then
            sudo docker cp caddy:/data/caddy/pki/authorities/local/root.crt "$DOCKER_DIR/caddy/homelab-root-ca.crt"
            sudo chown "$ACTUAL_USER:$ACTUAL_USER" "$DOCKER_DIR/caddy/homelab-root-ca.crt"
            cp "$DOCKER_DIR/caddy/homelab-root-ca.crt" "$NAS_DIR/homelab-root-ca.crt" 2>/dev/null || true
            CA_EXPORTED="yes"
            echo -e "${GREEN}[+] Wyeksportowano certyfikat CA: $DOCKER_DIR/caddy/homelab-root-ca.crt${NC}"
            break
        fi
        sleep 1
    done
    if [ -z "$CA_EXPORTED" ]; then
        echo -e "${YELLOW}[!] Certyfikat CA jeszcze się generuje. Wyeksportujesz go ręcznie za chwilę:${NC}"
        echo -e "    sudo docker cp caddy:/data/caddy/pki/authorities/local/root.crt $DOCKER_DIR/caddy/homelab-root-ca.crt"
    fi
fi

echo -e "\n${CYAN}======================================================${NC}"
echo -e "${GREEN}[SUKCES] Wybrane usługi działają w tle!${NC}"
echo -e "Katalog danych NAS:  ${YELLOW}${NAS_DIR}${NC}"
echo -e "Plik Compose:        ${YELLOW}${DOCKER_DIR}/docker-compose.yml${NC}"
echo -e "Sieć Docker bridge:  ${YELLOW}${DOCKER_NET_NAME} (${DOCKER_SUBNET})${NC}"
[[ "$OPT_USERNS" =~ ^[TtYy]$ ]] && echo -e "Izolacja Docker:     ${GREEN}userns-remap AKTYWNY (dockremap base: ${REMAP_UID}:${REMAP_GID})${NC}"
echo -e "------------------------------------------------------"
if [[ "$OPT_CADDY" =~ ^[TtYy]$ ]]; then
    [[ "$OPT_PIHOLE" =~ ^[TtYy]$ ]] && echo -e "Pi-hole:      https://pihole.home/admin  (bezpośredni port LAN zamknięty)"
    [[ "$OPT_VW" =~ ^[TtYy]$ ]]     && echo -e "Vaultwarden:  https://vault.home         (bezpośredni port LAN zamknięty)"
    [[ "$OPT_GITEA" =~ ^[TtYy]$ ]]  && echo -e "Gitea:        https://git.home           (SSH: port ${GITEA_SSH_PORT})"
    echo -e "Certyfikat:   ${YELLOW}${DOCKER_DIR}/caddy/homelab-root-ca.crt${NC} (skopiowany też do ${NAS_DIR})"
else
    [[ "$OPT_PIHOLE" =~ ^[TtYy]$ ]] && echo -e "Pi-hole:      http://${RPI_IP}:${PIHOLE_PORT}/admin"
    [[ "$OPT_VW" =~ ^[TtYy]$ ]]     && echo -e "Vaultwarden:  http://${RPI_IP}:${VW_PORT}"
    [[ "$OPT_GITEA" =~ ^[TtYy]$ ]]  && echo -e "Gitea:        http://${RPI_IP}:${GITEA_PORT} (SSH: port ${GITEA_SSH_PORT})"
fi
[[ "$OPT_PIHOLE" =~ ^[TtYy]$ ]] && echo -e "Pi-hole Cron: Auto-aktualizacja Gravity codziennie o 03:30 (/etc/cron.d/pihole-gravity)"
[[ "$OPT_SAMBA" =~ ^[TtYy]$ ]]  && echo -e "Samba SMB:    smb://${RPI_IP}/${SHARE_NAME} (Windows: \\\\${RPI_IP}\\${SHARE_NAME})"
if [[ "$OPT_TS" =~ ^[TtYy]$ ]]; then
    echo -e "Tailscale:    Aktywny na sieci bridge (status: sudo docker exec tailscale tailscale status)"
    echo -e "              ${YELLOW}Panel: https://login.tailscale.com/admin${NC}"
    echo -e "              1) Machines -> zatwierdź Subnet Routes (${TS_ROUTES}) i wyłącz Key Expiry"
    echo -e "              2) DNS -> Global nameservers -> wpisz ${PIHOLE_DOCKER_IP} (Pi-hole bridge IP) + Override DNS servers"
fi
[[ "$OPT_WT" =~ ^[TtYy]$ ]]     && echo -e "Watchtower:   Aktywny (Auto-update codziennie o 04:00)"
echo -e "${CYAN}======================================================${NC}"
