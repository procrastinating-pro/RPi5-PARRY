# 🍓 RPi5-PARRY (Raspberry Pi 5 Headless + Docker HomeLab + NAS + Media Stack + Auto-Maintenance)

Zestaw automatycznych i interaktywnych skryptów Bash pozwalających na szybkie przygotowanie czystego obrazu **Raspberry Pi OS (64-bit)** pod Raspberry Pi 5 (wraz z obsługą **NVMe HAT+**), bezobsługową aktualizację systemu, optymalizację krzywej chłodzenia (**Active Cooler + NVMe Heatsink Guard**), instalację **Dockera** oraz modułowe wdrożenie domowego serwera **HomeLab & NAS** (**Pi-hole**, **Samba**, **FileBrowser**, **Twingate**, **Vaultwarden**, **Gitea**, **Watchtower**) oraz opcjonalnego, odizolowanego **Media Stacka** (**Jellyfin**, **qBittorrent**, **Prowlarr**, **Sonarr**, **Radarr**, **Bazarr**).

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
| **`setup_homelab.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Interaktywny kreator podstawowych usług HomeLab (Czysty Bash `[T/n]`, katalog `~/docker/homelab`): **Pi-hole**, **Samba (SMB)**, **FileBrowser**, **Twingate Connector**, **Vaultwarden**, **Gitea (+ PostgreSQL)** oraz **Watchtower** (auto-update o 04:00). | 
| **`add_pihole_blocklists.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Interaktywny konfigurator list blokowania (Blocklist) dla kontenera Docker Pi-hole: dodaje gotowe pakiety **HaGeZi** (Multi PRO / PRO++ / Ultimate + TIF w formacie RPZ) chroniące przed reklamami, telemetrią, **malware** oraz **phishingiem**, a także klasyczny zestaw lub własne adresy URL do `gravity.db` (z automatycznym backupem, wykrywaniem silnika `pihole-FTL sqlite3`/`sqlite3`/`python3` i aktualizacją `pihole -g`). | 
| **`setup_mediastack.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Opcjonalny, niezależny kreator **Media Stacka** (Czysty Bash `[T/n]`, katalog `~/docker/mediastack`): **Jellyfin**, **qBittorrent** (z wbudowanym powiadomieniem prawnym P2P i potwierdzeniem `[t/N]`), **Prowlarr**, **Sonarr**, **Radarr** i **Bazarr** w układzie hardlinków. | 
| **`uninstall_homelab.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Bezpieczny deinstalator z menu wyboru zakresu (**tylko HomeLab & NAS**, **tylko Media Stack** lub **oba środowiska**) i podwójnym potwierdzeniem: usuwa wybrane kontenery, nieużywane sieci/obrazy i katalogi konfiguracyjne, przywraca `systemd-resolved` (przy usuwaniu HomeLaba) oraz opcjonalnie usuwa dane na dysku NAS (`/srv/nas/pliki` lub samo `/media` i `/downloads`). | 
| **`setup_cooler.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Konfigurator chłodzenia **Active Cooler**: ustawia krzywą wentylatora w `config.txt`, instaluje usługę `nvme-fan-guard` (przyspieszającą wentylator, gdy dysk NVMe z radiatorem nagrzewa się podczas transferów NAS) oraz dodaje polecenie diagnostyczne `rpi-temp`. | 
| **`diagnose_and_fix_fan.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Narzędzie diagnostyczno-naprawcze dla **Active Coolera**: skanuje partycje `bootfs` oraz `rootfs` (w tym konflikty SD vs NVMe), czyści błędne reguły `udev`/`systemd`, przywraca czystą konfigurację w `config.txt` i wykonuje sprzętowy test linii PWM (`0` vs `255`). | 
| **`rpi5_nvme_case.scad`** | 💻 Na komputerze (OpenSCAD) | Parametryczny model 3D podwyższonej obudowy z miejscem na M.2 HAT+, radiatory NVMe, przedłużoną komorą na taśmę PCIe, uniesionym dachem z logo (*Badge*) oraz nóżkami dystansowymi pod druk z elastycznego TPU. | 

## 🚀 Krok 1: Przygotowanie nośnika przed pierwszym startem (`rpi5_configurator.sh`)

