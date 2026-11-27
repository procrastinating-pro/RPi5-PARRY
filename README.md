# 🍓 RPi5-PARRY (Raspberry Pi 5 Headless + Docker HomeLab + NAS + Auto-Maintenance)

Zestaw automatycznych i interaktywnych skryptów Bash pozwalających na szybkie przygotowanie czystego obrazu **Raspberry Pi OS (64-bit)** pod Raspberry Pi 5 (wraz z obsługą **NVMe HAT+**), bezobsługową aktualizację systemu, optymalizację krzywej chłodzenia (**Active Cooler + NVMe Heatsink Guard**), instalację **Dockera** oraz modułowe wdrożenie domowego serwera **HomeLab & NAS** (**Pi-hole**, **Samba**, **Tailscale**, **Vaultwarden**, **Gitea**, **Caddy HTTPS**, **Watchtower**).

## 🛡️ O ile spada ryzyko udanego ataku?

Względem standardowej sieci domowej (router z przekierowanymi portami i zwykły DNS od operatora) ten zestaw ucina większość najczęstszych wektorów ataku jeszcze zanim dotrą do Twoich urządzeń:

| Wektor ataku | Spadek ryzyka | Co dokładnie blokuje ten wektor? | 
| ----- | ----- | ----- | 
| **Botnety i skanery z internetu (WAN → LAN)** | **\~99,9%** | **Tailscale (0 otwartych portów na routerze)** – serwer jest niewidoczny dla skanerów (Shodan) i automatycznych botnetów. | 
| **Malware, phishing i serwery C2** | **\~70 – 95%** | **Pi-hole (HaGeZi + TIF) + Tailscale DNS** – blokuje złośliwe domeny na poziomie DNS w domowym Wi-Fi oraz na sieci komórkowej **LTE/5G**. | 
| **Fałszywe Wi-Fi / Evil Portal** | **\~99%** | **Vaultwarden + własne LTE/5G** – menedżer haseł sprawdza dokładną domenę i nie autouzupełni hasła na podstawionym linku, a nielimitowane LTE eliminuje potrzebę łączenia z publicznym Wi-Fi. | 
| **Podsłuch haseł w sieci lokalnej (MITM)** | **\~95 – 99%** | **Caddy Reverse Proxy (`tls internal`)** – szyfruje dostęp do paneli (`*.home`) i zamyka bezpośrednie porty HTTP w sieci LAN. | 
| **Znane luki w aplikacjach (CVE)** | **\~80 – 90%** | **Watchtower (04:00) + Auto-Update (03:30)** – skraca okno podatności z tygodni/miesięcy do maks. 24 godzin. | 
| **Eskalacja uprawnień z kontenera** | **Wysoka izolacja** | **Docker `userns-remap` + sieć `bridge`** – kontenery nie działają jako prawdziwy `root` na hoście i nie współdzielą jego stosu sieciowego. | 

## 💰 Szacowane oszczędności i zwrot z inwestycji (ROI)

Wdrożenie zestawu na Raspberry Pi 5 pozwala ograniczyć stałe opłaty za subskrypcje w chmurze o ok. **620 – 970 PLN rocznie** (w warunkach domowych), a w wariancie dedykowanym dla **mikrofirmy (3–10 stanowisk)** zastępuje komercyjne rozwiązania DNS Security / VPN / chmury o wartości **1 500 – 5 500+ PLN rocznie**.

### 1. Stałe oszczędności na subskrypcjach (HomeLab & NAS)

| Usługa w domu | Komercyjny odpowiednik | Zestaw na RPi 5 | Roczna oszczędność | 
| ----- | ----- | ----- | ----- | 
| **Chmura na pliki i zdjęcia (2 TB)** | Google One / iCloud+ (\~47–50 PLN/mies.) | **Samba NAS (SMB)** (0 PLN) | **560 – 600 PLN** | 
| **Menedżer haseł** | Bitwarden Premium / 1Password (\~50–240 PLN/rok) | **Vaultwarden** (0 PLN) | **50 – 240 PLN** | 
| **Ochrona DNS i zdalny dostęp** | NextDNS Pro / AdGuard / płatny VPN (\~80–200 PLN/rok) | **Pi-hole + Tailscale** (darmowy do 100 urządzeń) | **80 – 200 PLN** | 
| **Energia elektryczna (24/7)** | 0 PLN (w chmurze) | **RPi 5** (\~6–7 W ≈ 60 kWh/rok) | **-70 PLN** *(koszt)* | 
| **RAZEM** | **\~690 – 1 040 PLN / rok** | **\~70 PLN / rok** | **\~620 – 970 PLN / rok** | 

