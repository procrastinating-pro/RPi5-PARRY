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

# ================= 1. WSPÓLNE ŚCIEŻKI I SIEĆ =================
echo -e "\n${YELLOW}[*] KROK 1: Konfiguracja sieci i katalogów głównych:${NC}"
read -p "1. Adres IP Twojego Raspberry Pi [$DEFAULT_IP]: " RPI_IP
RPI_IP=${RPI_IP:-$DEFAULT_IP}

read -p "2. Katalog główny dla plików NAS [/srv/nas/pliki]: " NAS_DIR
NAS_DIR=${NAS_DIR:-/srv/nas/pliki}

read -p "3. Katalog konfiguracji Dockera [/home/$ACTUAL_USER/docker/homelab]: " DOCKER_DIR
DOCKER_DIR=${DOCKER_DIR:-/home/$ACTUAL_USER/docker/homelab}

# ================= 2. WYBÓR KONTENERÓW (T/N) =================
echo -e "\n${YELLOW}[*] KROK 2: Wybierz kontenery do zainstalowania (T/n):${NC}"
read -p "   -> [1/6] Pi-hole (Blokada reklam + Lokalny DNS)? [T/n]: " OPT_PIHOLE
OPT_PIHOLE=${OPT_PIHOLE:-T}

read -p "   -> [2/6] Samba NAS (Udział sieciowy SMB Windows/Linux)? [T/n]: " OPT_SAMBA
OPT_SAMBA=${OPT_SAMBA:-T}

read -p "   -> [3/6] FileBrowser (Webowy menedżer plików NAS)? [T/n]: " OPT_FB
OPT_FB=${OPT_FB:-T}

read -p "   -> [4/6] Twingate Connector (Zdalny dostęp Zero-Trust)? [t/N]: " OPT_TG
OPT_TG=${OPT_TG:-N}

read -p "   -> [5/6] Vaultwarden (Lokalny menedżer haseł Bitwarden)? [t/N]: " OPT_VW
OPT_VW=${OPT_VW:-N}

read -p "   -> [6/6] Gitea + PostgreSQL (Lokalny serwer Git)? [t/N]: " OPT_GITEA
OPT_GITEA=${OPT_GITEA:-N}

read -p "   -> [Extra] Watchtower (Auto-update kontenerów o 04:00)? [T/n]: " OPT_WT
OPT_WT=${OPT_WT:-T}

# ================= 3. SZCZEGÓŁOWE PYTANIA TYLKO DLA WYBRANYCH =================

if [[ "$OPT_PIHOLE" =~ ^[TtYy]$ ]]; then
    echo -e "\n${YELLOW}[*] Konfiguracja Pi-hole:${NC}"
    read -p "   -> Port panelu WWW Pi-hole [8080]: " PIHOLE_PORT
    PIHOLE_PORT=${PIHOLE_PORT:-8080}
    while true; do
        read -s -p "   -> Hasło do panelu WWW Pi-hole: " PIHOLE_PASS
        echo ""
        if [ -n "$PIHOLE_PASS" ]; then break; else echo -e "${RED}      Hasło nie może być puste!${NC}"; fi
    done
    read -p "   -> Lokalne domeny DNS [nas.home pihole.home rpi.home vault.home git.home]: " LOCAL_DOMAINS
    LOCAL_DOMAINS=${LOCAL_DOMAINS:-"nas.home pihole.home rpi.home vault.home git.home"}
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

