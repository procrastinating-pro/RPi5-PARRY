# 🍓 RPi5-PARRY (Raspberry Pi 5 Headless + Docker HomeLab + NAS + Auto-Maintenance)

Zestaw automatycznych i interaktywnych skryptów Bash pozwalających na szybkie przygotowanie czystego obrazu **Raspberry Pi OS (64-bit)** pod Raspberry Pi 5 (wraz z obsługą **NVMe HAT+**), bezobsługową aktualizację systemu, optymalizację krzywej chłodzenia (**Active Cooler + NVMe Heatsink Guard**), instalację **Dockera** oraz modułowe wdrożenie domowego serwera **HomeLab & NAS** (**Pi-hole**, **Samba**, **FileBrowser**, **Twingate**, **Vaultwarden**, **Gitea**, **Caddy HTTPS**, **Watchtower**).

## 🛠️ Sprzęt użyty w projekcie (Hardware)

Projekt został zaprojektowany i zoptymalizowany pod kątem następującej konfiguracji sprzętowej:

* **Płyta główna:** Raspberry Pi 5

* **Adapter PCIe:** Raspberry Pi M.2 HAT+

* **Dysk systemowy i NAS:** Raspberry Pi SSD (NVMe PCIe Gen 3) + dodatkowe radiatory chłodzące na dysku

* **Chłodzenie procesora i obudowy:** Raspberry Pi Active Cooler (sterowany hybrydowo na podstawie temperatury CPU oraz czujnika S.M.A.R.T. dysku NVMe)

* **Zasilanie:** Oficjalny zasilacz Raspberry Pi 27W USB-C PD (5.1V / 5A)

* **Obudowa:** Dedykowana, podwyższona obudowa drukowana w 3D (projekt parametryczny w OpenSCAD mieszczący M.2 HAT+, wysokie radiatory na NVMe, uniesioną nakładkę z logo *Badge* oraz wciskane nóżki z TPU)

## 📂 Zawartość repozytorium

| Plik / Skrypt | Gdzie uruchamiać? | Opis działania | 
| ----- | ----- | ----- | 
| **`rpi5_configurator.sh`** | 💻 Na komputerze (np. Ubuntu) z podłączonym nośnikiem (SD/NVMe) | Konfiguruje czysty obraz przed pierwszym uruchomieniem: włącza SSH, tworzy użytkownika, wgrywa klucz SSH, ustawia statyczny IP (NetworkManager) i odblokowuje PCIe Gen 3 dla NVMe HAT+. | 
| **`install_docker.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Aktualizuje system, włącza `fstrim.timer` dla NVMe, ustawia codzienny Auto-Update/Clean w Cronie (03:30), instaluje **Docker Engine** oraz **Docker Compose v2** (z pominięciem, jeśli jest już zainstalowany) i konfiguruje rotację logów. | 
| **`setup_homelab.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Interaktywny kreator podstawowych usług HomeLab (Czysty Bash `[T/n]`, katalog `~/docker/homelab`): **Pi-hole**, **Samba (SMB)**, **FileBrowser**, **Twingate Connector**, **Vaultwarden**, **Gitea (+ PostgreSQL)**, **Caddy Reverse Proxy (lokalny HTTPS dla `.home`)** oraz **Watchtower** (auto-update o 04:00). | 
| **`add_pihole_blocklists.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Interaktywny konfigurator list blokowania (Blocklist) dla kontenera Docker Pi-hole: dodaje gotowe pakiety **HaGeZi** (Multi PRO / PRO++ / Ultimate + TIF w formacie RPZ) chroniące przed reklamami, telemetrią, **malware** oraz **phishingiem**, a także klasyczny zestaw lub własne adresy URL do `gravity.db` (z automatycznym backupem, wykrywaniem silnika `pihole-FTL sqlite3`/`sqlite3`/`python3` i aktualizacją `pihole -g`). | 
| **`uninstall_homelab.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Bezpieczny deinstalator z podwójnym potwierdzeniem: usuwa kontenery HomeLab & NAS, nieużywane sieci/obrazy i katalog konfiguracyjny `~/docker/homelab`, przywraca `systemd-resolved` oraz opcjonalnie usuwa dane na dysku NAS (`/srv/nas/pliki`). | 
| **`setup_cooler.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Konfigurator chłodzenia **Active Cooler**: ustawia krzywą wentylatora w `config.txt`, instaluje usługę `nvme-fan-guard` (przyspieszającą wentylator, gdy dysk NVMe z radiatorem nagrzewa się podczas transferów NAS) oraz dodaje polecenie diagnostyczne `rpi-temp`. | 
| **`diagnose_and_fix_fan.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Narzędzie diagnostyczno-naprawcze dla **Active Coolera**: skanuje partycje `bootfs` oraz `rootfs` (w tym konflikty SD vs NVMe), czyści błędne reguły `udev`/`systemd`, przywraca czystą konfigurację w `config.txt` i wykonuje sprzętowy test linii PWM (`0` vs `255`). | 
| **`rpi5_nvme_case.scad`** | 💻 Na komputerze (OpenSCAD) | Parametryczny model 3D podwyższonej obudowy z miejscem na M.2 HAT+, radiatory NVMe, przedłużoną komorą na taśmę PCIe, uniesionym dachem z logo (*Badge*) oraz nóżkami dystansowymi pod druk z elastycznego TPU. | 

