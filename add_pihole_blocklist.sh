#!/usr/bin/env bash
set -euo pipefail

trap 'echo -e "\n\033[0;31m[BŁĄD] Skrypt przerwał działanie w linii $LINENO.\033[0m"' ERR

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}   Konfigurator Blocklist dla Docker Pi-hole       ${NC}"
echo -e "${BLUE}====================================================${NC}"

# Wybór polecenia docker (z sudo jeśli wymagane)
DOCKER_BIN="docker"
if ! docker info >/dev/null 2>&1; then
    if sudo docker info >/dev/null 2>&1; then
        DOCKER_BIN="sudo docker"
    else
        echo -e "${RED}[x] Brak dostępu do demona Dockera.${NC}"
        exit 1
    fi
fi

# Wykrycie działającego kontenera Pi-hole
RUNNING_CONTAINERS=$($DOCKER_BIN ps --format "{{.Names}}" 2>/dev/null || true)
if [[ -z "$RUNNING_CONTAINERS" ]]; then
    echo -e "${RED}[x] Brak uruchomionych kontenerów w Dockerze.${NC}"
    exit 1
fi

DEFAULT_CONTAINER=$(echo "$RUNNING_CONTAINERS" | grep -iE "pihole" | head -n 1 || true)
DEFAULT_CONTAINER=${DEFAULT_CONTAINER:-$(echo "$RUNNING_CONTAINERS" | head -n 1)}

echo ""
echo -e "${YELLOW}Dostępne uruchomione kontenery:${NC}"
echo "$RUNNING_CONTAINERS" | sed 's/^/  - /'
echo ""
read -rp "Nazwa kontenera Pi-hole [domyślnie: ${DEFAULT_CONTAINER}]: " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-$DEFAULT_CONTAINER}

if ! $DOCKER_BIN inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo -e "${RED}[x] Kontener '${CONTAINER_NAME}' nie istnieje.${NC}"
    exit 1
fi

# Sprawdzenie dostępności bazy gravity.db w kontenerze
GRAVITY_DB="/etc/pihole/gravity.db"
if ! $DOCKER_BIN exec "$CONTAINER_NAME" test -f "$GRAVITY_DB"; then
    echo -e "${RED}[x] Nie znaleziono bazy ${GRAVITY_DB} w kontenerze '${CONTAINER_NAME}'.${NC}"
    exit 1
fi

# Wykrycie silnika do edycji bazy SQLite
DB_ENGINE=""
if $DOCKER_BIN exec "$CONTAINER_NAME" pihole-FTL sqlite3 --version >/dev/null 2>&1; then
    DB_ENGINE="ftl_sqlite"
elif $DOCKER_BIN exec "$CONTAINER_NAME" command -v sqlite3 >/dev/null 2>&1; then
    DB_ENGINE="container_sqlite"
elif $DOCKER_BIN exec "$CONTAINER_NAME" command -v python3 >/dev/null 2>&1; then
    DB_ENGINE="container_python"
elif command -v python3 >/dev/null 2>&1; then
    DB_ENGINE="host_python"
else
    echo -e "${RED}[x] Brak sqlite3/pihole-FTL w kontenerze oraz brak python3 na hoście.${NC}"
    exit 1
fi

echo -e "${GREEN}[+] Wykryty silnik bazy danych: ${DB_ENGINE}${NC}"

# Zestawy blocklist (URL|OPIS)
LIST_HAGEZI_PRO=(
    "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/pro.txt|HaGeZi Multi PRO (Ads + Tracking + Telemetry)"
)

LIST_HAGEZI_PRO_PLUS=(
    "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/pro.plus.txt|HaGeZi Multi PRO++ (Aggressive Ads + Tracking)"
)

LIST_HAGEZI_ULTIMATE=(
    "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/ultimate.txt|HaGeZi Ultimate (Very Aggressive)"
)

LIST_HAGEZI_TIF=(
    "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/domains/tif.txt|HaGeZi Threat Intelligence Feeds (Malware/Phishing/C2)"
)

LIST_CLASSIC=(
    "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts|StevenBlack Unified Hosts"
    "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt|AdGuard DNS Filter"
    "https://v.firebog.net/hosts/AdguardDNS.txt|Firebog - AdGuardDNS"
    "https://v.firebog.net/hosts/Easylist.txt|Firebog - EasyList"
    "https://v.firebog.net/hosts/Easyprivacy.txt|Firebog - EasyPrivacy"
    "https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt|Perflyst SmartTV Blocklist"
)