Zamiast korzystać z wbudowanego kreatora w Raspberry Pi Imagerze (który bywa zawodny), wgraj czysty obraz **Raspberry Pi OS Lite (64-bit)** na kartę SD lub dysk NVMe (wybierając **NO** przy pytaniu o *OS customisation*).

1. Wyjmij i ponownie podłącz nośnik do komputera, aby system zamontował partycje **`bootfs`** oraz **`rootfs`**.

2. Uruchom interaktywny konfigurator bezpośrednio z terminala:

```
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

```
sudo umount /media/$USER/bootfs /media/$USER/rootfs

```

4. Po około 60–90 sekundach połącz się z płytką przez SSH:

```
ssh twoj_login@192.168.1.250

```

*(Jeśli musisz zlokalizować płytkę w sieci lokalnej, użyj szybkiego skanowania Nmap dla portu SSH):*

```
nmap -p 22 -T4 -n 192.168.1.0/24 --open

```

## 🐳 Krok 2: Instalacja Dockera i Auto-Maintenance (`install_docker.sh`)

Po zalogowaniu się na Raspberry Pi 5 przez SSH zainstaluj środowisko Docker, Docker Compose v2 oraz harmonogram automatycznej konserwacji systemu jedną komendą:

```
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

```
docker run --rm hello-world

```

## 🛡️ Krok 3: Instalacja usług HomeLab & NAS (`setup_homelab.sh`)

Aby uruchomić podstawowe usługi domowego serwera (z możliwością wyboru `[T/n]` dla każdego kontenera), wykonaj na Raspberry Pi 5:

```
bash <(curl -fsSL https://raw.githubusercontent.com/procrastinating-pro/RPi5-PARRY/refs/heads/main/setup_homelab.sh)

```

*(Uwaga: Użycie składni `bash <(curl ...)` jest wymagane, ponieważ skrypt działa interaktywnie i pobiera od Ciebie wybór kontenerów, hasła, tokeny oraz ścieżki z klawiatury).*

**Dostępne kontenery do wyboru w kreatorze `[1/6 – 6/6 + Extra]`:**

1. **Pi-hole:** Blokowanie reklam w całej sieci LAN oraz lokalny serwer DNS (automatycznie zwalnia port `53` z `systemd-resolved` i konfiguruje lokalne domeny `.home`).

2. **Samba NAS:** Dysk sieciowy SMB/CIFS widoczny w systemach Windows, Linux oraz macOS.

3. **FileBrowser:** Nowoczesny menedżer plików NAS przez przeglądarkę WWW (automatycznie inicjalizuje bazę i tworzy konto administratora z hasłem o dł. min. 12 znaków).

4. **Twingate Connector:** Bezpieczny, zdalny dostęp Zero-Trust spoza domu w trybie `network_mode: host` (bez konieczności przekierowywania portów na routerze i z pełną obsługą lokalnych domen `.home`).

5. **Vaultwarden:** Lekki, lokalny serwer menedżera haseł kompatybilny z oficjalnymi aplikacjami Bitwarden.

6. **Gitea + PostgreSQL:** Lekki, lokalny serwer Git (self-hosted alternatywa dla GitHuba/GitLaba) z dedykowaną bazą **PostgreSQL 16**, automatycznie generowanym hasłem bazy oraz obsługą klonowania po HTTP (`3000`) i SSH (`2222`).

* **\[Extra\] Watchtower:** Automatyczna aktualizacja wszystkich uruchomionych kontenerów (w tym opcjonalnego Media Stacka) i czyszczenie starych obrazów codziennie o 04:00 rano (z wymuszonym `DOCKER_API_VERSION=1.44`).

### 🧱 Dodawanie list blokowania (Blocklist) do Pi-hole (`add_pihole_blocklists.sh`)

Po uruchomieniu kontenera **Pi-hole** możesz jednym poleceniem dodać sprawdzone listy blokujące reklamy, telemetrię, **malware** oraz **phishing** (z opcjonalną kopią zapasową bazy `gravity.db` w `~/pihole_backups` przed zmianami):