## 🚀 Krok 1: Przygotowanie nośnika przed pierwszym startem (`rpi5_configurator.sh`)

Zamiast korzystać z wbudowanego kreatora w Raspberry Pi Imagerze (który bywa zawodny), wgraj czysty obraz **Raspberry Pi OS Lite (64-bit)** na kartę SD lub dysk NVMe (wybierając **NO** przy pytaniu o *OS customisation*).

1. Wyjmij i ponownie podłącz nośnik do komputera, aby system zamontował partycje **`bootfs`** oraz **`rootfs`**.

2. Uruchom interaktywny konfigurator bezpośrednio z terminala:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/procrastinating-pro/RPi5-PARRY/refs/heads/main/rpi5_configurator.sh)
```

**Co możesz skonfigurować w kreatorze:**

* Aktywację serwera SSH (`bootfs/ssh`).

* Utworzenie nowego konta użytkownika i zaszyfrowanego hasła (`userconf.txt`).

* Automatyczne skopiowanie Twojego klucza publicznego (`~/.ssh/id_ed25519.pub` lub `id_rsa.pub`) dla logowania bez hasła.

* Ustawienie statycznego adresu IP dla portu LAN (`eth0`) – domyślnie `192.168.1.250/24`.

* Włączenie obsługi **Raspberry Pi NVMe HAT+** (`dtparam=pciex1`) oraz wymuszenie szybszego trybu **PCIe Gen 3** (`dtparam=pciex1_gen=3`).

* Zmianę nazwy hosta (`hostname`).

3. Po zakończeniu pracy skryptu odmontuj partycje, przełóż nośnik do Raspberry Pi 5, podłącz kabel LAN oraz zasilanie:

```bash
sudo umount /media/$USER/bootfs /media/$USER/rootfs
```

4. Po około 60–90 sekundach połącz się z płytką przez SSH:

```bash
ssh twoj_login@192.168.1.250
```

*(Jeśli musisz zlokalizować płytkę w sieci lokalnej, użyj szybkiego skanowania Nmap dla portu SSH):*

```bash
nmap -p 22 -T4 -n 192.168.1.0/24 --open
```

## 🐳 Krok 2: Instalacja Dockera i Auto-Maintenance (`install_docker.sh`)

Po zalogowaniu się na Raspberry Pi 5 przez SSH zainstaluj środowisko Docker, Docker Compose v2 oraz harmonogram automatycznej konserwacji systemu jedną komendą:

```bash
curl -fsSL https://raw.githubusercontent.com/procrastinating-pro/RPi5-PARRY/refs/heads/main/install_docker.sh | bash && newgrp docker
```

**Co robi skrypt:**

* Wykonuje pełną, bezobsługową aktualizację systemu (`full-upgrade`, `autoremove`, `autoclean`).

* Tworzy zadanie w `/etc/cron.d/auto-system-maintenance`, które **codziennie o 03:30 w nocy** aktualizuje pakiety systemowe, czyści zbędne zależności i usuwa nieużywane obrazy Dockera (`docker image prune -af`), zapisując pełny przebieg ze znacznikami czasu do `/var/log/auto-update.log`.

* Aktywuje usługę `fstrim.timer` dbającą o kondycję i wydajność dysku NVMe.

* Sprawdza, czy Docker jest już zainstalowany – jeśli nie, dodaje oficjalny klucz GPG i repozytorium Dockera dla architektury `arm64`, po czym instaluje pakiety `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin` oraz `docker-compose-plugin`.

* Konfiguruje plik `/etc/docker/daemon.json` z limitem rozmiaru logów (`max-size: 10m`, `max-file: 3`), co chroni dysk przed zapełnieniem.

* Dodaje bieżącego użytkownika do grupy `docker` (jeśli jeszcze do niej nie należy).

*Weryfikacja poprawności instalacji:*

```bash
docker run --rm hello-world
```

## 🛡️ Krok 3: Instalacja usług HomeLab & NAS (`setup_homelab.sh`)

### 🔑 Przed uruchomieniem: Przygotowanie tokenów Twingate (opcjonalnie)

Jeśli planujesz uruchomić zdalny dostęp **Twingate Connector**, wygeneruj tokeny **zanim** odpalisz `setup_homelab.sh` – kreator poprosi o ich wklejenie w trakcie instalacji:

1. Zaloguj się do panelu administracyjnego **`admin.twingate.com`**.

2. Przejdź do *Network → Remote Networks*, kliknij **Add a Remote Network**, nazwij sieć (np. `HomeLab` lub `Dom`) i wybierz lokalizację **On-Premise**.

3. Wejdź w utworzoną sieć, kliknij **Deploy Connector** i jako metodę wdrożenia wybierz **Docker**.

4. Kliknij **Generate Tokens** i pozostaw otwartą kartę z trzema wartościami, o które zapyta skrypt:

   * nazwą sieci (`TWINGATE_NETWORK` – np. `twojanazwa` z adresu `twojanazwa.twingate.com`),

   * `TWINGATE_ACCESS_TOKEN`,

   * `TWINGATE_REFRESH_TOKEN`.

### 🚀 Uruchomienie kreatora `setup_homelab.sh`

Aby uruchomić podstawowe usługi domowego serwera (z możliwością wyboru `[T/n]` dla każdego kontenera), wykonaj na Raspberry Pi 5:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/procrastinating-pro/RPi5-PARRY/refs/heads/main/setup_homelab.sh)
```