* **Szacowany czas zwrotu sprzętu** (przy koszcie zakupu brutto RPi 5, M.2 HAT+, dysku NVMe 1–2 TB, Active Coolera i zasilacza 27W na poziomie ok. **1 350 – 1 600 PLN**): **1,5 – 2 lata**.

* **Dodatkowa oszczędność na prądzie:** jeśli RPi 5 zastępuje w domu starszy serwer/PC x86 działający 24/7 (ok. 50 W ≈ 500 PLN/rok), sama zmiana platformy oszczędza dodatkowe **\~430 PLN rocznie** na energii elektrycznej.

### 2. Wartość zapobiegania intruzji i redukcji ryzyka (Dom vs Mikrofirma)

* **Zerowa powierzchnia ataku od strony WAN + DNS Sinkholing:** brak przekierowań portów na routerze (tunel **Tailscale**) czyni serwer niewidocznym dla skanerów i botnetów, a **Pi-hole** z listami **HaGeZi + Threat Intelligence Feeds (TIF)** blokuje domeny phishingowe, malware i serwery C2 (*Command & Control*) w całej sieci LAN oraz na danych komórkowych (LTE/5G) — zastępując komercyjne bramy/licencje DNS Security warte **400 – 4 500 PLN/rok**.

* **W warunkach domowych:** zablokowanie pojedynczego *infostealera* lub kampanii phishingowej chroni przed przejęciem aktywnych sesji w przeglądarce, kont bankowych oraz zaszyfrowaniem plików (uniknięte straty rzędu **kilku – kilkudziesięciu tysięcy PLN** oraz dziesiątek godzin odzyskiwania dostępów).

* **W mikrofirmie (3–10 stanowisk):** pojedynczy skuteczny phishing kończący się ransomware na udziałach sieciowych to zazwyczaj **15 000 – 50 000+ PLN strat** (przestój operacyjny firmy, informatyk śledczy, odtwarzanie danych z kopii zapasowych oraz ryzyko kar RODO). Koszt sprzętowy RPi 5 zwraca się już przy zablokowaniu **jednego** incydentu.

*(Wskazówka: Ponieważ zestaw podstawowy pracuje na pojedynczym dysku NVMe, najważniejsze pliki z `/srv/nas/pliki` warto okresowo kopiować na zewnętrzny dysk USB zgodnie z zasadą backupu 3-2-1 lub rozbudować zestaw o wielodyskowy **Radxa Penta SATA HAT** z macierzą RAID — szczegóły poniżej).*

## 📝 To-Do / Roadmap

* \[x\] **Migracja z Twingate na Tailscale** *(wdrożone w `setup_homelab.sh`)*

  * **Powód zmiany:** Twingate działa wyłącznie jako *split-tunnel* dla jawnie zdefiniowanych zasobów (`192.168.1.250`, `*.home`), przez co na sieci komórkowej (LTE/5G) cały pozostały ruch DNS omija lokalny serwer **Pi-hole** (nie działają domowe listy blokowania reklam i malware HaGeZi; opcja *Custom DNS* w Twingate przyjmuje jedynie publiczny serwer DoH `https://...`). **Tailscale** w trybie *Subnet Router* z opcją **Override DNS servers** pozwala kierować 100% zapytań DNS z telefonu poza domem bezpośrednio przez Pi-hole na Raspberry Pi 5, bez otwierania portów na routerze i bez przekierowywania całego ruchu internetowego przez domowe łącze.

* \[x\] **Usunięcie niewspieranego FileBrowsera** – dostęp do dysku NAS realizowany bezpośrednio przez bezpieczny udział **Samba (SMB)** (lokalnie i przez Tailscale).

* \[x\] **Zamknięcie otwartych portów webowych w sieci LAN + Tailscale w trybie `bridge`** – przy aktywnym Caddy wyeliminowano mapowanie portów `8080`, `8222` oraz `3000` na interfejsie LAN, a kontener Tailscale przeniesiono na dedykowaną sieć `homelab-net` (`172.28.0.0/24`).