echo ""
echo "Wybierz zestaw list do dodania:"
echo "  1) HaGeZi Multi PRO + TIF (zalecane — reklamy, telemetria, malware)"
echo "  2) HaGeZi Multi PRO++ + TIF (agresywniejsze blokowanie)"
echo "  3) HaGeZi Ultimate + TIF (maksymalne blokowanie — może wymagać whitelisty)"
echo "  4) Klasyczny zestaw (StevenBlack + AdGuard + Firebog + SmartTV)"
echo "  5) Własna lista adresów URL (oddzielone spacją)"
read -rp "Wybór [domyślnie: 1]: " PROFILE_CHOICE
PROFILE_CHOICE=${PROFILE_CHOICE:-1}

SELECTED_ENTRIES=()

add_array_entries() {
    local -n arr_ref=$1
    local entry
    for entry in "${arr_ref[@]}"; do
        SELECTED_ENTRIES+=("$entry")
    done
}

case "$PROFILE_CHOICE" in
    1)
        add_array_entries LIST_HAGEZI_PRO
        add_array_entries LIST_HAGEZI_TIF
        ;;
    2)
        add_array_entries LIST_HAGEZI_PRO_PLUS
        add_array_entries LIST_HAGEZI_TIF
        ;;
    3)
        add_array_entries LIST_HAGEZI_ULTIMATE
        add_array_entries LIST_HAGEZI_TIF
        ;;
    4)
        add_array_entries LIST_CLASSIC
        ;;
    5)
        read -rp "Podaj adresy URL blocklist: " CUSTOM_URLS
        for url in $CUSTOM_URLS; do
            [[ -n "$url" ]] && SELECTED_ENTRIES+=("${url}|Custom list")
        done
        ;;
    *)
        echo -e "${RED}[x] Nieprawidłowy wybór.${NC}"
        exit 1
        ;;
esac