*(Uwaga: Użycie składni `bash <(curl ...)` jest wymagane, ponieważ skrypt działa interaktywnie i pobiera od Ciebie wybór kontenerów, hasła, tokeny oraz ścieżki z klawiatury).*

**Dostępne kontenery do wyboru w kreatorze `[1/7 – 7/7 + Extra]`:**

1. **Pi-hole:** Blokowanie reklam w całej sieci LAN oraz lokalny serwer DNS (automatycznie zwalnia port `53` z `systemd-resolved` i konfiguruje lokalne domeny `.home`).

2. **Samba NAS:** Dysk sieciowy SMB/CIFS widoczny w systemach Windows, Linux oraz macOS.

3. **FileBrowser:** Nowoczesny menedżer plików NAS przez przeglądarkę WWW (automatycznie inicjalizuje bazę i tworzy konto administratora z hasłem o dł. min. 12 znaków).

4. **Twingate Connector:** Bezpieczny, zdalny dostęp Zero-Trust spoza domu w trybie `network_mode: host` (bez konieczności przekierowywania portów na routerze i z pełną obsługą lokalnych domen `.home`).

5. **Vaultwarden:** Lekki, lokalny serwer menedżera haseł kompatybilny z oficjalnymi aplikacjami Bitwarden (przy włączonym Caddy automatycznie korzysta z `https://vault.home` wymaganego przez WebCrypto).

6. **Gitea + PostgreSQL:** Lekki, lokalny serwer Git (self-hosted alternatywa dla GitHuba/GitLaba) z dedykowaną bazą **PostgreSQL 16**, trwale zapisywanym hasłem bazy (`~/docker/homelab/gitea/.db_pass`) oraz obsługą klonowania po HTTPS/HTTP (`3000`) i SSH (`2222`).

7. **Caddy Reverse Proxy (Lokalny HTTPS):** Automatycznie generuje `Caddyfile` dla wszystkich wybranych usług i udostępnia je po szyfrowanym połączeniu **HTTPS** bez wpisywania numerów portów (`https://pihole.home`, `https://nas.home`, `https://vault.home`, `https://git.home`), wykorzystując wbudowane lokalne CA (`tls internal`). Po uruchomieniu eksportuje certyfikat `homelab-root-ca.crt` do `~/docker/homelab/caddy/` oraz na dysk NAS (`/srv/nas/pliki/`).