* \[x\] **Docker User-Remap (`userns-remap`)** – opcjonalna izolacja przestrzeni nazw UID/GID w `/etc/docker/daemon.json` z automatycznym ustawieniem uprawnień wolumenów dla `dockremap`.

* \[x\] **Automatyczna aktualizacja list Pi-hole Gravity w nocy** – zadanie Cron (`/etc/cron.d/pihole-gravity` codziennie o `03:30`) odświeżające bazy blokowania (`docker exec pihole pihole -g`) przed nocnym oknem aktualizacji Watchtowera (`04:00`).

* \[ \] **Zaktualizować `uninstall_homelab.sh`** o czyszczenie katalogu `~/docker/homelab/tailscale`, pliku `/etc/sysctl.d/99-tailscale.conf`, `/etc/cron.d/pihole-gravity` oraz opcjonalne wycofanie `userns-remap`.

* \[ \] **Automatyczny backup konfiguracji** (bazy Vaultwarden, repozytoriów Gitea oraz ustawień Pi-hole) na zewnętrzny nośnik lub zaszyfrowane archiwum.

## 🛠️ Sprzęt użyty w projekcie (Hardware)

Projekt został zaprojektowany i zoptymalizowany pod kątem następującej konfiguracji sprzętowej:

* **Płyta główna:** Raspberry Pi 5

* **Adapter PCIe:** Raspberry Pi M.2 HAT+

* **Dysk systemowy i NAS:** Raspberry Pi SSD (NVMe PCIe Gen 3) + dodatkowe radiatory chłodzące na dysku

* **Chłodzenie procesora i obudowy:** Raspberry Pi Active Cooler (sterowany hybrydowo na podstawie temperatury CPU oraz czujnika S.M.A.R.T. dysku NVMe)

* **Zasilanie:** Oficjalny zasilacz Raspberry Pi 27W USB-C PD (5.1V / 5A)

* **Obudowa:** Dedykowana, podwyższona obudowa drukowana w 3D (projekt parametryczny w OpenSCAD mieszczący M.2 HAT+, wysokie radiatory na NVMe, uniesioną nakładkę z logo *Badge* oraz wciskane nóżki z TPU)

### 🔀 Opcjonalna rozbudowa NAS: Zamiana M.2 HAT+ na Radxa Penta SATA HAT

Zamiast pojedynczego dysku NVMe na **Raspberry Pi M.2 HAT+** można podłączyć do złącza PCIe w Raspberry Pi 5 nakładkę **Radxa Penta SATA HAT**. Wszystkie skrypty konfiguracyjne i kontenery Dockera z tego repozytorium działają w tym wariancie bez zmian (wystarczy wskazać punkt montowania macierzy jako katalog `NAS_DIR` w `setup_homelab.sh`), a zestaw zyskuje możliwości pełnoprawnego serwera NAS klasy SOHO / mikrofirmy:

* **Do 5 dysków SATA jednocześnie (nawet 100 TB przestrzeni):** 4× port SATA (dyski 2.5" lub 3.5" HDD/SSD) + 1× port eSATA — idealne pod archiwum wideo, kopie zapasowe wszystkich komputerów w firmie/domu oraz własną chmurę plików.

* **Sprzętowa gotowość pod macierze RAID (RAID 0 / 1 / 5 / 10 przez `mdadm`, Btrfs lub ZFS):** eliminacja pojedynczego punktu awarii (*Single Point of Failure*). Przy **RAID 1** lub **RAID 5** awaria jednego dysku nie powoduje utraty danych ani przestoju usług (Samba, Gitea, Vaultwarden).

* **Migawki (*Snapshots*) jako dodatkowa tarcza anty-ransomware:** na macierzy Btrfs/ZFS można ustawić cykliczne migawki tylko do odczytu (*read-only*) dla katalogu `/srv/nas/pliki` — nawet jeśli zainfekowany komputer w sieci LAN zaszyfruje pliki na udziale Samba, stan sprzed ataku można cofnąć w kilka sekund.