if [[ "$OPT_FB" =~ ^[TtYy]$ ]]; then
    echo -e "\n${YELLOW}[*] Konfiguracja FileBrowser:${NC}"
    read -p "   -> Port dla FileBrowsera [8081]: " FB_PORT
    FB_PORT=${FB_PORT:-8081}
    read -p "   -> Login administratora FileBrowsera [admin]: " FB_USER
    FB_USER=${FB_USER:-admin}
    while true; do
        read -s -p "   -> Hasło do FileBrowsera (min. 12 znaków) [Enter = użyj hasła Samby]: " FB_PASS
        echo ""
        FB_PASS=${FB_PASS:-$SAMBA_PASS}
        if [ ${#FB_PASS} -ge 12 ]; then
            break
        else
            echo -e "${RED}      [!] FileBrowser wymaga hasła o długości minimum 12 znaków! Podaj dłuższe hasło.${NC}"
        fi
    done
fi

if [[ "$OPT_TG" =~ ^[TtYy]$ ]]; then
    echo -e "\n${YELLOW}[*] Konfiguracja Twingate Connector:${NC}"
    while true; do
        read -p "   -> Nazwa sieci Twingate (np. 'twojanazwa' z twojanazwa.twingate.com): " TG_NET
        if [ -n "$TG_NET" ]; then break; else echo -e "${RED}      Nazwa sieci nie może być pusta!${NC}"; fi
    done
    while true; do
        read -p "   -> Wklej TWINGATE_ACCESS_TOKEN: " TG_ACCESS
        if [ -n "$TG_ACCESS" ]; then break; else echo -e "${RED}      Access Token nie może być pusty!${NC}"; fi
    done
    while true; do
        read -p "   -> Wklej TWINGATE_REFRESH_TOKEN: " TG_REFRESH
        if [ -n "$TG_REFRESH" ]; then break; else echo -e "${RED}      Refresh Token nie może być pusty!${NC}"; fi
    done
fi

if [[ "$OPT_VW" =~ ^[TtYy]$ ]]; then
    echo -e "\n${YELLOW}[*] Konfiguracja Vaultwarden (Bitwarden):${NC}"
    read -p "   -> Port WWW dla Vaultwarden [8222]: " VW_PORT
    VW_PORT=${VW_PORT:-8222}
fi

if [[ "$OPT_GITEA" =~ ^[TtYy]$ ]]; then
    echo -e "\n${YELLOW}[*] Konfiguracja Gitea (Serwer Git + PostgreSQL):${NC}"
    read -p "   -> Port WWW dla Gitea [3000]: " GITEA_PORT
    GITEA_PORT=${GITEA_PORT:-3000}
    read -p "   -> Port SSH dla Gitea [2222]: " GITEA_SSH_PORT
    GITEA_SSH_PORT=${GITEA_SSH_PORT:-2222}
    if command -v openssl >/dev/null 2>&1; then
        GITEA_DB_PASS=$(openssl rand -hex 16)
    else
        GITEA_DB_PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
    fi
fi

echo -e "\n${CYAN}======================================================${NC}"

# ================= 4. PRZYGOTOWANIE KATALOGÓW =================
echo -e "${YELLOW}[1/4] Tworzenie struktury katalogów w $NAS_DIR oraz $DOCKER_DIR...${NC}"
sudo mkdir -p "$NAS_DIR"
sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "$(dirname "$NAS_DIR")"
sudo chmod -R 775 "$NAS_DIR"

mkdir -p "$DOCKER_DIR"

cat > "$DOCKER_DIR/docker-compose.yml" <<EOF
services:
EOF

# ================= 5. GENEROWANIE USŁUG W DOCKER-COMPOSE =================
echo -e "${YELLOW}[2/4] Generowanie pliku docker-compose.yml dla wybranych usług...${NC}"

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

    mkdir -p "$DOCKER_DIR/pihole/etc-pihole" "$DOCKER_DIR/pihole/etc-dnsmasq.d"
    rm -f "$DOCKER_DIR/pihole/etc-pihole/custom.list"
    EXTRA_HOSTS_YAML=""
    FTL_HOSTS_LIST=""

    for dom in $LOCAL_DOMAINS; do
        echo "${RPI_IP} ${dom}" >> "$DOCKER_DIR/pihole/etc-pihole/custom.list"
        EXTRA_HOSTS_YAML="${EXTRA_HOSTS_YAML}      - \"${dom}:${RPI_IP}\"\n"
        if [ -z "$FTL_HOSTS_LIST" ]; then
            FTL_HOSTS_LIST="${RPI_IP} ${dom}"
        else
            FTL_HOSTS_LIST="${FTL_HOSTS_LIST},${RPI_IP} ${dom}"
        fi
    done

    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "${PIHOLE_PORT}:80/tcp"
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
    restart: unless-stopped
EOF
fi

# --- SAMBA ---
if [[ "$OPT_SAMBA" =~ ^[TtYy]$ ]]; then
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

  samba:
    container_name: samba-nas
    image: dperson/samba:latest
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
    restart: unless-stopped
EOF
fi

# --- FILEBROWSER ---
if [[ "$OPT_FB" =~ ^[TtYy]$ ]]; then
    mkdir -p "$DOCKER_DIR/filebrowser"
    sudo chown -R "$USER_UID:$USER_GID" "$DOCKER_DIR/filebrowser"
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

  filebrowser:
    container_name: filebrowser-nas
    image: filebrowser/filebrowser:latest
    user: "${USER_UID}:${USER_GID}"
    ports:
      - "${FB_PORT}:80"
    volumes:
      - '${NAS_DIR}:/srv'
      - './filebrowser:/database'
    command: --database /database/filebrowser.db
    restart: unless-stopped
EOF
fi

# --- TWINGATE ---
if [[ "$OPT_TG" =~ ^[TtYy]$ ]]; then
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

  twingate:
    container_name: twingate-connector
    image: twingate/connector:latest
    network_mode: host
    environment:
      - TZ=Europe/Warsaw
      - TWINGATE_NETWORK=${TG_NET}
      - TWINGATE_ACCESS_TOKEN=${TG_ACCESS}
      - TWINGATE_REFRESH_TOKEN=${TG_REFRESH}
      - TWINGATE_DNS=${RPI_IP}
      - TWINGATE_LABEL_HOSTNAME=$(hostname)
    sysctls:
      - net.ipv4.ping_group_range=0 2147483647
    restart: unless-stopped
EOF
fi

# --- VAULTWARDEN ---
if [[ "$OPT_VW" =~ ^[TtYy]$ ]]; then
    mkdir -p "$DOCKER_DIR/vaultwarden"
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

  vaultwarden:
    container_name: vaultwarden
    image: vaultwarden/server:latest
    ports:
      - "${VW_PORT}:80"
    environment:
      - TZ=Europe/Warsaw
      - SIGNUPS_ALLOWED=true
      - WEBSOCKET_ENABLED=true
    volumes:
      - './vaultwarden:/data'
    restart: unless-stopped
EOF
fi

# --- GITEA + POSTGRESQL ---
if [[ "$OPT_GITEA" =~ ^[TtYy]$ ]]; then
    mkdir -p "$DOCKER_DIR/gitea/data" "$DOCKER_DIR/gitea/postgres"
    sudo chown -R "$USER_UID:$USER_GID" "$DOCKER_DIR/gitea/data"
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
    restart: unless-stopped

  gitea:
    container_name: gitea
    image: gitea/gitea:latest
    depends_on:
      gitea-db:
        condition: service_healthy
    environment:
      - TZ=Europe/Warsaw
      - USER_UID=${USER_UID}
      - USER_GID=${USER_GID}
      - GITEA__database__DB_TYPE=postgres
      - GITEA__database__HOST=gitea-db:5432
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD=${GITEA_DB_PASS}
      - GITEA__server__DOMAIN=${RPI_IP}
      - GITEA__server__SSH_DOMAIN=${RPI_IP}
      - GITEA__server__ROOT_URL=http://${RPI_IP}:${GITEA_PORT}/
      - GITEA__server__SSH_PORT=${GITEA_SSH_PORT}
    ports:
      - "${GITEA_PORT}:3000"
      - "${GITEA_SSH_PORT}:22"
    volumes:
      - './gitea/data:/data'
      - '/etc/timezone:/etc/timezone:ro'
      - '/etc/localtime:/etc/localtime:ro'
    restart: unless-stopped
EOF
fi

# --- WATCHTOWER ---
if [[ "$OPT_WT" =~ ^[TtYy]$ ]]; then
    cat >> "$DOCKER_DIR/docker-compose.yml" <<EOF

  watchtower:
    container_name: watchtower
    image: containrrr/watchtower:latest
    environment:
      - TZ=Europe/Warsaw
      - DOCKER_API_VERSION=1.44
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_INCLUDE_STOPPED=true
      - WATCHTOWER_SCHEDULE=0 0 4 * * *
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
EOF
fi

echo -e "${GREEN}[+] Plik $DOCKER_DIR/docker-compose.yml został wygenerowany.${NC}"

# ================= 6. INICJALIZACJA BAZY FILEBROWSERA =================
cd "$DOCKER_DIR"

if [[ "$OPT_FB" =~ ^[TtYy]$ ]]; then
    echo -e "${YELLOW}[3/4] Konfiguracja konta '$FB_USER' w bazie FileBrowsera...${NC}"
    sudo docker compose stop filebrowser >/dev/null 2>&1 || true
    sudo rm -f "$DOCKER_DIR/filebrowser/filebrowser.db"
    sudo docker compose run --rm filebrowser config init --database /database/filebrowser.db >/dev/null
    sudo docker compose run --rm filebrowser config set --address 0.0.0.0 --root /srv --database /database/filebrowser.db >/dev/null
    sudo docker compose run --rm filebrowser users add "$FB_USER" "$FB_PASS" --perm.admin --database /database/filebrowser.db >/dev/null
    echo -e "${GREEN}[+] Utworzono konto '$FB_USER' w FileBrowserze.${NC}"
else
    echo -e "${YELLOW}[3/4] Pominięto inicjalizację FileBrowsera.${NC}"
fi

# ================= 7. URUCHOMIENIE KONTENERÓW =================
echo -e "${YELLOW}[4/4] Uruchamianie wybranych kontenerów w tle...${NC}"
sudo docker compose up -d

echo -e "\n${CYAN}======================================================${NC}"
echo -e "${GREEN}[SUKCES] Wybrane usługi działają w tle!${NC}"
echo -e "Katalog danych NAS:  ${YELLOW}${NAS_DIR}${NC}"
echo -e "Plik Compose:        ${YELLOW}${DOCKER_DIR}/docker-compose.yml${NC}"
echo -e "------------------------------------------------------"
[[ "$OPT_PIHOLE" =~ ^[TtYy]$ ]] && echo -e "Pi-hole:      http://${RPI_IP}:${PIHOLE_PORT}/admin"
[[ "$OPT_SAMBA" =~ ^[TtYy]$ ]]  && echo -e "Samba SMB:    smb://${RPI_IP}/${SHARE_NAME} (Windows: \\\\${RPI_IP}\\${SHARE_NAME})"
[[ "$OPT_FB" =~ ^[TtYy]$ ]]     && echo -e "FileBrowser:  http://${RPI_IP}:${FB_PORT}"
[[ "$OPT_VW" =~ ^[TtYy]$ ]]     && echo -e "Vaultwarden:  http://${RPI_IP}:${VW_PORT}"
[[ "$OPT_GITEA" =~ ^[TtYy]$ ]]  && echo -e "Gitea:        http://${RPI_IP}:${GITEA_PORT} (SSH: port ${GITEA_SSH_PORT})"
[[ "$OPT_TG" =~ ^[TtYy]$ ]]     && echo -e "Twingate:     Aktywny w trybie hosta (logi: sudo docker logs twingate-connector)"
[[ "$OPT_WT" =~ ^[TtYy]$ ]]     && echo -e "Watchtower:   Aktywny (Auto-update codziennie o 04:00)"
echo -e "${CYAN}======================================================${NC}"