```
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

Skrypt `setup_homelab.sh` automatycznie pyta o lokalne domeny podczas instalacji Pi-hole (domyślnie: `nas.home pihole.home rpi.home vault.home git.home`) i dopisuje je bezpośrednio do pliku `~/docker/homelab/docker-compose.yml`. Jeśli planujesz uruchomić również opcjonalny **Media Stack**, możesz od razu dopisać domenę `media.home` do tej listy.

Jeśli w przyszłości zechcesz dodać kolejne własne domeny, wystarczy wyedytować plik `~/docker/homelab/docker-compose.yml` (sekcja `extra_hosts` oraz `FTLCONF_dns_hosts` w usłudze `pihole`) i przeładować kontenery komendą `docker compose up -d`.

*(Wskazówka: Używaj końcówek `.home`, `.lan` lub `.internal`. Unikaj końcówki `.local`, która jest zarezerwowana dla protokołu mDNS/Avahi i może powodować opóźnienia).*

### 🔐 Konfiguracja Twingate (Onboarding i zdalny dostęp)

Aby połączyć się z HomeLabem spoza domu bez przekierowywania portów na routerze, wykonaj poniższe kroki w panelu administracyjnym **`admin.twingate.com`**:

1. **Remote Network (Sieć zdalna):**

   * Przejdź do *Network → Remote Networks* i kliknij **Add a Remote Network**.

   * Nazwij sieć dowolnie (np. `HomeLab` lub `Dom`) i wybierz lokalizację **On-Premise**.

2. **Connector i tokeny:**

   * Wejdź w utworzoną sieć, kliknij **Deploy Connector** i jako metodę wdrożenia wybierz **Docker**.

   * Kliknij **Generate Tokens**, aby uzyskać `TWINGATE_NETWORK` (np. `twojanazwa` z adresu `twojanazwa.twingate.com`), `TWINGATE_ACCESS_TOKEN` oraz `TWINGATE_REFRESH_TOKEN`.

   * Wklej je podczas uruchamiania `setup_homelab.sh` (lub dopisz w `~/docker/homelab/docker-compose.yml` / `.env` i wykonaj `docker compose up -d`).

   * Po chwili status Connectora zmieni się na zielony (**Connected**). Połączenie zweryfikujesz też komendą `sudo docker logs twingate-connector`.

3. **Resources (Zasoby dostępne zdalnie):**

   * W ustawieniach swojej sieci kliknij **Add Resource** i dodaj (przypisując dostęp grupie **Everyone** lub własnej):

     * **Serwer RPi 5 / sieć LAN:** adres `192.168.1.250` (tylko Raspberry Pi) lub `192.168.1.0/24` (cała sieć domowa, np. panel routera).

     * **Lokalne domeny `.home`:** adres `*.home` – dzięki pracy w trybie `network_mode: host` Connector odpytuje lokalnego Pi-hole'a i rozwiązuje `nas.home`, `pihole.home`, `vault.home`, `git.home` czy `media.home`.

4. **Klient na telefonie / laptopie:**

   * Zainstaluj aplikację **Twingate**, zaloguj się do swojej sieci (`twojanazwa.twingate.com`), przełącz telefon na dane komórkowe i sprawdź dostęp np. do `http://192.168.1.250:8081` lub `http://pihole.home:8080/admin`.

*(Wskazówka: Jeśli domeny `*.home` nie rozwiązują się zdalnie, sprawdź w `/etc/resolv.conf` na Raspberry Pi, czy jako serwer DNS wpisany jest `127.0.0.1` lub `192.168.1.250`).*

## ❄️ Krok 4: Optymalizacja chłodzenia Active Cooler i NVMe (`setup_cooler.sh`)

W zamkniętej obudowie z nakładką M.2 HAT+ i radiatorami na dysku SSD Gen 3 domyślna krzywa wentylatora (start od 50°C CPU) jest zbyt pasywna. Aby zapewnić optymalny obieg powietrza wokół radiatora NVMe oraz cichą pracę, uruchom konfigurator chłodzenia:

```
bash <(curl -fsSL https://raw.githubusercontent.com/procrastinating-pro/RPi5-PARRY/refs/heads/main/setup_cooler.sh)

```

**Co robi skrypt:**

* Ustawia w `/boot/firmware/config.txt` zoptymalizowaną krzywą dla **Raspberry Pi Active Cooler**.

* Instaluje pakiet `nvme-cli` oraz usługę systemową `nvme-fan-guard.service`, która odczytuje temperaturę dysku SSD i automatycznie reguluje obroty wentylatora podczas dużych transferów plików przez NAS (nawet gdy sam procesor RPi 5 jest chłodny).