if [[ ${#SELECTED_ENTRIES[@]} -eq 0 ]]; then
    echo -e "${RED}[x] Brak list do dodania.${NC}"
    exit 1
fi

# Opcjonalny backup gravity.db przed modyfikacją
read -rp "Utworzyć kopię zapasową gravity.db przed dodaniem list? [T/n]: " DO_BACKUP
if [[ "${DO_BACKUP,,}" != "n" ]]; then
    BACKUP_DIR="$HOME/pihole_backups"
    mkdir -p "$BACKUP_DIR"
    TS=$(date '+%Y%m%d_%H%M%S')
    $DOCKER_BIN cp "${CONTAINER_NAME}:${GRAVITY_DB}" "${BACKUP_DIR}/gravity_${TS}.db"
    echo -e "${GREEN}[+] Zapisano backup: ${BACKUP_DIR}/gravity_${TS}.db${NC}"
fi

# Skrypt Pythona do wstawiania wpisów (dla trybu container_python oraz host_python)
read -r -d '' PY_INSERT_SCRIPT <<'PYEOF' || true
import sqlite3
import sys

db_path = sys.argv[1]
conn = sqlite3.connect(db_path)
cur = conn.cursor()

cols = [row[1] for row in cur.execute("PRAGMA table_info(adlist)").fetchall()]
has_comment = "comment" in cols

added = 0
skipped = 0

for raw_line in sys.stdin:
    line = raw_line.strip()
    if not line:
        continue
    url, _, comment = line.partition("|")
    if has_comment:
        cur.execute(
            "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES (?, 1, ?)",
            (url, comment),
        )
    else:
        cur.execute(
            "INSERT OR IGNORE INTO adlist (address, enabled) VALUES (?, 1)",
            (url,),
        )
    if cur.rowcount > 0:
        print(f"  \033[0;32m+ Dodano:\033[0m {url}")
        added += 1
    else:
        print(f"  \033[1;33m= Już istniała:\033[0m {url}")
        skipped += 1

conn.commit()
conn.close()
print(f"\nPodsumowanie dodawania: nowe={added}, pominięte (duplikaty)={skipped}")
PYEOF

echo ""
echo -e "${BLUE}[*] Dodawanie blocklist do bazy ${GRAVITY_DB}...${NC}"

if [[ "$DB_ENGINE" == "ftl_sqlite" || "$DB_ENGINE" == "container_sqlite" ]]; then
    SQLITE_CMD=("sqlite3")
    [[ "$DB_ENGINE" == "ftl_sqlite" ]] && SQLITE_CMD=("pihole-FTL" "sqlite3")

    HAS_COMMENT_COL=$($DOCKER_BIN exec "$CONTAINER_NAME" "${SQLITE_CMD[@]}" "$GRAVITY_DB" \
        "SELECT COUNT(*) FROM pragma_table_info('adlist') WHERE name='comment';")

    ADDED_COUNT=0
    SKIPPED_COUNT=0

    for entry in "${SELECTED_ENTRIES[@]}"; do
        URL="${entry%%|*}"
        COMMENT="${entry#*|}"
        SQL_URL="${URL//\'/\'\'}"
        SQL_COMMENT="${COMMENT//\'/\'\'}"

        if [[ "$HAS_COMMENT_COL" -ge 1 ]]; then
            SQL="INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('${SQL_URL}', 1, '${SQL_COMMENT}'); SELECT changes();"
        else
            SQL="INSERT OR IGNORE INTO adlist (address, enabled) VALUES ('${SQL_URL}', 1); SELECT changes();"
        fi

        CHANGED=$($DOCKER_BIN exec "$CONTAINER_NAME" "${SQLITE_CMD[@]}" "$GRAVITY_DB" "$SQL" | tail -n 1)

        if [[ "$CHANGED" == "1" ]]; then
            echo -e "  ${GREEN}+ Dodano:${NC} ${URL}"
            ADDED_COUNT=$((ADDED_COUNT + 1))
        else
            echo -e "  ${YELLOW}= Już istniała:${NC} ${URL}"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        fi
    done

    echo ""
    echo -e "Podsumowanie dodawania: nowe=${ADDED_COUNT}, pominięte (duplikaty)=${SKIPPED_COUNT}"

elif [[ "$DB_ENGINE" == "container_python" ]]; then
    printf '%s\n' "${SELECTED_ENTRIES[@]}" | \
        $DOCKER_BIN exec -i "$CONTAINER_NAME" python3 -c "$PY_INSERT_SCRIPT" "$GRAVITY_DB"

elif [[ "$DB_ENGINE" == "host_python" ]]; then
    TMP_DB=$(mktemp /tmp/pihole_gravity_XXXXXX.db)
    trap 'rm -f "$TMP_DB"' EXIT

    ORIG_OWNER=$($DOCKER_BIN exec "$CONTAINER_NAME" stat -c '%u:%g' "$GRAVITY_DB" 2>/dev/null || echo "")
    $DOCKER_BIN cp "${CONTAINER_NAME}:${GRAVITY_DB}" "$TMP_DB"

    printf '%s\n' "${SELECTED_ENTRIES[@]}" | python3 -c "$PY_INSERT_SCRIPT" "$TMP_DB"

    $DOCKER_BIN cp "$TMP_DB" "${CONTAINER_NAME}:${GRAVITY_DB}"
    if [[ -n "$ORIG_OWNER" ]]; then
        $DOCKER_BIN exec -u 0 "$CONTAINER_NAME" chown "$ORIG_OWNER" "$GRAVITY_DB" || true
    fi
    rm -f "$TMP_DB"
fi

# Aktualizacja Gravity w Pi-hole
echo ""
read -rp "Uruchomić teraz 'pihole -g' aby pobrać i zaktualizować listy? [T/n]: " RUN_GRAVITY
if [[ "${RUN_GRAVITY,,}" != "n" ]]; then
    echo -e "${BLUE}[*] Aktualizacja bazy gravity w kontenerze '${CONTAINER_NAME}' (może potrwać kilkadziesiąt sekund)...${NC}"
    $DOCKER_BIN exec "$CONTAINER_NAME" pihole -g
    echo -e "${GREEN}[+] Aktualizacja gravity zakończona.${NC}"
else
    echo -e "${YELLOW}[!] Pamiętaj, aby później uruchomić: docker exec ${CONTAINER_NAME} pihole -g${NC}"
fi