* **\[Extra\] Watchtower:** Automatyczna aktualizacja wszystkich uruchomionych kontenerów i czyszczenie starych obrazów codziennie o 04:00 rano (z wymuszonym `DOCKER_API_VERSION=1.44`).

### 🔒 Lokalny HTTPS (Caddy) – jednorazowa instalacja certyfikatu CA

Ponieważ Caddy wystawia certyfikaty dla lokalnych domen `.home` z własnego, lokalnego urzędu certyfikacji (`tls internal`), wystarczy **raz** dodać plik `homelab-root-ca.crt` (dostępny w `~/docker/homelab/caddy/homelab-root-ca.crt` oraz bezpośrednio w `/srv/nas/pliki/homelab-root-ca.crt`) do zaufanych na swoich urządzeniach – dzięki temu znikną ostrzeżenia w przeglądarce i poprawnie zadziałają aplikacje Bitwarden/Vaultwarden:

* **Ubuntu / Debian:**
  ```bash
  sudo cp homelab-root-ca.crt /usr/local/share/ca-certificates/
  sudo update-ca-certificates
  ```
  *(W Chrome/Firefox dodatkowo: Ustawienia → Certyfikaty → Urzędy certyfikacji → Importuj → zaznacz zaufanie dla witryn).*

* **Windows:** Kliknij dwukrotnie `homelab-root-ca.crt` → *Zainstaluj certyfikat* → *Komputer lokalny* → *Umieść wszystkie certyfikaty w następującym magazynie* → **Zaufane główne urzędy certyfikacji**.

* **Android:** Pobierz plik (np. przez FileBrowser) → *Ustawienia → Zabezpieczenia → Szyfrowanie i dane logowania → Zainstaluj certyfikat → Certyfikat CA* → wskaż `homelab-root-ca.crt`.

* **iOS:** Pobierz plik na telefon, zainstaluj profil w *Ustawienia → Ogólne → VPN i zarządzanie urządzeniami*, a następnie włącz pełne zaufanie w *Ustawienia → Ogólne → To urządzenie → Ustawienia zaufania certyfikatów*.

### 🧱 Dodawanie list blokowania (Blocklist) do Pi-hole (`add_pihole_blocklists.sh`)