* **Jedno wspólne zasilanie 12V DC:** nakładka zasila jednocześnie Raspberry Pi 5 oraz podłączone dyski SATA (w tym prądożerne dyski 3.5" HDD), eliminując potrzebę stosowania osobnego zasilacza USB-C 27W.

* **Opcjonalny moduł Top Board (OLED + wentylator PWM):** wbudowany wyświetlacz pokazuje na bieżąco adres IP, temperaturę oraz stan zapełnienia macierzy bez logowania się po SSH.

* **O czym pamiętać przy tej zamianie:** system operacyjny uruchamia się wtedy z karty microSD (lub SSD na USB 3.0), skrypt `nvme-fan-guard` z `setup_cooler.sh` nie jest potrzebny (brak dysku NVMe), a zamiast obudowy `rpi5_nvme_case.scad` należy zastosować obudowę dedykowaną pod wieżę dysków SATA.

## 📂 Zawartość repozytorium

| Plik / Skrypt | Gdzie uruchamiać? | Opis działania | 
| ----- | ----- | ----- | 
| **`rpi5_configurator.sh`** | 💻 Na komputerze (np. Ubuntu) z podłączonym nośnikiem (SD/NVMe) | Konfiguruje czysty obraz przed pierwszym uruchomieniem: włącza SSH, tworzy użytkownika, wgrywa klucz SSH, ustawia statyczny IP (NetworkManager) i odblokowuje PCIe Gen 3 dla NVMe HAT+. | 
| **`install_docker.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Aktualizuje system, włącza `fstrim.timer` dla NVMe, ustawia codzienny Auto-Update/Clean w Cronie (03:30), instaluje **Docker Engine** oraz **Docker Compose v2** (z pominięciem, jeśli jest już zainstalowany) i konfiguruje rotację logów. | 
| **`setup_homelab.sh`** | 🍓 Na Raspberry Pi 5 (przez SSH) | Interaktywny kreator usług HomeLab (Czysty Bash `[T/n]`, katalog `~/docker/homelab`): **Pi-hole** (+ nocny Cron Gravity), **Samba (SMB)**, **Tailscale (VPN Subnet Router w sieci `bridge`)**, **Vaultwarden**, **Gitea (+ PostgreSQL)**, **Caddy Reverse Proxy (lokalny HTTPS `.home` + zamknięcie portów webowych na LAN)**, **Watchtower** (auto-update o 04:00) oraz **Docker `userns-remap`**. | 
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

### 🔑 Przed uruchomieniem: Wygenerowanie klucza Tailscale Auth Key (opcjonalnie)

Jeśli planujesz uruchomić zdalny dostęp **Tailscale** (dostęp do sieci domowej oraz blokowanie reklam przez Pi-hole również na sieci komórkowej LTE/5G), wygeneruj klucz autoryzacyjny **zanim** odpalisz `setup_homelab.sh`:

1. Zaloguj się do panelu administracyjnego **`https://login.tailscale.com/admin`**.

2. Przejdź do *Settings → Keys* (`https://login.tailscale.com/admin/settings/keys`) i kliknij **Generate auth key**.

3. Skopiuj wygenerowany klucz (`tskey-auth-...`) – kreator poprosi o jego wklejenie w trakcie instalacji.

### 🚀 Uruchomienie kreatora `setup_homelab.sh`

Aby uruchomić usługi domowego serwera (z możliwością wyboru `[T/n]` dla każdego kontenera i opcji bezpieczeństwa), wykonaj na Raspberry Pi 5:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/procrastinating-pro/RPi5-PARRY/refs/heads/main/setup_homelab.sh)
```

*(Uwaga: Użycie składni `bash <(curl ...)` jest wymagane, ponieważ skrypt działa interaktywnie i pobiera od Ciebie wybór kontenerów, hasła, klucze oraz ścieżki z klawiatury).*

**Dostępne moduły do wyboru w kreatorze `[1/6 – 6/6 + Extra + Security]`:**

1. **Pi-hole:** Blokowanie reklam w całej sieci LAN oraz lokalny serwer DNS ze stałym IP w sieci Dockera (`172.28.0.10`). Automatycznie zwalnia port `53` z `systemd-resolved`, konfiguruje lokalne domeny `.home` oraz ustawia automatyczne odświeżanie list Gravity codziennie o `03:30` w `/etc/cron.d/pihole-gravity`.

2. **Samba NAS:** Dysk sieciowy SMB/CIFS widoczny w systemach Windows, Linux oraz macOS (dostępny lokalnie oraz zdalnie przez Tailscale).

3. **Tailscale (VPN Subnet Router w trybie `bridge`):** Bezpieczny, zdalny dostęp spoza domu bez otwierania portów na routerze (działa nawet za CGNAT). Działa w odizolowanej sieci `homelab-net` (`172.28.0.0/24`), rozgłasza podsieć LAN oraz mostek Dockera i kieruje cały ruch DNS z telefonu na LTE/5G bezpośrednio do Pi-hole (`172.28.0.10`).

4. **Vaultwarden:** Lekki, lokalny serwer menedżera haseł kompatybilny z oficjalnymi aplikacjami Bitwarden (przy włączonym Caddy automatycznie korzysta z `https://vault.home` wymaganego przez WebCrypto).