* Tworzy polecenie diagnostyczne `rpi-temp`, pozwalające w dowolnej chwili sprawdzić temperatury oraz obroty wentylatora.

## 🎬 Krok 5 (Opcjonalny): Instalacja niezależnego Media Stacka (`setup_mediastack.sh`)

Usługi multimedialne zostały wydzielone do osobnego skryptu instalowanego w dedykowanym katalogu `~/docker/mediastack`, dzięki czemu nie nadpisują konfiguracji głównego HomeLaba (`~/docker/homelab`) i mogą być zarządzane niezależnie.

```
bash <(curl -fsSL https://raw.githubusercontent.com/procrastinating-pro/RPi5-PARRY/refs/heads/main/setup_mediastack.sh)

```

**Dostępne kontenery do wyboru w kreatorze `[1/6 – 6/6]`:**

1. **Jellyfin:** Domowy serwer multimediów i wideo z mapowaniem sprzętowej akceleracji `/dev/dri` oraz automatycznie przygotowaną strukturą folderów (`/media/movies`, `/media/tv`, `/media/music`).

2. **qBittorrent:** Klient sieci BitTorrent z interfejsem WebUI (domyślnie na porcie `8085`, aby nie kolidować z Pi-hole) oraz obsługą portów `6881` TCP/UDP.

   * **⚠️ Ostrzeżenie prawne P2P:** Przed instalacją qBittorrenta skrypt wyświetla szczegółową informację o działaniu protokołu BitTorrent (automatycznym seedowaniu w trakcie pobierania oraz różnicy między art. 23 a art. 116 ustawy o prawie autorskim w Polsce) i wymaga jawnego potwierdzenia `[t/N]`. Odrzucenie komunikatu pomija wyłącznie qBittorrenta, instalując pozostałe wybrane kontenery.

3. **Prowlarr:** Centralny menedżer indekserów, który automatycznie synchronizuje listę wyszukiwarek z aplikacjami Sonarr i Radarr.

4. **Sonarr:** Automatyzacja katalogowania i pobierania kolekcji seriali TV (z obsługą błyskawicznych *hardlinków* na dysku NVMe).

5. **Radarr:** Automatyzacja katalogowania i pobierania kolekcji filmów (z obsługą *hardlinków*).

6. **Bazarr:** Automatyczne wyszukiwanie i pobieranie dopasowanych napisów (np. polskich) do filmów i seriali zgromadzonych w Radarr oraz Sonarr.

### ⚙️ Konfiguracja i spięcie pakietu \*arr + Jellyfin (Hardlinki TRaSH-Guides)

Skrypt `setup_mediastack.sh` automatycznie tworzy na dysku NVMe wspólną strukturę katalogów:

* `/srv/nas/pliki/downloads/complete` (widoczny w kontenerach jako `/data/downloads/complete`)

* `/srv/nas/pliki/media/movies` (widoczny w kontenerach jako `/data/media/movies`)

* `/srv/nas/pliki/media/tv` (widoczny w kontenerach jako `/data/media/tv`)

Dzięki wspólnemu wolumenowi `/data`, przenoszenie plików z katalogu pobrań do biblioteki Jellyfin przez Sonarr/Radarr odbywa się poprzez **twarde dowiązania (hardlinks)** – trwa ułamek sekundy, nie zajmuje podwójnie miejsca i nie obciąża dysku NVMe zbędnym kopiowaniem.

**Krótka ściąga po pierwszym uruchomieniu:**

1. **qBittorrent (`:8085`, jeśli zainstalowany):** Odczytaj tymczasowe hasło z logów komendą `sudo docker logs qbittorrent`, zaloguj się jako `admin`, a następnie w *Tools -> Options -> Web UI* ustaw własne hasło. W zakładce *Downloads* upewnij się, że domyślna ścieżka zapisu (*Default Save Path*) to `/data/downloads/complete`.

2. **Sonarr (`:8989`) i Radarr (`:7878`):**

   * W *Settings -> Media Management -> Add Root Folder* wybierz odpowiednio `/data/media/tv` (w Sonarr) oraz `/data/media/movies` (w Radarr).

   * W *Settings -> Download Clients* dodaj wybranego klienta pobierania (np. **qBittorrent**: Host `qbittorrent`, Port `8085`, albo alternatywnego klienta Usenet/Debrid).

