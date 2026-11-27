#!/bin/bash
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ACTUAL_USER=${SUDO_USER:-$USER}
DEFAULT_DOCKER_DIR="/home/$ACTUAL_USER/docker/homelab"
DEFAULT_NAS_DIR="/srv/nas/pliki"
DEFAULT_BACKUP_MOUNT="/mnt/backup_usb"

# ================= TRYB AUTOMATYCZNY (CRON: --auto) =================
if [ "$1" == "--auto" ]; then
    if [ ! -f /etc/homelab-backup.conf ]; then
        echo "[BŁĄD] Brak pliku /etc/homelab-backup.conf. Uruchom skrypt najpierw interaktywnie!"
        exit 1
    fi
    source /etc/homelab-backup.conf

    if ! mountpoint -q "$BACKUP_MOUNT" 2>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [POMINIĘTO] Dysk zewnętrzny ($BACKUP_MOUNT) nie jest zamontowany!" >> /var/log/homelab-backup.log
        exit 1
    fi

    TIMESTAMP=$(date +%Y-%m-%d_%H-%M)
    SNAP_DIR="$BACKUP_DIR/snapshots/$TIMESTAMP"
    MIRROR_DIR="$BACKUP_DIR/nas-mirror"
    TMP_DIR="/tmp/homelab_snap_$TIMESTAMP"

    mkdir -p "$SNAP_DIR" "$MIRROR_DIR" "$TMP_DIR"
    chmod 700 "$BACKUP_DIR" "$SNAP_DIR"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] === START NOCNEGO BACKUPU ===" >> /var/log/homelab-backup.log

    # 1. Lustrzana kopia plików NAS (jak RAID 1 + archiwum na usunięte/nadpisane pliki)
    if [ -d "$NAS_DIR" ]; then
        ARCHIVE_DIFF="$BACKUP_DIR/nas-deleted-history/$TIMESTAMP"
        rsync -a --delete --backup --backup-dir="$ARCHIVE_DIFF" "$NAS_DIR/" "$MIRROR_DIR/" >> /var/log/homelab-backup.log 2>&1
        rmdir "$ARCHIVE_DIFF" 2>/dev/null || true
    fi

    # 2. Spójny zrzut bazy Vaultwarden (SQLite online backup)
    if docker ps -q -f name="^vaultwarden$" | grep -q .; then
        mkdir -p "$TMP_DIR/vaultwarden"
        if [ -f "$DOCKER_DIR/vaultwarden/db.sqlite3" ]; then
            if command -v sqlite3 >/dev/null 2>&1; then
                sqlite3 "$DOCKER_DIR/vaultwarden/db.sqlite3" ".backup '$TMP_DIR/vaultwarden/db.sqlite3'"
            else
                cp "$DOCKER_DIR/vaultwarden/db.sqlite3" "$TMP_DIR/vaultwarden/db.sqlite3"
            fi
        fi
        for item in rsa_key.pem rsa_key.pub.pem attachments sends config.json; do
            [ -e "$DOCKER_DIR/vaultwarden/$item" ] && cp -a "$DOCKER_DIR/vaultwarden/$item" "$TMP_DIR/vaultwarden/"
        done
    fi

    # 3. Spójny zrzut bazy PostgreSQL Gitea + repozytoriów
    if docker ps -q -f name="^gitea-db$" | grep -q .; then
        mkdir -p "$TMP_DIR/gitea"
        docker exec gitea-db pg_dump -U gitea gitea > "$TMP_DIR/gitea/gitea_postgres.sql"
        [ -d "$DOCKER_DIR/gitea/data" ] && cp -a "$DOCKER_DIR/gitea/data" "$TMP_DIR/gitea/"
    fi

    # 4. Kopia ustawień Pi-hole oraz Caddy
    if docker ps -q -f name="^pihole$" | grep -q .; then
        mkdir -p "$TMP_DIR/pihole"
        [ -d "$DOCKER_DIR/pihole/etc-pihole" ] && cp -a "$DOCKER_DIR/pihole/etc-pihole" "$TMP_DIR/pihole/"
        [ -d "$DOCKER_DIR/pihole/etc-dnsmasq.d" ] && cp -a "$DOCKER_DIR/pihole/etc-dnsmasq.d" "$TMP_DIR/pihole/"
    fi
    if [ -d "$DOCKER_DIR/caddy" ]; then
        mkdir -p "$TMP_DIR/caddy"
        cp -a "$DOCKER_DIR/caddy/Caddyfile" "$DOCKER_DIR/caddy/homelab-root-ca.crt" "$TMP_DIR/caddy/" 2>/dev/null || true
    fi
    [ -f "$DOCKER_DIR/docker-compose.yml" ] && cp -a "$DOCKER_DIR/docker-compose.yml" "$TMP_DIR/"

    # 5. Pakowanie i szyfrowanie AES-256 (OpenSSL PBKDF2)
    ARCHIVE_FILE="$SNAP_DIR/homelab_services_$TIMESTAMP.tar.gz.enc"
    tar -czf - -C "$TMP_DIR" . | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -pass file:/etc/homelab-backup.key -out "$ARCHIVE_FILE"
    chmod 600 "$ARCHIVE_FILE"
    rm -rf "$TMP_DIR"

    # 6. Rotacja starych migawek
    find "$BACKUP_DIR/snapshots" -mindepth 1 -maxdepth 1 -type d -mtime +"${RETENTION_DAYS:-14}" -exec rm -rf {} + 2>/dev/null || true
    find "$BACKUP_DIR/nas-deleted-history" -mindepth 1 -maxdepth 1 -type d -mtime +"${RETENTION_DAYS:-14}" -exec rm -rf {} + 2>/dev/null || true

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] === KONIEC BACKUPU (OK: $ARCHIVE_FILE) ===" >> /var/log/homelab-backup.log
    exit 0