5. **Gitea + PostgreSQL:** Lekki, lokalny serwer Git (self-hosted alternatywa dla GitHuba/GitLaba) z dedykowaną bazą **PostgreSQL 16**, trwale zapisywanym hasłem bazy (`~/docker/homelab/gitea/.db_pass`) oraz obsługą klonowania po HTTPS i SSH (`2222`).

6. **Caddy Reverse Proxy (Lokalny HTTPS + zamknięcie portów LAN):** Automatycznie generuje `Caddyfile` dla wszystkich wybranych usług i udostępnia je wyłącznie po szyfrowanym połączeniu **HTTPS** (`https://pihole.home`, `https://vault.home`, `https://git.home`), zamykając bezpośrednie porty webowe (`8080`, `8222`, `3000`) w sieci lokalnej. Po uruchomieniu eksportuje certyfikat `homelab-root-ca.crt` do `~/docker/homelab/caddy/` oraz na dysk NAS (`/srv/nas/pliki/`).

* **\[Extra\] Watchtower:** Automatyczna aktualizacja wszystkich uruchomionych kontenerów i czyszczenie starych obrazów codziennie o 04:00 rano (z wymuszonym `DOCKER_API_VERSION=1.44`).

* **\[Security\] Docker `userns-remap`:** Izolacja przestrzeni nazw użytkowników w daemonie Dockera (`"userns-remap": "default"` w `/etc/docker/daemon.json`) z automatycznym przepisaniem uprawnień wolumenów dla `dockremap`.

### 🔒 Lokalny HTTPS (Caddy) – jednorazowa instalacja certyfikatu CA

Ponieważ Caddy wystawia certyfikaty dla lokalnych domen `.home` z własnego, lokalnego urzędu certyfikacji (`tls internal`), wystarczy **raz** dodać plik `homelab-root-ca.crt` (dostępny w `~/docker/homelab/caddy/homelab-root-ca.crt` oraz bezpośrednio na udziale Samba w `/srv/nas/pliki/homelab-root-ca.crt`) do zaufanych na swoich urządzeniach – dzięki temu znikną ostrzeżenia w przeglądarce i poprawnie zadziałają aplikacje Bitwarden/Vaultwarden:

* **Ubuntu / Debian:**

  ```bash
  sudo cp homelab-root-ca.crt /usr/local/share/ca-certificates/
  sudo update-ca-certificates
  ```

  *(W Chrome/Firefox dodatkowo: Ustawienia → Certyfikaty → Urzędy certyfikacji → Importuj → zaznacz zaufanie dla witryn).*

* **Windows:** Kliknij dwukrotnie `homelab-root-ca.crt` → *Zainstaluj certyfikat* → *Komputer lokalny* → *Umieść wszystkie certyfikaty w następującym magazynie* → **Zaufane główne urzędy certyfikacji**.

* **Android:** Pobierz plik (np. z udziału Samba lub przez SCP) → *Ustawienia → Zabezpieczenia → Szyfrowanie i dane logowania → Zainstaluj certyfikat → Certyfikat CA* → wskaż `homelab-root-ca.crt`.

* **iOS:** Pobierz plik na telefon, zainstaluj profil w *Ustawienia → Ogólne → VPN i zarządzanie urządzeniami*, a następnie włącz pełne zaufanie w *Ustawienia → Ogólne → To urządzenie → Ustawienia zaufania certyfikatom*.

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

4. Pole **Zapasowy serwer DNS (Secondary DNS)** pozostaw **puste** (jeśli router wymaga wartości, wpisz ponownie `192.168.1.250`, `0.0.0.0` lub nieużywany adres IP z podsieci, np. `192.168.1.251` – nie wpisuj `1.1.1.1` ani `8.8.8.8`).

5. Zapisz ustawienia i zrestartuj połączenie Wi-Fi/LAN na urządzeniach, aby pobrały nową konfigurację z routera.

### 🌍 Lokalne domeny DNS (Konfiguracja w `docker-compose.yml`)