3. **Prowlarr (`:9696`):**

   * W *Settings -> Apps* dodaj **Sonarr** (`http://sonarr:8989`) oraz **Radarr** (`http://radarr:7878`), wklejając ich klucze API (*Settings -> General* w Sonarr/Radarr).

4. **Bazarr (`:6767`):**

   * W *Settings -> Sonarr* oraz *Settings -> Radarr* połącz obie aplikacje po kluczu API, a w *Settings -> Languages* ustaw język polski jako domyślny profil napisów.

5. **Jellyfin (`:8096`):**

   * W *Panelu administracyjnym -> Biblioteki* dodaj bibliotekę **Filmy** wskazującą na `/data/media/movies` oraz bibliotekę **Programy (Shows)** wskazującą na `/data/media/tv`.

## 🌐 Dostęp do usług po instalacji

Przy założeniu domyślnego adresu IP `192.168.1.250` oraz domyślnych lokalnych domen DNS:

### HomeLab & NAS (`setup_homelab.sh`)

| Usługa | Adres w sieci LAN / Domena `.home` | Domyślne logowanie / Uwagi | 
| ----- | ----- | ----- | 
| **Pi-hole** | `http://pihole.home:8080/admin` (`http://192.168.1.250:8080/admin`) | Hasło podane w konfiguratorze Pi-hole. | 
| **Samba NAS (SMB)** | Linux: `smb://nas.home/DyskNAS` / Windows: `\\nas.home\DyskNAS` | Login i hasło Samby podane w konfiguratorze. | 
| **FileBrowser** | `http://nas.home:8081` (`http://192.168.1.250:8081`) | Login: `admin` + własne hasło (min. 12 znaków). | 
| **Vaultwarden** | `http://vault.home:8222` (`http://192.168.1.250:8222`) | Utwórz konto w przeglądarce (wymaga HTTPS/Twingate dla WebCrypto). | 
| **Gitea** | `http://git.home:3000` (`http://192.168.1.250:3000`) | SSH: port `2222`. Przy pierwszym wejściu kliknij *Zainstaluj Gitea* (dane PostgreSQL są już uzupełnione). | 
| **Twingate** | Działa w tle (`network_mode: host`) | Logi połączenia: `sudo docker logs twingate-connector`. | 
| **Watchtower** | Działa w tle (harmonogram Cron `04:00`) | Logi aktualizacji: `sudo docker logs watchtower`. | 

### Media Stack – opcjonalny (`setup_mediastack.sh`)

*(Adresy z domeną `media.home` działają po dopisaniu jej do listy lokalnych domen w Pi-hole).*

| Usługa | Adres w sieci LAN | Domyślne logowanie / Uwagi | 
| ----- | ----- | ----- | 
| **Jellyfin** | `http://192.168.1.250:8096` (`http://media.home:8096`) | Kreator przy pierwszym wejściu (biblioteki: `/data/media/movies`, `/data/media/tv`). | 
| **qBittorrent** | `http://192.168.1.250:8085` (`http://media.home:8085`) | Login: `admin`, hasło tymczasowe: `sudo docker logs qbittorrent`. | 
| **Prowlarr** | `http://192.168.1.250:9696` (`http://media.home:9696`) | Centralny menedżer indekserów (ustaw hasło przy pierwszym wejściu). | 
| **Sonarr** | `http://192.168.1.250:8989` (`http://media.home:8989`) | Seriale TV (Root Folder: `/data/media/tv`). | 
| **Radarr** | `http://192.168.1.250:7878` (`http://media.home:7878`) | Filmy (Root Folder: `/data/media/movies`). | 
| **Bazarr** | `http://192.168.1.250:6767` (`http://media.home:6767`) | Automatyczne napisy (połącz z Sonarr i Radarr po API). | 

## 🗑️ Deinstalacja i czyszczenie środowiska (`uninstall_homelab.sh`)

Jeśli chcesz zresetować wybrane środowisko (albo oba naraz), usunąć jego kontenery oraz konfigurację i zacząć od czystego stanu, uruchom skrypt deinstalacyjny:

```
bash <(curl -fsSL https://raw.githubusercontent.com/procrastinating-pro/RPi5-PARRY/refs/heads/main/uninstall_homelab.sh)

```

**Menu wyboru i zabezpieczenia deinstalatora:**