Po uruchomieniu kontenera **Pi-hole** możesz jednym poleceniem dodać sprawdzone listy blokujące reklamy, telemetrię, **malware** oraz **phishing** (z opcjonalną kopią zapasową bazy `gravity.db` w `~/pihole_backups` przed zmianami):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/procrastinating-pro/RPi5-PARRY/refs/heads/main/add_pihole_blocklists.sh)
```

**Dostępne profile w konfiguratorze:**

1. **HaGeZi Multi PRO + TIF (`pro` + `tif-1` + `tif-2`, format RPZ) *(zalecane)*** – optymalna ochrona przed reklamami, telemetrią, malware i phishingiem przy minimalnej liczbie błędnych blokad.

2. **HaGeZi Multi PRO + TIF Medium** – lżejszy wariant listy Threat Intelligence Feeds.

3. **HaGeZi Multi PRO++ + TIF (`pro.plus` + `tif-1` + `tif-2`)** – bardziej agresywne blokowanie reklam i trackerów.

4. **HaGeZi Ultimate + TIF (`ultimate` + `tif-1` + `tif-2`)** – maksymalny poziom blokowania (może wymagać ręcznego dodawania wyjątków do białej listy).

5. **Klasyczny zestaw** – StevenBlack Unified Hosts, AdGuard DNS Filter, Firebog (AdGuardDNS, EasyList, EasyPrivacy) oraz Perflyst SmartTV.

6. **Własna lista adresów URL** – ręczne podanie dowolnych linków do list blokowania.

Skrypt automatycznie wykrywa dostępne narzędzie do edycji `gravity.db` (`pihole-FTL sqlite3`, `sqlite3`, `python3` w kontenerze lub `python3` na hoście), pomija duplikaty i na końcu uruchamia `pihole -g`.

### ⚠️ Ważne: Konfiguracja DNS na routerze

Aby blokowanie reklam przez **Pi-hole** oraz lokalne domeny (`.home`) działały automatycznie na wszystkich urządzeniach w domu (telefonach, telewizorach, komputerach):

1. Zaloguj się do panelu administracyjnego swojego routera.

2. Przejdź do ustawień sieci lokalnej (**LAN / DHCP Server**).

3. Jako **Podstawowy serwer DNS (Primary DNS)** wpisz statyczny adres IP swojego Raspberry Pi (domyślnie `192.168.1.250`).

4. Pole **Zapasowy serwer DNS (Secondary DNS)** pozostaw **puste** (jeśli wpiszesz tam np. `8.8.8.8` lub `1.1.1.1`, część zapytań ominie Pi-hole, reklamy będą się wyświetlać, a lokalne domeny `nas.home` nie będą działać).

5. Zapisz ustawienia i zrestartuj połączenie Wi-Fi/LAN na urządzeniach, aby pobrały nową konfigurację z routera.

### 🌍 Lokalne domeny DNS (Konfiguracja w `docker-compose.yml`)

Skrypt `setup_homelab.sh` automatycznie pyta o lokalne domeny podczas instalacji Pi-hole (domyślnie: `nas.home pihole.home rpi.home vault.home git.home`) i dopisuje je bezpośrednio do pliku `~/docker/homelab/docker-compose.yml`.

Jeśli w przyszłości zechcesz dodać kolejne własne domeny, wystarczy wyedytować plik `~/docker/homelab/docker-compose.yml` (sekcja `extra_hosts` oraz `FTLCONF_dns_hosts` rozdzielone średnikiem w usłudze `pihole`) i przeładować kontenery komendą `docker compose up -d`.

*(Wskazówka: Używaj końcówek `.home`, `.lan` lub `.internal`. Unikaj końcówki `.local`, która jest zarezerwowana dla protokołu mDNS/Avahi i może powodować opóźnienia).*

### 🔐 Dokończenie konfiguracji Twingate (po uruchomieniu kontenerów)

Gdy `setup_homelab.sh` uruchomi już kontener `twingate-connector`, dokończ konfigurację zdalnego dostępu w panelu **`admin.twingate.com`**:

1. **Weryfikacja Connectora:**

   * Sprawdź, czy status Connectora w panelu zmienił się na zielony (**Connected**). Lokalnie połączenie zweryfikujesz komendą `sudo docker logs twingate-connector`.

2. **Resources (Zasoby dostępne zdalnie):**

   * W ustawieniach swojej sieci kliknij **Add Resource** i dodaj (przypisując dostęp grupie **Everyone** lub własnej):

     * **Serwer RPi 5 / sieć LAN:** adres `192.168.1.250` (tylko Raspberry Pi) lub `192.168.1.0/24` (cała sieć domowa, np. panel routera).

     * **Lokalne domeny `.home`:** adres `*.home` – dzięki pracy w trybie `network_mode: host` Connector odpytuje lokalnego Pi-hole'a i rozwiązuje `nas.home`, `pihole.home`, `vault.home` oraz `git.home`.

3. **Klient na telefonie / laptopie:**

   * Zainstaluj aplikację **Twingate**, zaloguj się do swojej sieci (`twojanazwa.twingate.com`), przełącz telefon na dane komórkowe i sprawdź dostęp np. do `https://nas.home` lub `https://pihole.home/admin` (albo po IP: `http://192.168.1.250:8081`).

*(Wskazówka: Jeśli domeny `*.home` nie rozwiązują się zdalnie, sprawdź w `/etc/resolv.conf` na Raspberry Pi, czy jako serwer DNS wpisany jest `127.0.0.1` lub `192.168.1.250`).*

## ❄️ Krok 4: Optymalizacja chłodzenia Active Cooler i NVMe (`setup_cooler.sh`)