Skrypt `setup_homelab.sh` automatycznie pyta o lokalne domeny podczas instalacji Pi-hole (domyślnie: `pihole.home rpi.home vault.home git.home`) i dopisuje je bezpośrednio do pliku `~/docker/homelab/docker-compose.yml`.

Jeśli w przyszłości zechcesz dodać kolejne własne domeny, wystarczy wyedytować plik `~/docker/homelab/docker-compose.yml` (sekcja `extra_hosts` oraz `FTLCONF_dns_hosts` rozdzielone średnikiem w usłudze `pihole`) i przeładować kontenery komendą `docker compose up -d`.

*(Wskazówka: Używaj końcówek `.home`, `.lan` lub `.internal`. Unikaj końcówki `.local`, która jest zarezerwowana dla protokołu mDNS/Avahi i może powodować opóźnienia).*

### 🔐 Dokończenie konfiguracji Tailscale (po uruchomieniu kontenerów)

Gdy `setup_homelab.sh` uruchomi już kontener `tailscale` w sieci `homelab-net`, wykonaj dwa kroki w panelu **`https://login.tailscale.com/admin`**:

1. **Zatwierdzenie Subnet Routes i wyłączenie wygasania klucza (*Machines*):**

   * Znajdź swoje Raspberry Pi na liście urządzeń, kliknij menu `...` → **Edit route settings** → zaznacz obie rozgłaszane podsieci (`192.168.1.0/24` oraz `172.28.0.0/24`) i zapisz.

   * W tym samym menu kliknij **Disable key expiry**, aby serwer nie wymagał ponownej autoryzacji po 180 dniach.

2. **Przekierowanie całego DNS (LTE/5G) przez Pi-hole (*DNS*):**

   * Przejdź do zakładki **DNS** → sekcja **Nameservers** → **Add nameserver → Custom**.

   * Wpisz stały adres IP kontenera Pi-hole w sieci Dockera: **`172.28.0.10`**.

   * Włącz przełącznik **Override DNS servers** – od tego momentu każde zapytanie DNS z telefonu na LTE/5G leci przez Pi-hole (działają zarówno listy HaGeZi, jak i lokalne domeny `https://*.home`), podczas gdy sam ruch internetowy idzie bezpośrednio przez sieć komórkową.

3. **Klient na telefonie / laptopie:**

   * Zainstaluj aplikację **Tailscale**, zaloguj się na to samo konto, przełącz telefon na dane komórkowe i sprawdź dostęp np. do `https://pihole.home/admin` lub `https://vault.home`.

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

Przy założeniu domyślnego adresu IP `192.168.1.250`, domyślnych domen `.home` oraz włączonego **Caddy (HTTPS)** (bezpośrednie porty webowe w LAN są zamknięte):

| Usługa | Adres HTTPS (Caddy) | Adres bezpośredni / SMB / SSH | Domyślne logowanie / Uwagi | 
| ----- | ----- | ----- | ----- | 
| **Pi-hole** | `https://pihole.home/admin` | DNS: port `53` (`172.28.0.10` w Tailscale) | Hasło podane w konfiguratorze Pi-hole. | 
| **Vaultwarden** | `https://vault.home` | *(port LAN zamknięty)* | Utwórz konto przez `https://vault.home` (HTTPS wymagane przez WebCrypto). | 
| **Gitea** | `https://git.home` | SSH: port `2222` *(HTTP LAN zamknięty)* | Przy pierwszym wejściu kliknij *Zainstaluj Gitea* (dane PostgreSQL są już uzupełnione). | 
| **Samba NAS (SMB)** | — | Linux: `smb://rpi.home/DyskNAS` / Windows: `\\rpi.home\DyskNAS` | Login i hasło Samby podane w konfiguratorze. | 
| **Caddy (HTTPS)** | Porty `80` i `443` | — | Certyfikat CA do pobrania: `/srv/nas/pliki/homelab-root-ca.crt`. | 
| **Tailscale** | Działa w sieci `homelab-net` (`bridge`) | — | Status połączenia: `sudo docker exec tailscale tailscale status`. | 
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
  docker logs vaultwarden
  docker logs gitea
  docker logs gitea-db
  docker logs caddy
  docker logs tailscale
  docker exec tailscale tailscale status
  ```

* **Restart lub zatrzymanie usług:**

  ```bash
  cd ~/docker/homelab
  docker compose restart   # lub: docker compose down
  ```