1. **Wybór zakresu (`1–4`):**

   * `1)` **Tylko HomeLab & NAS** – usuwa kontenery i katalog `~/docker/homelab` (Pi-hole, Samba, FileBrowser, Twingate, Vaultwarden, Gitea, Watchtower).

   * `2)` **Tylko Media Stack** – usuwa kontenery i katalog `~/docker/mediastack` (Jellyfin, qBittorrent, Prowlarr, Sonarr, Radarr, Bazarr) bez ruszania HomeLaba i bez naruszania działającego Pi-hole.

   * `3)` **Oba środowiska** – usuwa jednocześnie HomeLab & NAS oraz Media Stack.

   * `4)` **Anuluj** – bezpieczne wyjście ze skryptu.

2. **Potwierdzenie usunięcia kontenerów (`TAK`):** Po wyborze zakresu skrypt zatrzymuje i usuwa wybrane kontenery (`docker compose down -v`), czyści wyłącznie nieużywane sieci i obrazy (`docker image prune -a -f`), a katalogi konfiguracyjne kasuje tylko dla wybranego zakresu. Domyślna konfiguracja `systemd-resolved` (port `53`) jest przywracana **wyłącznie przy usuwaniu HomeLaba** (opcja `1` lub `3`).

3. **Ochrona danych na dysku NAS (`USUN_MEDIA` / `USUN_DANE`):** Pliki w `/srv/nas/pliki` są domyślnie **chronione**:

   * Przy usuwaniu **samego Media Stacka** (opcja `2`) skrypt pyta wyłącznie o wykasowanie podkatalogów `/srv/nas/pliki/media` oraz `/srv/nas/pliki/downloads` (wymaga wpisania frazy `USUN_MEDIA`).

   * Przy usuwaniu **HomeLaba** lub **obu środowisk** (opcja `1` lub `3`) skrypt pyta o usunięcie całej zawartości `/srv/nas/pliki` (wymaga wpisania frazy `USUN_DANE`).

## 🛠️ Przydatne komendy diagnostyczne

* **Sprawdzenie temperatury CPU, dysku NVMe oraz obrotów Active Coolera:**

```
rpi-temp
# lub podgląd na żywo co 2 sekundy:
watch -n 2 rpi-temp

```

* **Pełna diagnostyka i reset konfiguracji wentylatora (w przypadku pracy na 100% obrotów):**
  Jeśli wentylator nie reaguje na zmiany temperatury, uruchom skrypt diagnostyczny, który przeskanuje partycje `bootfs` i `rootfs`, usunie konflikty i przetestuje sprzętowo linię PWM (`PWM=0` vs `PWM=255`):

```
sudo bash <(curl -fsSL https://raw.githubusercontent.com/procrastinating-pro/RPi5-PARRY/refs/heads/main/diagnose_and_fix_fan.sh)

```

* **Sprawdzenie czy nocny Auto-Update systemu (03:30) został przeprowadzony:**

```
# 1. Podgląd pełnego logu z nocnej aktualizacji (update, full-upgrade, autoremove, autoclean, docker prune):
tail -n 50 /var/log/auto-update.log

# 2. Sprawdzenie w logach systemowych (journalctl), czy zadanie Cron wystartowało punktualnie o 03:30:
sudo journalctl --since "03:29:00" --until "03:45:00" | grep -iE "cron|apt|upgrade|autoremove|autoclean"

# 3. Historia faktycznie zaktualizowanych lub usuniętych pakietów APT:
tail -n 30 /var/log/apt/history.log

```

* **Sprawdzenie czy aktualizacja kontenerów Docker (Watchtower o 04:00) została przeprowadzona:**

```
# 1. Logi działania kontenera Watchtower:
docker logs watchtower

# 2. Sprawdzenie dokładnej daty utworzenia/aktualizacji poszczególnych kontenerów:
docker inspect --format='{{.Name}} -> Utworzony: {{.Created}}' $(docker ps -a -q)

# 3. Ręczne wymuszenie natychmiastowego sprawdzenia i aktualizacji wszystkich kontenerów (test jednorazowy):
sudo docker run --rm -e DOCKER_API_VERSION=1.44 -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --run-once

```

* **Sprawdzenie statusu uruchomionych kontenerów:**

```
docker ps

```

* **Podgląd logów poszczególnych kontenerów:**