W zamkniętej obudowie z nakładką M.2 HAT+ i radiatorami na dysku SSD Gen 3 domyślna krzywa wentylatora (start od 50°C CPU) jest zbyt pasywna. Aby zapewnić optymalny obieg powietrza wokół radiatora NVMe oraz cichą pracę, uruchom konfigurator chłodzenia:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/procrastinating-pro/RPi5-PARRY/refs/heads/main/setup_cooler.sh)
```

**Co robi skrypt:**

* Ustawia w `/boot/firmware/config.txt` zoptymalizowaną krzywą dla **Raspberry Pi Active Cooler**.

* Instaluje pakiet `nvme-cli` oraz usługę systemową `nvme-fan-guard.service`, która odczytuje temperaturę dysku SSD i automatycznie reguluje obroty wentylatora podczas dużych transferów plików przez NAS (nawet gdy sam procesor RPi 5 jest chłodny).

* Tworzy polecenie diagnostyczne `rpi-temp`, pozwalające w dowolnej chwili sprawdzić temperatury oraz obroty wentylatora.

## 🌐 Dostęp do usług po instalacji

Przy założeniu domyślnego adresu IP `192.168.1.250`, domyślnych domen `.home` oraz włączonego **Caddy (HTTPS)**:

| Usługa | Adres HTTPS (Caddy) | Adres bezpośredni HTTP / SMB | Domyślne logowanie / Uwagi | 
| ----- | ----- | ----- | ----- | 
| **Pi-hole** | `https://pihole.home/admin` | `http://192.168.1.250:8080/admin` | Hasło podane w konfiguratorze Pi-hole. | 
| **FileBrowser** | `https://nas.home` | `http://192.168.1.250:8081` | Login: `admin` + własne hasło (min. 12 znaków). | 
| **Vaultwarden** | `https://vault.home` | `http://192.168.1.250:8222` | Utwórz konto przez `https://vault.home` (HTTPS wymagane przez WebCrypto). | 
| **Gitea** | `https://git.home` | `http://192.168.1.250:3000` | SSH: port `2222`. Przy pierwszym wejściu kliknij *Zainstaluj Gitea* (dane PostgreSQL są już uzupełnione). | 
| **Samba NAS (SMB)** | — | Linux: `smb://nas.home/DyskNAS` / Windows: `\\nas.home\DyskNAS` | Login i hasło Samby podane w konfiguratorze. | 
| **Caddy (HTTPS)** | Porty `80` i `443` | — | Certyfikat CA do pobrania: `/srv/nas/pliki/homelab-root-ca.crt`. | 
| **Twingate** | Działa w tle (`network_mode: host`) | — | Logi połączenia: `sudo docker logs twingate-connector`. | 
| **Watchtower** | Działa w tle (harmonogram Cron `04:00`) | — | Logi aktualizacji: `sudo docker logs watchtower`. | 

## 🗑️ Deinstalacja i czyszczenie środowiska (`uninstall_homelab.sh`)

Jeśli chcesz zresetować środowisko HomeLab & NAS, usunąć kontenery oraz konfigurację i zacząć od czystego stanu, uruchom skrypt deinstalacyjny:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/procrastinating-pro/RPi5-PARRY/refs/heads/main/uninstall_homelab.sh)
```

**Zabezpieczenia deinstalatora:**

1. **Potwierdzenie usunięcia kontenerów (`TAK`):** Skrypt zatrzymuje i usuwa kontenery z `~/docker/homelab` (`docker compose down -v`), czyści nieużywane sieci i obrazy (`docker image prune -a -f`), usuwa katalog konfiguracyjny oraz przywraca domyślną konfigurację `systemd-resolved` (port `53`).

2. **Ochrona danych na dysku NAS (`USUN_DANE`):** Pliki w `/srv/nas/pliki` są domyślnie **chronione** – ich wykasowanie wymaga osobnego, jawnego potwierdzenia frazą `USUN_DANE`.

## 🛠️ Przydatne komendy diagnostyczne

* **Sprawdzenie temperatury CPU, dysku NVMe oraz obrotów Active Coolera:**

```bash
rpi-temp
# lub podgląd na żywo co 2 sekundy:
watch -n 2 rpi-temp
```

* **Pełna diagnostyka i reset konfiguracji wentylatora (w przypadku pracy na 100% obrotów):**
  Jeśli wentylator nie reaguje na zmiany temperatury, uruchom skrypt diagnostyczny, który przeskanuje partycje `bootfs` i `rootfs`, usunie konflikty i przetestuje sprzętowo linię PWM (`PWM=0` vs `PWM=255`):

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/procrastinating-pro/RPi5-PARRY/refs/heads/main/diagnose_and_fix_fan.sh)
```

* **Sprawdzenie czy nocny Auto-Update systemu (03:30) został przeprowadzony:**