fi

# ================= FUNKCJA PRZYWRACANIA (RESTORE WIZARD) =================
restore_wizard() {
    clear
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}        KREATOR PRZYWRACANIA DANYCH Z BACKUPU         ${NC}"
    echo -e "${CYAN}======================================================${NC}"

    [ -f /etc/homelab-backup.conf ] && source /etc/homelab-backup.conf
    read -p "1. Katalog z kopiami na dysku backupowym [${BACKUP_DIR:-/mnt/backup_usb/homelab-backup}]: " IN_BDIR
    BACKUP_DIR=${IN_BDIR:-${BACKUP_DIR:-/mnt/backup_usb/homelab-backup}}

    read -p "2. Docelowy katalog Dockera [${DOCKER_DIR:-$DEFAULT_DOCKER_DIR}]: " IN_DDIR
    DOCKER_DIR=${IN_DDIR:-${DOCKER_DIR:-$DEFAULT_DOCKER_DIR}}

    read -p "3. Docelowy katalog plików NAS [${NAS_DIR:-$DEFAULT_NAS_DIR}]: " IN_NDIR
    NAS_DIR=${IN_NDIR:-${NAS_DIR:-$DEFAULT_NAS_DIR}}

    if [ ! -d "$BACKUP_DIR/snapshots" ]; then
        echo -e "${RED}[!] Nie znaleziono katalogu migawek: $BACKUP_DIR/snapshots${NC}"
        exit 1
    fi

    mapfile -t SNAPSHOTS < <(find "$BACKUP_DIR/snapshots" -mindepth 1 -maxdepth 1 -type d | sort -r)
    if [ ${#SNAPSHOTS[@]} -eq 0 ]; then
        echo -e "${RED}[!] Brak dostępnych migawek w $BACKUP_DIR/snapshots!${NC}"
        exit 1
    fi

    echo -e "\n${YELLOW}[*] Dostępne migawki backupu (od najnowszej):${NC}"
    for i in "${!SNAPSHOTS[@]}"; do
        echo -e "   ${CYAN}[$((i+1))]${NC} $(basename "${SNAPSHOTS[$i]}")"
    done

    echo ""
    read -p "Wybierz numer migawki do przywrócenia [1]: " SNAP_IDX
    SNAP_IDX=${SNAP_IDX:-1}
    SELECTED_SNAP="${SNAPSHOTS[$((SNAP_IDX-1))]}"

    if [ -z "$SELECTED_SNAP" ] || [ ! -d "$SELECTED_SNAP" ]; then
        echo -e "${RED}[!] Nieprawidłowy wybór migawki.${NC}"
        exit 1
    fi

    ENC_ARCHIVE=$(find "$SELECTED_SNAP" -maxdepth 1 -name "*.tar.gz.enc" | head -n 1)
    if [ -z "$ENC_ARCHIVE" ]; then
        echo -e "${RED}[!] Brak zaszyfrowanego archiwum w wybranej migawce!${NC}"
        exit 1
    fi

    echo -e "\n${YELLOW}[*] Co chcesz przywrócić z migawki $(basename "$SELECTED_SNAP")?${NC}"
    echo -e "   ${CYAN}[1]${NC} Wszystko (Vaultwarden + Gitea + Pi-hole + Caddy + Lustro plików NAS)"
    echo -e "   ${CYAN}[2]${NC} Tylko usługi (Vaultwarden + Gitea + Pi-hole + Caddy + Compose)"
    echo -e "   ${CYAN}[3]${NC} Tylko Vaultwarden (baza haseł + klucze)"
    echo -e "   ${CYAN}[4]${NC} Tylko Gitea (baza PostgreSQL + repozytoria)"
    echo -e "   ${CYAN}[5]${NC} Tylko Pi-hole i Caddy (ustawienia DNS + certyfikaty)"
    echo -e "   ${CYAN}[6]${NC} Tylko pliki NAS z lustra (nas-mirror -> $NAS_DIR)"
    read -p "Wybierz opcję [1]: " RESTORE_SCOPE
    RESTORE_SCOPE=${RESTORE_SCOPE:-1}

    RESTORE_TMP="/tmp/homelab_restore_$(date +%s)"
    mkdir -p "$RESTORE_TMP"

    if [ "$RESTORE_SCOPE" != "6" ]; then
        echo -e "\n${YELLOW}[*] Odszyfrowywanie archiwum: $(basename "$ENC_ARCHIVE")${NC}"
        while true; do
            read -s -p "   -> Podaj hasło szyfrowania AES-256: " DEC_PASS
            echo ""
            if openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in "$ENC_ARCHIVE" -pass pass:"$DEC_PASS" 2>/dev/null | tar -xzf - -C "$RESTORE_TMP" 2>/dev/null; then
                echo -e "${GREEN}   [+] Archiwum pomyślnie odszyfrowane i rozpakowane!${NC}"
                break
            else
                echo -e "${RED}   [!] Błędne hasło lub uszkodzone archiwum. Spróbuj ponownie (Ctrl+C przerywa).${NC}"
                rm -rf "$RESTORE_TMP"/*
            fi
        done
    fi

    echo -e "\n${RED}[!] UWAGA: Przywracanie nadpisze obecne dane wybranych usług!${NC}"
    read -p "    Wpisz 'TAK', aby rozpocząć przywracanie: " CONFIRM_RESTORE
    if [ "$CONFIRM_RESTORE" != "TAK" ]; then
        rm -rf "$RESTORE_TMP"
        echo -e "${YELLOW}[*] Anulowano przywracanie.${NC}"
        exit 0
    fi

    # Wykrycie userns-remap (jeśli aktywne, pliki kontenerów muszą mieć właściciela dockremap)
    REMAP_UID=$(awk -F: '$1=="dockremap"{print $2; exit}' /etc/subuid 2>/dev/null || true)
    REMAP_GID=$(awk -F: '$1=="dockremap"{print $2; exit}' /etc/subgid 2>/dev/null || true)
    USERNS_ACTIVE=""
    grep -q '"userns-remap"' /etc/docker/daemon.json 2>/dev/null && USERNS_ACTIVE="yes"

    # Przywracanie Vaultwarden
    if [[ "$RESTORE_SCOPE" =~ ^(1|2|3)$ ]] && [ -d "$RESTORE_TMP/vaultwarden" ]; then
        echo -e "${YELLOW}   -> Przywracanie Vaultwarden...${NC}"
        sudo docker stop vaultwarden >/dev/null 2>&1 || true
        sudo mkdir -p "$DOCKER_DIR/vaultwarden"
        sudo rm -f "$DOCKER_DIR/vaultwarden/db.sqlite3-wal" "$DOCKER_DIR/vaultwarden/db.sqlite3-shm"
        sudo cp -a "$RESTORE_TMP/vaultwarden/." "$DOCKER_DIR/vaultwarden/"
        [ -n "$USERNS_ACTIVE" ] && [ -n "$REMAP_UID" ] && sudo chown -R "${REMAP_UID}:${REMAP_GID}" "$DOCKER_DIR/vaultwarden"
        sudo docker start vaultwarden >/dev/null 2>&1 || true
        echo -e "${GREEN}   [+] Vaultwarden przywrócony.${NC}"
    fi

    # Przywracanie Gitea + PostgreSQL
    if [[ "$RESTORE_SCOPE" =~ ^(1|2|4)$ ]] && [ -d "$RESTORE_TMP/gitea" ]; then
        echo -e "${YELLOW}   -> Przywracanie Gitea + PostgreSQL...${NC}"
        sudo docker stop gitea >/dev/null 2>&1 || true
        if [ -d "$RESTORE_TMP/gitea/data" ]; then
            sudo mkdir -p "$DOCKER_DIR/gitea/data"
            sudo cp -a "$RESTORE_TMP/gitea/data/." "$DOCKER_DIR/gitea/data/"
            [ -n "$USERNS_ACTIVE" ] && [ -n "$REMAP_UID" ] && sudo chown -R "${REMAP_UID}:${REMAP_GID}" "$DOCKER_DIR/gitea/data"
        fi
        if [ -f "$RESTORE_TMP/gitea/gitea_postgres.sql" ] && docker ps -q -f name="^gitea-db$" | grep -q .; then
            sudo docker exec -i gitea-db psql -U gitea -d postgres -c "DROP DATABASE IF EXISTS gitea;" >/dev/null
            sudo docker exec -i gitea-db psql -U gitea -d postgres -c "CREATE DATABASE gitea OWNER gitea;" >/dev/null
            cat "$RESTORE_TMP/gitea/gitea_postgres.sql" | sudo docker exec -i gitea-db psql -U gitea -d gitea >/dev/null
        fi
        sudo docker start gitea >/dev/null 2>&1 || true
        echo -e "${GREEN}   [+] Gitea przywrócona.${NC}"
    fi

    # Przywracanie Pi-hole i Caddy
    if [[ "$RESTORE_SCOPE" =~ ^(1|2|5)$ ]]; then
        if [ -d "$RESTORE_TMP/pihole" ]; then
            echo -e "${YELLOW}   -> Przywracanie Pi-hole...${NC}"
            sudo docker stop pihole >/dev/null 2>&1 || true
            [ -d "$RESTORE_TMP/pihole/etc-pihole" ] && sudo cp -a "$RESTORE_TMP/pihole/etc-pihole/." "$DOCKER_DIR/pihole/etc-pihole/"
            [ -d "$RESTORE_TMP/pihole/etc-dnsmasq.d" ] && sudo cp -a "$RESTORE_TMP/pihole/etc-dnsmasq.d/." "$DOCKER_DIR/pihole/etc-dnsmasq.d/"
            [ -n "$USERNS_ACTIVE" ] && [ -n "$REMAP_UID" ] && sudo chown -R "${REMAP_UID}:${REMAP_GID}" "$DOCKER_DIR/pihole"
            sudo docker start pihole >/dev/null 2>&1 || true
            echo -e "${GREEN}   [+] Pi-hole przywrócony.${NC}"
        fi
        if [ -d "$RESTORE_TMP/caddy" ]; then
            echo -e "${YELLOW}   -> Przywracanie Caddy...${NC}"
            sudo mkdir -p "$DOCKER_DIR/caddy"
            sudo cp -a "$RESTORE_TMP/caddy/." "$DOCKER_DIR/caddy/"
            sudo docker restart caddy >/dev/null 2>&1 || true
            echo -e "${GREEN}   [+] Caddy przywrócony.${NC}"
        fi
    fi

    # Przywracanie plików NAS z lustra
    if [[ "$RESTORE_SCOPE" =~ ^(1|6)$ ]]; then
        if [ -d "$BACKUP_DIR/nas-mirror" ]; then
            echo -e "${YELLOW}   -> Przywracanie plików NAS z lustra ($BACKUP_DIR/nas-mirror -> $NAS_DIR)...${NC}"
            sudo mkdir -p "$NAS_DIR"
            sudo rsync -a "$BACKUP_DIR/nas-mirror/" "$NAS_DIR/"
            sudo chown -R "$ACTUAL_USER:$ACTUAL_USER" "$NAS_DIR"
            echo -e "${GREEN}   [+] Pliki NAS przywrócone.${NC}"
        else
            echo -e "${RED}   [!] Brak katalogu $BACKUP_DIR/nas-mirror.${NC}"
        fi
    fi

    rm -rf "$RESTORE_TMP"
    echo -e "\n${CYAN}======================================================${NC}"
    echo -e "${GREEN}[SUKCES] Przywracanie zakończone!${NC}"
    echo -e "${CYAN}======================================================${NC}"
    exit 0
}

# ================= MENU GŁÓWNE KONFIGURATORA =================
clear
echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}   KONFIGURATOR BACKUPU 3-2-1, DYSKU USB I RESTORE    ${NC}"
echo -e "${CYAN}======================================================${NC}"
echo -e "Wybierz tryb działania:"
echo -e "   ${CYAN}[1]${NC} Skonfiguruj nocny backup (z automatycznym przygotowaniem/formatem dysku USB)"
echo -e "   ${CYAN}[2]${NC} Przywróć dane z backupu (Kreator Restore — podajesz tylko hasło)"
echo ""
read -p "Twój wybór [1]: " MAIN_CHOICE
MAIN_CHOICE=${MAIN_CHOICE:-1}

if [ "$MAIN_CHOICE" == "2" ]; then
    restore_wizard
fi

# ================= KROK 1: WYKRYCIE I OPCJONALNE FORMATOWANIE DYSKU USB =================
echo -e "\n${YELLOW}[*] KROK 1: Wybór i przygotowanie dysku zewnętrznego USB:${NC}"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT | grep -E "NAME|sd|nvme|mmcblk" || true
echo ""

read -p "1. Punkt montowania dysku backupowego [$DEFAULT_BACKUP_MOUNT]: " BACKUP_MOUNT
BACKUP_MOUNT=${BACKUP_MOUNT:-$DEFAULT_BACKUP_MOUNT}

if ! mountpoint -q "$BACKUP_MOUNT" 2>/dev/null; then
    echo -e "${YELLOW}[!] Katalog $BACKUP_MOUNT nie jest jeszcze zamontowany jako dysk zewnętrzny.${NC}"
    read -p "    Czy chcesz teraz przygotować (sformatować na ext4 i dopisać do /etc/fstab) dysk USB? [T/n]: " PREP_DISK
    PREP_DISK=${PREP_DISK:-T}

    if [[ "$PREP_DISK" =~ ^[TtYy]$ ]]; then
        echo -e "\n${YELLOW}   Dostępne dyski blokowe:${NC}"
        lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -E "NAME|usb|sd" || true
        echo ""
        read -p "   -> Podaj nazwę urządzenia dysku USB (np. sda — BEZ /dev/ i BEZ numeru partycji!): " USB_DEV
        USB_DEV=${USB_DEV#/dev/}

        if [ -z "$USB_DEV" ] || [ ! -b "/dev/$USB_DEV" ]; then
            echo -e "${RED}[!] Urządzenie /dev/$USB_DEV nie istnieje! Przerywam.${NC}"
            exit 1
        fi

        if [[ "$USB_DEV" == nvme* ]] || [[ "$USB_DEV" == mmcblk* ]]; then
            echo -e "${RED}[!] BŁĄD BEZPIECZEŃSTWA: Wykryto dysk systemowy ($USB_DEV). Formatowanie zablokowane!${NC}"
            exit 1
        fi

        read -p "   -> Podaj etykietę (nazwę) dla tego dysku [BACKUP_USB]: " DISK_LABEL
        DISK_LABEL=${DISK_LABEL:-BACKUP_USB}

        echo -e "\n${RED}[!] OSTRZEŻENIE: Wszystkie dane na /dev/${USB_DEV} zostaną BEZPOWROTNIE USUNIĘTE!${NC}"
        read -p "    Wpisz 'FORMATUJ' wielkimi literami, aby sformatować /dev/${USB_DEV} jako '${DISK_LABEL}' (ext4): " CONFIRM_FMT
        if [ "$CONFIRM_FMT" != "FORMATUJ" ]; then
            echo -e "${YELLOW}[*] Anulowano formatowanie.${NC}"
            exit 0
        fi

        echo -e "${YELLOW}   -> Odmontowywanie ewentualnych partycji na /dev/${USB_DEV}...${NC}"
        for part in /dev/${USB_DEV}*; do
            sudo umount "$part" 2>/dev/null || true
        done

        echo -e "${YELLOW}   -> Tworzenie tablicy partycji GPT i partycji ext4 (${DISK_LABEL})...${NC}"
        sudo parted -s "/dev/${USB_DEV}" mklabel gpt
        sudo parted -s "/dev/${USB_DEV}" mkpart primary ext4 0% 100%
        sleep 2

        USB_PART="/dev/${USB_DEV}1"
        sudo mkfs.ext4 -F -L "$DISK_LABEL" "$USB_PART" >/dev/null

        PART_UUID=$(sudo blkid -s UUID -o value "$USB_PART")
        if [ -z "$PART_UUID" ]; then
            echo -e "${RED}[!] Nie udało się odczytać UUID partycji $USB_PART.${NC}"
            exit 1
        fi

        sudo mkdir -p "$BACKUP_MOUNT"
        # Usuń stary wpis dla tego samego punktu montowania, jeśli istniał
        sudo sed -i "\|[[:space:]]${BACKUP_MOUNT}[[:space:]]|d" /etc/fstab
        echo "UUID=${PART_UUID} ${BACKUP_MOUNT} ext4 defaults,noatime,nofail,x-systemd.device-timeout=10 0 2" | sudo tee -a /etc/fstab >/dev/null

        sudo systemctl daemon-reload
        sudo mount "$BACKUP_MOUNT"
        echo -e "${GREEN}   [+] Dysk /dev/${USB_DEV} sformatowany jako '${DISK_LABEL}' (UUID=${PART_UUID}) i zamontowany w ${BACKUP_MOUNT}!${NC}"
    else
        echo -e "${RED}[!] Podłącz i zamontuj dysk w $BACKUP_MOUNT przed kontynuacją.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}   [+] Dysk w $BACKUP_MOUNT jest już poprawnie zamontowany (pominięto formatowanie).${NC}"
fi

# ================= KROK 2: ŚCIEŻKI, RETENCJA I HASŁO =================
echo -e "\n${YELLOW}[*] KROK 2: Parametry harmonogramu i szyfrowania:${NC}"
BACKUP_DIR="$BACKUP_MOUNT/homelab-backup"

read -p "2. Katalog główny plików NAS do lustrzanej kopii [$DEFAULT_NAS_DIR]: " NAS_DIR
NAS_DIR=${NAS_DIR:-$DEFAULT_NAS_DIR}

read -p "3. Katalog konfiguracji Dockera [$DEFAULT_DOCKER_DIR]: " DOCKER_DIR
DOCKER_DIR=${DOCKER_DIR:-$DEFAULT_DOCKER_DIR}

read -p "4. Ile dni trzymać historyczne migawki i usunięte pliki? [14]: " RETENTION_DAYS
RETENTION_DAYS=${RETENTION_DAYS:-14}

while true; do
    read -s -p "5. Hasło szyfrowania AES-256 dla baz (min. 12 znaków): " ENC_PASS
    echo ""
    if [ ${#ENC_PASS} -ge 12 ]; then
        read -s -p "   -> Powtórz hasło szyfrowania: " ENC_PASS_CONFIRM
        echo ""
        if [ "$ENC_PASS" == "$ENC_PASS_CONFIRM" ]; then
            break
        else
            echo -e "${RED}      Hasła nie są identyczne! Spróbuj ponownie.${NC}"
        fi
    else
        echo -e "${RED}      Hasło musi mieć minimum 12 znaków! Zapisz je w Vaultwardenie + na kartce.${NC}"
    fi
done

# Zapis klucza i konfiguracji
echo -n "$ENC_PASS" | sudo tee /etc/homelab-backup.key >/dev/null
sudo chmod 600 /etc/homelab-backup.key

sudo tee /etc/homelab-backup.conf >/dev/null <<EOF
BACKUP_MOUNT="$BACKUP_MOUNT"
BACKUP_DIR="$BACKUP_DIR"
NAS_DIR="$NAS_DIR"
DOCKER_DIR="$DOCKER_DIR"
RETENTION_DAYS="$RETENTION_DAYS"
EOF
sudo chmod 600 /etc/homelab-backup.conf

# Instalacja skryptu systemowego i Crona (03:00 w nocy)
sudo cp "$0" /usr/local/sbin/homelab-backup.sh
sudo chmod 700 /usr/local/sbin/homelab-backup.sh

echo "0 3 * * * root /usr/local/sbin/homelab-backup.sh --auto" | sudo tee /etc/cron.d/homelab-backup >/dev/null
sudo chmod 644 /etc/cron.d/homelab-backup

echo -e "\n${CYAN}======================================================${NC}"
echo -e "${GREEN}[SUKCES] Skonfigurowano nocny backup o 03:00!${NC}"
echo -e "    - Dysk backupowy:       ${YELLOW}${BACKUP_MOUNT}${NC}"
echo -e "    - Lustrzana kopia NAS:  ${YELLOW}${BACKUP_DIR}/nas-mirror${NC}"
echo -e "    - Szyfrowane migawki:   ${YELLOW}${BACKUP_DIR}/snapshots/${NC}"
echo -e "    - Logi z wykonania:     ${YELLOW}/var/log/homelab-backup.log${NC}"
echo -e "------------------------------------------------------"
echo -e "Test od razu teraz:  ${CYAN}sudo /usr/local/sbin/homelab-backup.sh --auto${NC}"
echo -e "Kreator przywracania: ${CYAN}sudo /usr/local/sbin/homelab-backup.sh${NC} (wybierz opcję [2])"
echo -e "${CYAN}======================================================${NC}"