```
# HomeLab & NAS:
docker logs pihole
docker logs samba-nas
docker logs filebrowser-nas
docker logs vaultwarden
docker logs gitea
docker logs gitea-db
docker logs twingate-connector

# Media Stack (jeśli zainstalowany):
docker logs jellyfin
docker logs qbittorrent
docker logs prowlarr
docker logs sonarr
docker logs radarr
docker logs bazarr

```

* **Restart lub zatrzymanie usług:**

```
# HomeLab & NAS:
cd ~/docker/homelab
docker compose restart   # lub: docker compose down

# Media Stack (jeśli zainstalowany):
cd ~/docker/mediastack
docker compose restart   # lub: docker compose down

```

* **Ręczna zmiana hasła do FileBrowsera z poziomu terminala:**

```
cd ~/docker/homelab
docker compose stop filebrowser
docker compose run --rm filebrowser users update admin --password "TwojeNoweHaslo123" --database /database/filebrowser.db
docker compose start filebrowser

```

## 💰 Szacowane oszczędności i zwrot z inwestycji (ROI w domu)

W warunkach domowych wdrożenie zestawu na Raspberry Pi 5 pozwala ograniczyć stałe opłaty za subskrypcje w chmurze i serwisy zewnętrzne o ok. **620 – 970 PLN rocznie** w wariancie podstawowym (HomeLab & NAS) oraz ok. **1 820 – 3 370 PLN rocznie** przy wykorzystaniu opcjonalnego Media Stacka.

| Usługa w domu | Komercyjny odpowiednik | Zestaw na RPi 5 | Roczna oszczędność | 
| ----- | ----- | ----- | ----- | 
| **Chmura na pliki i zdjęcia (2 TB)** | Google One / iCloud+ (\~47–50 PLN/mies.) | **Samba + FileBrowser** (0 PLN) | **560 – 600 PLN** | 
| **Menedżer haseł** | Bitwarden Premium / 1Password (\~50–240 PLN/rok) | **Vaultwarden** (0 PLN) | **50 – 240 PLN** | 
| **Ochrona DNS i zdalny dostęp** | NextDNS Pro / AdGuard / płatny VPN (\~80–200 PLN/rok) | **Pi-hole + Twingate** (darmowy do 5 osób) | **80 – 200 PLN** | 
| **Platformy VOD (opcjonalnie)** | 2–4 serwisy streamingowe (\~100–200 PLN/mies.) | **Jellyfin + pakiet \*arr** (0 PLN) | **1 200 – 2 400 PLN** | 
| **Energia elektryczna (24/7)** | 0 PLN (w chmurze) | **RPi 5** (\~6–7 W ≈ 60 kWh/rok) | **-70 PLN** *(koszt)* | 
| **RAZEM (bez Media Stacka)** | **\~690 – 1 040 PLN / rok** | **\~70 PLN / rok** | **\~620 – 970 PLN / rok** | 
| **RAZEM (z Media Stackiem)** | **\~1 890 – 3 440 PLN / rok** | **\~70 PLN / rok** | **\~1 820 – 3 370 PLN / rok** | 

**Szacowany czas zwrotu sprzętu** (przy koszcie zakupu brutto RPi 5, M.2 HAT+, dysku NVMe 1–2 TB, Active Coolera i zasilacza 27W na poziomie ok. **1 100 – 1 400 PLN**):

* **Tylko HomeLab & NAS:** zwrot po **1,5 – 2 latach**.

* **Z Media Stackiem:** zwrot w **5 – 8 miesięcy**.

* **Dodatkowa oszczędność na prądzie:** jeśli RPi 5 zastępuje w domu starszy serwer/PC x86 działający 24/7 (ok. 50 W ≈ 500 PLN/rok), sama zmiana platformy oszczędza dodatkowe **\~430 PLN rocznie** na energii elektrycznej.

*(Wskazówka: Ponieważ zestaw pracuje na pojedynczym dysku NVMe, najważniejsze pliki z `/srv/nas/pliki` warto okresowo kopiować na zewnętrzny dysk USB zgodnie z zasadą backupu 3-2-1).*

## 📄 Licencja

Projekt jest udostępniany na warunkach licencji **MIT**. Szczegółowe informacje znajdują się w pliku [LICENSE.md](LICENSE.md).