```bash
# 1. Podgląd pełnego logu z nocnej aktualizacji (update, full-upgrade, autoremove, autoclean, docker prune):
tail -n 50 /var/log/auto-update.log

# 2. Sprawdzenie w logach systemowych (journalctl), czy zadanie Cron wystartowało punktualnie o 03:30:
sudo journalctl --since "03:29:00" --until "03:45:00" | grep -iE "cron|apt|upgrade|autoremove|autoclean"

# 3. Historia faktycznie zaktualizowanych lub usuniętych pakietów APT:
tail -n 30 /var/log/apt/history.log
```

* **Sprawdzenie czy aktualizacja kontenerów Docker (Watchtower o 04:00) została przeprowadzona:**

```bash
# 1. Logi działania kontenera Watchtower:
docker logs watchtower

# 2. Sprawdzenie dokładnej daty utworzenia/aktualizacji poszczególnych kontenerów:
docker inspect --format='{{.Name}} -> Utworzony: {{.Created}}' $(docker ps -a -q)

# 3. Ręczne wymuszenie natychmiastowego sprawdzenia i aktualizacji wszystkich kontenerów (test jednorazowy):
sudo docker run --rm -e DOCKER_API_VERSION=1.44 -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --run-once
```

* **Sprawdzenie statusu uruchomionych kontenerów:**

```bash
docker ps
```

* **Podgląd logów poszczególnych kontenerów:**

```bash
docker logs pihole
docker logs samba-nas
docker logs filebrowser-nas
docker logs vaultwarden
docker logs gitea
docker logs gitea-db
docker logs caddy
docker logs twingate-connector
```

* **Restart lub zatrzymanie usług:**

```bash
cd ~/docker/homelab
docker compose restart   # lub: docker compose down
```

* **Ręczna zmiana hasła do FileBrowsera z poziomu terminala:**

```bash
cd ~/docker/homelab
docker compose stop filebrowser
docker compose run --rm filebrowser users update admin --password "TwojeNoweHaslo123" --database /database/filebrowser.db
docker compose start filebrowser
```

## 💰 Szacowane oszczędności i zwrot z inwestycji (ROI w domu)

W warunkach domowych wdrożenie zestawu na Raspberry Pi 5 pozwala ograniczyć stałe opłaty za subskrypcje w chmurze i serwisy zewnętrzne o ok. **620 – 970 PLN rocznie**.

| Usługa w domu | Komercyjny odpowiednik | Zestaw na RPi 5 | Roczna oszczędność | 
| ----- | ----- | ----- | ----- | 
| **Chmura na pliki i zdjęcia (2 TB)** | Google One / iCloud+ (~47–50 PLN/mies.) | **Samba + FileBrowser** (0 PLN) | **560 – 600 PLN** | 
| **Menedżer haseł** | Bitwarden Premium / 1Password (~50–240 PLN/rok) | **Vaultwarden** (0 PLN) | **50 – 240 PLN** | 
| **Ochrona DNS i zdalny dostęp** | NextDNS Pro / AdGuard / płatny VPN (~80–200 PLN/rok) | **Pi-hole + Twingate** (darmowy do 5 osób) | **80 – 200 PLN** | 
| **Energia elektryczna (24/7)** | 0 PLN (w chmurze) | **RPi 5** (~6–7 W ≈ 60 kWh/rok) | **-70 PLN** *(koszt)* | 
| **RAZEM** | **~690 – 1 040 PLN / rok** | **~70 PLN / rok** | **~620 – 970 PLN / rok** | 

**Szacowany czas zwrotu sprzętu** (przy koszcie zakupu brutto RPi 5, M.2 HAT+, dysku NVMe 1–2 TB, Active Coolera i zasilacza 27W na poziomie ok. **1 100 – 1 400 PLN**):

* **HomeLab & NAS:** zwrot po **1,5 – 2 latach**.

* **Dodatkowa oszczędność na prądzie:** jeśli RPi 5 zastępuje w domu starszy serwer/PC x86 działający 24/7 (ok. 50 W ≈ 500 PLN/rok), sama zmiana platformy oszczędza dodatkowe **~430 PLN rocznie** na energii elektrycznej.

*(Wskazówka: Ponieważ zestaw pracuje na pojedynczym dysku NVMe, najważniejsze pliki z `/srv/nas/pliki` warto okresowo kopiować na zewnętrzny dysk USB zgodnie z zasadą backupu 3-2-1).*

## 📄 Licencja

Projekt jest udostępniany na warunkach licencji **MIT**. Szczegółowe informacje znajdują się w pliku [LICENSE.md](LICENSE.md).