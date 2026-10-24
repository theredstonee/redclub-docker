#!/usr/bin/env bash
# RedClub — Installation auf einem Linux-Server (Debian/Ubuntu, auch RHEL-Verwandte).
# One-liner / Einzeiler (installs to /opt/redclub, other folder: RC_DIR=/path):
#   curl -fsSL https://raw.githubusercontent.com/theredstonee/redclub-docker/main/install.sh | sudo bash
# Oder im Ordner mit den Dateien:  sudo bash install.sh
# Entfernen / Uninstall:  sudo bash /opt/redclub/install.sh --uninstall
#
# Zwei Wege nach aussen, der Installer erkennt selbst, welcher passt:
#   Caddy  — Port 80/443 sind frei: eigener Caddy mit automatischem HTTPS (Let's Encrypt).
#   Port   — Port 80/443 sind schon belegt (nginx, Apache, Plesk …): die App bekommt einen freien
#            Port auf 127.0.0.1, dein Webserver bekommt einen Virtual Host fuer die Domain.
#
# Schalter (optional):  --lang en|de  --port 8080  --domain verein.firma.de  --email du@firma.de
#                       --caddy (Caddy erzwingen)  --no-vhost (keinen Virtual Host anlegen)
#                       --uninstall / --deinstallieren (Container, Webserver-Eintraege, auf Wunsch alle Daten)
# Ein zweiter Aufruf aktualisiert nur (Image ziehen, neu starten) und fragt nichts mehr.
set -euo pipefail
QUELLE="https://raw.githubusercontent.com/theredstonee/redclub-docker/main"
DATEIEN="docker-compose.yml compose.caddy.yml compose.port.yml Caddyfile install.sh .env.example README.md version.json"
# Ueber curl | bash gestartet (oder Dateien fehlen): alles nach /opt/redclub holen und dort weitermachen
if [ -f "$0" ] && [ -f "$(dirname "$0")/docker-compose.yml" ]; then
  cd "$(dirname "$0")"
else
  ZIEL="${RC_DIR:-/opt/redclub}"
  echo "==> RedClub: $ZIEL"
  mkdir -p "$ZIEL" && cd "$ZIEL"
  for f in $DATEIEN; do curl -fsSL -o "$f" "$QUELLE/$f" || { [ "$f" = "version.json" ] || { echo "ERROR: $f"; exit 1; }; }; done
  # Fragen brauchen das Terminal (stdin ist bei curl | bash die Leitung) — ohne Terminal gelten die Vorgaben
  if { true </dev/tty; } 2>/dev/null; then exec bash ./install.sh "$@" </dev/tty; else exec bash ./install.sh "$@"; fi
fi

PORT=""; DOMAIN=""; EMAIL=""; MODUS=""; VHOST="ja"; WEG=""; SPR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --lang) SPR="${2,,}"; shift 2 ;;
    --port) PORT="$2"; MODUS="port"; shift 2 ;;
    --domain) DOMAIN="${2,,}"; shift 2 ;;
    --email) EMAIL="$2"; shift 2 ;;
    --caddy) MODUS="caddy"; shift ;;
    --no-vhost) VHOST="nein"; shift ;;
    --deinstallieren|--uninstall) WEG="ja"; shift ;;
    *) echo "Unknown option / Unbekannter Schalter: $1"; exit 1 ;;
  esac
done

# Aussehen: Farben nur im Terminal (RC_FARBE=1 erzwingt sie, NO_COLOR/TERM=dumb schaltet sie ab), Zeichen nur mit UTF-8
if { [ -t 1 ] || [ -n "${RC_FARBE:-}" ]; } && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  R=$'\033[38;2;232;48;48m'; R2=$'\033[38;2;255;110;100m'; G=$'\033[38;2;74;222;128m'; Y=$'\033[38;2;251;191;36m'
  C=$'\033[38;2;125;211;252m'; D=$'\033[2m'; B=$'\033[1m'; U=$'\033[4m'; N=$'\033[0m'
else R=""; R2=""; G=""; Y=""; C=""; D=""; B=""; U=""; N=""; fi
if locale charmap 2>/dev/null | grep -qi 'utf-\?8' || echo "${LANG:-}${LC_ALL:-}" | grep -qi 'utf-\?8'; then
  Z_SCHRITT="▸"; Z_OK="✔"; Z_FEHLER="✖"; Z_FRAGE="?"; Z_PUNKT="·"; K_OL="╭"; K_OR="╮"; K_UL="╰"; K_UR="╯"; K_H="─"; K_V="│"; SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
else
  Z_SCHRITT=">"; Z_OK="OK"; Z_FEHLER="X"; Z_FRAGE="?"; Z_PUNKT="-"; K_OL="+"; K_OR="+"; K_UL="+"; K_UR="+"; K_H="-"; K_V="|"; SPIN=('|' '/' '-' '\')
fi
VERSION_TXT=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' version.json 2>/dev/null | head -1 || true)
banner() {
  echo ""
  printf '%s\n' "${R}${B}   ██████╗ ███████╗██████╗ ${R2} ██████╗██╗     ██╗   ██╗██████╗ ${N}" \
                "${R}${B}   ██╔══██╗██╔════╝██╔══██╗${R2}██╔════╝██║     ██║   ██║██╔══██╗${N}" \
                "${R}${B}   ██████╔╝█████╗  ██║  ██║${R2}██║     ██║     ██║   ██║██████╔╝${N}" \
                "${R}${B}   ██╔══██╗██╔══╝  ██║  ██║${R2}██║     ██║     ██║   ██║██╔══██╗${N}" \
                "${R}${B}   ██║  ██║███████╗██████╔╝${R2}╚██████╗███████╗╚██████╔╝██████╔╝${N}" \
                "${R}${B}   ╚═╝  ╚═╝╚══════╝╚═════╝ ${R2} ╚═════╝╚══════╝ ╚═════╝ ╚═════╝ ${N}"
  echo "   ${D}Selbst gehostete Vereinsverwaltung ${Z_PUNKT} self-hosted club management${N}"
  echo "   ${D}${VERSION_TXT:+v$VERSION_TXT  ${Z_PUNKT}  }by TheRedStonee ${Z_PUNKT} https://www.theredstonee.de/redclub/${N}"
  echo ""
}
# Kasten um wichtige Werte (Setup-Code, Adresse): kasten FARBE "Zeile" ["Zeile" …]
kasten() {
  local farbe="$1"; shift
  local breit=0 z
  for z in "$@"; do [ ${#z} -gt $breit ] && breit=${#z}; done
  local linie; linie=$(printf "%$((breit + 4))s" "" | sed "s/ /${K_H}/g")
  echo "  ${farbe}${K_OL}${linie}${K_OR}${N}"
  # von Hand auffuellen: printf zaehlt Bytes, ${#z} Zeichen (Umlaute, „·“)
  for z in "$@"; do printf '  %s%s%s  %s%s%s%*s  %s%s%s\n' "$farbe" "$K_V" "$N" "$B" "$z" "$N" $((breit - ${#z})) "" "$farbe" "$K_V" "$N"; done
  echo "  ${farbe}${K_UL}${linie}${K_UR}${N}"
}
[ -n "${RC_KEIN_BANNER:-}" ] || banner

# Sprache: Schalter → .env → fragen (Standard Englisch)
[ -n "$SPR" ] || SPR=$(sed -n 's/^RC_LANG=//p' .env 2>/dev/null | tail -1 || true)
if [ "$SPR" != "de" ] && [ "$SPR" != "en" ]; then
  SPR="en"
  if [ -t 0 ]; then
    echo ""
    echo "  ${Y}${Z_FRAGE}${N} ${B}Language / Sprache:${N}   ${C}1${N}) English   ${C}2${N}) Deutsch"
    read -r -p "    [1] " wahl </dev/tty || true
    case "${wahl:-1}" in 2|de|d|deutsch|Deutsch) SPR="de" ;; esac
  fi
fi
s() { if [ "$SPR" = "de" ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }   # s "deutsch" "english"
say() { # Meldung je Art einfaerben: „==> Fertig/Done“ gruen, „==> “ Schritt, FEHLER/ERROR rot, eingerueckt = Detail
  local m; m=$(s "$1" "$2")
  m=$(printf '%s' "$m" | sed -E "s#(https?://[^ )\"']+)#${C}${U}\1${N}#g")
  case "$m" in
    "==> Fertig"*|"==> Done"*) echo ""; echo "${G}${B}${Z_OK} ${m#==> }${N}" ;;
    "==> "*) echo "${R}${B}${Z_SCHRITT}${N} ${B}${m#==> }${N}" ;;
    FEHLER:*|ERROR:*) echo "${R}${B}${Z_FEHLER} ${m}${N}" ;;
    "    FEHLER"*|"    ERROR"*) echo "  ${R}${Z_FEHLER}${N} ${m#    }" ;;
    "    "*) echo "  ${D}${K_V}${N} ${m#    }" ;;
    *) echo "$m" ;;
  esac
}

# Zum Testen: RC_DRY_RUN=1 zeigt Aenderungen am Webserver nur an, statt sie auszufuehren.
tu() { if [ "${RC_DRY_RUN:-}" = "1" ]; then echo "    ($(s Probelauf "dry run")) $*"; else "$@"; fi; }
frage() { # frage "Text" "Vorgabe" -> Antwort (ohne Terminal: Vorgabe)
  local antwort=""
  local text="$1"; text="${text#==> }"; text="${text#    }"
  if [ -t 0 ]; then read -r -p "  ${Y}${Z_FRAGE}${N} ${text} ${D}[$2]${N} " antwort </dev/tty || true; fi
  echo "${antwort:-$2}"
}
ja() { # ja "Text" "j|n" -> 0 bei ja (akzeptiert j/ja/y/yes)
  local vorgabe="$2" a
  [ "$SPR" = "en" ] && { [ "$vorgabe" = "j" ] && vorgabe="y"; }
  a=$(frage "$1 ($(s j/n y/n))" "$vorgabe"); case "${a,,}" in j|ja|y|yes) return 0 ;; *) return 1 ;; esac
}
belegt() { # lauscht etwas auf dem Port?
  if command -v ss >/dev/null 2>&1; then ss -ltnH "sport = :$1" 2>/dev/null | grep -q .
  else (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; fi
}
wer_lauscht() { ss -ltnpH "sport = :$1" 2>/dev/null | grep -o 'users:(("[^"]*"' | head -1 | sed 's/users:(("//'; }

# Deinstallieren: Container weg, Webserver-Eintraege weg (mit Backup), auf Wunsch auch alle Daten und der Ordner
if [ -n "$WEG" ]; then
  say "==> RedClub entfernen (Ordner: $PWD)" "==> Removing RedClub (folder: $PWD)"
  daten="nein"
  if ja "    $(s "Auch ALLE Vereinsdaten (Datenbank, Belege, Dokumente) loeschen? Das laesst sich nicht rueckgaengig machen." "Also delete ALL club data (database, receipts, documents)? This cannot be undone.")" "n"; then
    wort=$(s loeschen delete)
    bestaetigt=$(frage "    $(s "Zur Bestaetigung bitte  $wort  eintippen" "To confirm, please type  $wort")" "")
    [ "$bestaetigt" = "$wort" ] && daten="ja" || say "    Nicht bestaetigt — Dateien und Datenbank bleiben erhalten." "    Not confirmed — files and database are kept."
  fi
  if [ -f docker-compose.yml ] && command -v docker >/dev/null 2>&1; then
    if [ "$daten" = "ja" ]; then docker compose down -v --remove-orphans || true; else docker compose down --remove-orphans || true; fi
    docker image rm ghcr.io/theredstonee/redclub:latest >/dev/null 2>&1 || true
  fi
  # Update-Dienst
  if [ -f /etc/systemd/system/redclub-update.path ]; then
    systemctl disable --now redclub-update.path >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/redclub-update.path /etc/systemd/system/redclub-update.service /usr/local/bin/redclub-update
    systemctl daemon-reload || true
  fi
  stempel=$(date +%Y%m%d-%H%M%S); neu_laden=""
  for datei in /etc/nginx/sites-enabled/redclub.conf /etc/nginx/sites-enabled/redclub-setup.conf /etc/nginx/sites-available/redclub.conf /etc/nginx/sites-available/redclub-setup.conf \
               /etc/nginx/conf.d/redclub.conf /etc/nginx/conf.d/redclub-setup.conf /etc/apache2/sites-enabled/redclub.conf /etc/apache2/sites-enabled/redclub-setup.conf \
               /etc/apache2/sites-available/redclub.conf /etc/apache2/sites-available/redclub-setup.conf /etc/httpd/conf.d/redclub.conf /etc/httpd/conf.d/redclub-setup.conf; do
    if [ -L "$datei" ]; then rm -f "$datei"; neu_laden="ja"
    elif [ -f "$datei" ]; then mkdir -p /root/redclub-backup && cp -a "$datei" "/root/redclub-backup/$(basename "$datei").bak-$stempel" && rm -f "$datei"; neu_laden="ja"; fi
  done
  if [ -n "$neu_laden" ]; then
    if command -v nginx >/dev/null 2>&1 && nginx -t >/dev/null 2>&1; then systemctl reload nginx 2>/dev/null || nginx -s reload; fi
    if command -v apache2ctl >/dev/null 2>&1 && apache2ctl configtest >/dev/null 2>&1; then systemctl reload apache2; fi
    say "==> Webserver-Eintraege entfernt (Sicherung in /root/redclub-backup)." "==> Web server entries removed (backup in /root/redclub-backup)."
  fi
  dom=$(sed -n 's/^RC_PROXY_DOMAIN=//p' .env 2>/dev/null | tail -1 || true)
  if [ -n "$dom" ] && command -v certbot >/dev/null 2>&1 && certbot certificates 2>/dev/null | grep -q "Certificate Name: $dom$"; then
    ja "    $(s "Zertifikat fuer $dom auch loeschen?" "Also delete the certificate for $dom?")" "n" && certbot delete --cert-name "$dom" -n || true
  fi
  if [ "$daten" = "ja" ]; then
    ordner="$PWD"; cd /
    if ja "    $(s "Ordner $ordner auch loeschen (inkl. .env)?" "Also delete the folder $ordner (incl. .env)?")" "j"; then rm -rf "$ordner"; say "==> Ordner entfernt." "==> Folder removed."; fi
    say "==> RedClub ist vollstaendig entfernt." "==> RedClub has been removed completely."
  else
    say "==> Container gestoppt und entfernt. Dateien, Datenbank und dieser Ordner sind noch da —" "==> Containers stopped and removed. Files, database and this folder are still there —"
    say "    neu starten mit  sudo bash install.sh  (gleiches Datenbank-Passwort aus der .env)." "    start again with  sudo bash install.sh  (same database password from .env)."
  fi
  exit 0
fi

say "==> RedClub wird eingerichtet" "==> Setting up RedClub"

# 1. Docker (falls noch nicht da)
if ! command -v docker >/dev/null 2>&1; then
  say "==> Docker wird installiert …" "==> Installing Docker …"
  curl -fsSL https://get.docker.com | sh
fi
docker compose version >/dev/null 2>&1 || { say "FEHLER: 'docker compose' fehlt. Bitte Docker aktualisieren." "ERROR: 'docker compose' is missing. Please update Docker."; exit 1; }
for f in docker-compose.yml compose.caddy.yml compose.port.yml compose.reddrop.yml Caddyfile; do
  [ -f "$f" ] || curl -fsSL -o "$f" "$QUELLE/$f" || { say "FEHLER: $f fehlt neben install.sh und konnte nicht geladen werden." "ERROR: $f is missing next to install.sh and could not be downloaded."; exit 1; }
done

# 2. Bei wenig Arbeitsspeicher eine Auslagerungsdatei anlegen (unter 1,5 GB RAM, noch kein Swap)
ram_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
if [ "$ram_mb" -lt 1500 ] && [ "$(swapon --noheadings 2>/dev/null | wc -l)" -eq 0 ] && [ ! -f /swapfile ]; then
  say "==> Nur ${ram_mb} MB RAM: lege 1 GB Auslagerungsdatei an …" "==> Only ${ram_mb} MB RAM: creating a 1 GB swap file …"
  fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# 3. .env: Datenbank-Passwort nur beim ersten Mal (sonst passt es nicht mehr zur Datenbank)
if [ ! -f .env ]; then
  printf 'DB_PASSWORD=%s\nTZ=Europe/Berlin\n' "$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')" > .env
  chmod 600 .env
  say "==> .env mit zufaelligem Datenbank-Passwort angelegt" "==> Created .env with a random database password"
fi
# Sprache merken — gilt auch fuer den Einrichtungs-Assistenten
if grep -q '^RC_LANG=' .env; then sed -i "s/^RC_LANG=.*/RC_LANG=$SPR/" .env; else echo "RC_LANG=$SPR" >> .env; fi

# 4. Weg nach aussen festlegen — nur, solange die .env noch keinen kennt
if ! grep -q '^COMPOSE_FILE=' .env; then
  # Bestehende Installation mit altem Compose (Caddy stand noch in docker-compose.yml): Caddy behalten.
  if [ -z "$MODUS" ] && docker ps --filter "label=com.docker.compose.service=caddy" --format '{{.Label "com.docker.compose.project.working_dir"}}' 2>/dev/null | grep -qx "$PWD"; then
    MODUS="caddy"
  fi
  if [ -z "$MODUS" ]; then
    if belegt 80 || belegt 443; then
      server=$(wer_lauscht 80 || true); [ -n "$server" ] || server=$(wer_lauscht 443 || true)
      echo ""
      say "==> Port 80/443 sind schon belegt (${server:-unbekannter Dienst})." "==> Port 80/443 are already in use (${server:-unknown service})."
      say "    RedClub bekommt dann einen eigenen Port auf 127.0.0.1, und dein Webserver" "    RedClub then gets its own port on 127.0.0.1, and your web server"
      say "    leitet die Domain dorthin weiter (Virtual Host, HTTPS ueber deinen Webserver)." "    forwards the domain to it (virtual host, HTTPS via your web server)."
      if ja "    $(s "So einrichten? Bei Nein versucht Caddy, Port 80/443 selbst zu belegen." "Set it up this way? If not, Caddy tries to take port 80/443 itself.")" "j"; then MODUS="port"; else MODUS="caddy"; fi
    else
      MODUS="caddy"
    fi
  fi

  if [ "$MODUS" = "port" ]; then
    if [ -z "$PORT" ]; then
      for p in 8080 8081 8082 8088 8090 8100 8180 8280 3100 3200 9080; do belegt "$p" || { PORT=$p; break; }; done
      [ -n "$PORT" ] || { say "FEHLER: kein freier Port gefunden. Bitte mit --port angeben." "ERROR: no free port found. Please pass one with --port."; exit 1; }
      PORT=$(frage "    $(s "Port fuer RedClub (frei)" "Port for RedClub (free)")" "$PORT")
    fi
    belegt "$PORT" && { say "FEHLER: Port $PORT ist belegt." "ERROR: port $PORT is in use."; exit 1; }
    [ -n "$DOMAIN" ] || DOMAIN=$(frage "    $(s "Domain, unter der das Panel laufen soll (leer = spaeter)" "Domain for the panel (empty = later)")" "")
    DOMAIN="${DOMAIN,,}"
    {
      echo "COMPOSE_FILE=docker-compose.yml:compose.port.yml"
      echo "RC_PORT=$PORT"
      echo "RC_BIND=127.0.0.1"
      echo "RC_PROXY_DOMAIN=$DOMAIN"
    } >> .env
    say "==> App hoert auf 127.0.0.1:$PORT (ohne eigenen Caddy)" "==> App listens on 127.0.0.1:$PORT (without its own Caddy)"
  else
    echo "COMPOSE_FILE=docker-compose.yml:compose.caddy.yml" >> .env
    say "==> Caddy uebernimmt Port 80/443 und holt das Zertifikat selbst" "==> Caddy takes port 80/443 and gets the certificate by itself"
  fi
fi
# Werte aus der .env (auch bei einem zweiten Aufruf)
PORT=$(sed -n 's/^RC_PORT=//p' .env | tail -1)
[ -n "$DOMAIN" ] || DOMAIN=$(sed -n 's/^RC_PROXY_DOMAIN=//p' .env | tail -1)
grep -q 'compose.port.yml' .env && MODUS="port" || MODUS="caddy"
# --domain beim zweiten Aufruf: in der .env nachtragen, damit der Assistent sie vorwaehlt
if [ "$MODUS" = "port" ] && [ -n "$DOMAIN" ]; then
  [[ "$DOMAIN" =~ ^[a-z0-9.-]+$ ]] || { say "FEHLER: ungueltige Domain: $DOMAIN" "ERROR: invalid domain: $DOMAIN"; exit 1; }
  if grep -q '^RC_PROXY_DOMAIN=' .env; then sed -i "s|^RC_PROXY_DOMAIN=.*|RC_PROXY_DOMAIN=$DOMAIN|" .env; else echo "RC_PROXY_DOMAIN=$DOMAIN" >> .env; fi
fi

# 4b. RedDrop (Dateien & Fotos) im selben Compose — nur mit eigenem Caddy, einmalig gefragt
if [ "$MODUS" = "caddy" ] && ! grep -q '^REDDROP_GEFRAGT=' .env; then
  echo "REDDROP_GEFRAGT=1" >> .env
  echo ""
  say "==> RedDrop: Datei- und Foto-Hosting fuer den Verein (Galerie im Mitgliederbereich, Upload-Links)." "==> RedDrop: file and photo hosting for the club (gallery in the members area, upload links)."
  if ja "    $(s "RedDrop gleich mit installieren? Braucht eine eigene Domain." "Install RedDrop as well? Needs its own domain.")" "n"; then
    RDOM=$(frage "    $(s "Domain fuer RedDrop (z. B. dateien.meinverein.de)" "Domain for RedDrop (e.g. files.myclub.org)")" "")
    RDOM="${RDOM,,}"
    if [[ "$RDOM" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]]; then
      sed -i 's|^COMPOSE_FILE=docker-compose.yml:compose.caddy.yml$|COMPOSE_FILE=docker-compose.yml:compose.caddy.yml:compose.reddrop.yml|' .env
      { echo "RC_REDDROP_DOMAIN=$RDOM"; echo "REDDROP_DB_PASSWORD=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"; } >> .env
      say "==> RedDrop kommt unter https://$RDOM dazu (DNS-Eintrag auf diesen Server nicht vergessen)" "==> RedDrop will run at https://$RDOM (remember the DNS record pointing to this server)"
    else
      say "    Keine gueltige Domain — RedDrop wird nicht installiert (spaeter: compose.reddrop.yml in COMPOSE_FILE)." "    No valid domain — RedDrop is not installed (later: add compose.reddrop.yml to COMPOSE_FILE)."
    fi
  fi
fi

# 5. Starten
if [ -d .output ]; then docker compose up -d --build; else docker compose pull && docker compose up -d; fi

# 5b. Update-Dienst: der Knopf „Jetzt aktualisieren“ im Panel legt eine Anfrage-Datei in /data ab, ein
#     systemd-Pfad-Dienst auf dem Server zieht dann das neue Image und startet die App neu. So braucht
#     RedClub selbst keinen Zugriff auf Docker.
updater_einrichten() {
  command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] || return 0
  local app daten
  app=$(docker compose ps -q app 2>/dev/null || true)
  [ -n "$app" ] || return 0
  daten=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' "$app" 2>/dev/null || true)
  [ -n "$daten" ] && [ -d "$daten" ] || return 0
  cat > /usr/local/bin/redclub-update <<SKRIPT
#!/usr/bin/env bash
# RedClub — Update auf Anfrage aus dem Panel (angelegt von install.sh, systemd: redclub-update.path)
set -uo pipefail
DIR="$PWD"; DATEN="$daten"
[ -f "\$DATEN/.update-anfrage" ] || exit 0
aktion=\$(sed -n 's/.*"aktion":"\([a-z-]*\)".*/\1/p' "\$DATEN/.update-anfrage")
tok=\$(sed -n 's#.*"token":"\([A-Za-z0-9+/=_-]*\)".*#\1#p' "\$DATEN/.update-anfrage")
rm -f "\$DATEN/.update-anfrage"
status() { printf '{"status":"%s","zeit":"%s","meldung":"%s"}\n' "\$2" "\$(date -Is)" "\$3" > "\$DATEN/\$1"; chmod 644 "\$DATEN/\$1"; }
kurz() { echo "\$1" | tail -3 | tr '\n"\\\\' '   '; }
profil() { # profil an|aus name — Profil in COMPOSE_PROFILES der .env
  local n="\$2" p; p=\$(sed -n 's/^COMPOSE_PROFILES=//p' .env | tail -1 | tr ',' ' ')
  p=\$(echo " \$p " | sed "s/ \$n / /g" | xargs)
  [ "\$1" = "an" ] && p=\$(echo "\$p \$n" | xargs)
  sed -i '/^COMPOSE_PROFILES=/d' .env
  [ -z "\$p" ] || echo "COMPOSE_PROFILES=\$(echo "\$p" | tr ' ' ',')" >> .env
}
cd "\$DIR" || { status .update-status fehler "Ordner \$DIR fehlt"; exit 1; }
case "\${aktion:-update}" in
  tunnel-an)
    status .tunnel-status laeuft ""
    [ -n "\$tok" ] || { status .tunnel-status fehler "Kein Tunnel-Token in der Anfrage"; exit 1; }
    sed -i '/^RC_TUNNEL_TOKEN=/d' .env; echo "RC_TUNNEL_TOKEN=\$tok" >> .env; chmod 600 .env
    profil an tunnel
    if out=\$(docker compose up -d cloudflared 2>&1); then status .tunnel-status fertig ""; else status .tunnel-status fehler "\$(kurz "\$out")"; fi ;;
  tunnel-aus)
    status .tunnel-status laeuft ""
    if out=\$(docker compose stop cloudflared 2>&1 && docker compose rm -f cloudflared 2>&1); then profil aus tunnel; sed -i '/^RC_TUNNEL_TOKEN=/d' .env; status .tunnel-status fertig ""
    else status .tunnel-status fehler "\$(kurz "\$out")"; fi ;;
  *)
    status .update-status laeuft ""
    dienste="app"; grep -q '^COMPOSE_PROFILES=.*tunnel' .env && dienste="\$dienste cloudflared"
    if out=\$(docker compose pull \$dienste 2>&1 && docker compose up -d \$dienste 2>&1); then status .update-status fertig ""
    else status .update-status fehler "\$(kurz "\$out")"; fi ;;
esac
SKRIPT
  chmod 755 /usr/local/bin/redclub-update
  printf '%s\n' "[Unit]" "Description=RedClub: Update-Anfrage aus dem Panel" "[Path]" "PathExists=$daten/.update-anfrage" "[Install]" "WantedBy=multi-user.target" > /etc/systemd/system/redclub-update.path
  printf '%s\n' "[Unit]" "Description=RedClub aktualisieren" "[Service]" "Type=oneshot" "ExecStart=/usr/local/bin/redclub-update" > /etc/systemd/system/redclub-update.service
  systemctl daemon-reload && systemctl enable --now redclub-update.path >/dev/null 2>&1 || return 0
  printf '%s\naktionen=update tunnel\n' "$PWD" > "$daten/.updater"; chmod 644 "$daten/.updater"
  say "==> Update-Dienst eingerichtet (Panel → Version unten links → „Jetzt aktualisieren“)" "==> Update service set up (panel → version at the bottom left → “Update now”)"
}
updater_einrichten

# 6. Virtual Host fuer die Domain in deinem Webserver (nur im Port-Modus, nur mit Domain).
#    Als Funktion: laeuft auch nach der Einrichtung ueber den Kurzzeit-Link (Schritt 9) mit der dort gewaehlten Domain.
vhost_angelegt=""; fremd=""
vhost_einrichten() {
if [ "$MODUS" = "port" ] && [ -n "$DOMAIN" ] && [ "$VHOST" = "ja" ]; then
  webserver=""
  if command -v nginx >/dev/null 2>&1; then webserver="nginx"
  elif command -v apache2ctl >/dev/null 2>&1; then webserver="apache2"
  elif command -v httpd >/dev/null 2>&1; then webserver="httpd"
  fi
  # Gibt es fuer die Domain schon einen fremden Eintrag (z. B. eine alte Vereinsseite)? Dann nichts anfassen — umstellen
  # ist ein bewusster Schritt (siehe Umzug unten), sonst stritten sich zwei Eintraege um die Domain.
  fremd=$(grep -RlsE "^[[:space:]]*(server_name|ServerName|ServerAlias)[[:space:]]+(.*[[:space:]])?${DOMAIN//./\\.}([[:space:];]|$)" /etc/nginx/sites-enabled /etc/nginx/conf.d /etc/apache2/sites-enabled /etc/httpd/conf.d 2>/dev/null | grep -v 'redclub' | head -1 || true)
  # Zeigt der Eintrag schon auf RedClub (z. B. nach dem Umstellen)? Dann ist alles erledigt.
  if [ -n "$fremd" ] && grep -qE "(proxy_pass|ProxyPass[[:space:]]+/)[[:space:]]+http://(127\.0\.0\.1|localhost):${PORT}(/|;|[[:space:]]|$)" "$fremd"; then
    say "==> $DOMAIN zeigt schon auf RedClub ($fremd)." "==> $DOMAIN already points to RedClub ($fremd)."
    fremd=""; webserver=""; vhost_angelegt="vorhanden"; https_ok=1
  fi
  if [ -n "$fremd" ]; then
    say "==> Fuer $DOMAIN gibt es schon einen Eintrag: $fremd — den fasse ich nicht an." "==> There is already an entry for $DOMAIN: $fremd — I will not touch it."
    webserver=""
  fi
  if [ -n "$webserver" ] && ja "==> $(s "Virtual Host fuer $DOMAIN in $webserver anlegen (Backup vorhandener Dateien, Konfigtest, Neuladen)?" "Create a virtual host for $DOMAIN in $webserver (backup of existing files, config test, reload)?")" "j"; then
    stempel=$(date +%Y%m%d-%H%M%S)
    if [ "$webserver" = "nginx" ]; then
      if [ -d /etc/nginx/sites-enabled ]; then datei=/etc/nginx/sites-available/redclub.conf; link=/etc/nginx/sites-enabled/redclub.conf
      else datei=/etc/nginx/conf.d/redclub.conf; link=""; fi
      inhalt="# RedClub — angelegt von install.sh am $stempel
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    client_max_body_size 110m;
    proxy_request_buffering off;
    proxy_read_timeout 3600s;
    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}"
      [ -f "$datei" ] && tu cp -a "$datei" "$datei.bak-$stempel"
      if [ "${RC_DRY_RUN:-}" = "1" ]; then echo "    ($(s Probelauf "dry run")) $datei:"; echo "$inhalt" | sed 's/^/        /'; else printf '%s\n' "$inhalt" > "$datei"; fi
      [ -n "$link" ] && tu ln -sf "$datei" "$link"
      if tu nginx -t; then tu systemctl reload nginx 2>/dev/null || tu nginx -s reload; vhost_angelegt="$webserver"
      else say "    FEHLER: nginx -t schlaegt fehl — Datei $datei bitte pruefen (Backup: $datei.bak-$stempel)." "    ERROR: nginx -t fails — please check $datei (backup: $datei.bak-$stempel)."; fi
    else
      if [ "$webserver" = "apache2" ]; then datei=/etc/apache2/sites-available/redclub.conf; else datei=/etc/httpd/conf.d/redclub.conf; fi
      inhalt="# RedClub — angelegt von install.sh am $stempel
<VirtualHost *:80>
    ServerName $DOMAIN
    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:$PORT/
    ProxyPassReverse / http://127.0.0.1:$PORT/
    RequestHeader set X-Forwarded-Proto \"expr=%{REQUEST_SCHEME}\"
</VirtualHost>"
      [ -f "$datei" ] && tu cp -a "$datei" "$datei.bak-$stempel"
      if [ "${RC_DRY_RUN:-}" = "1" ]; then echo "    ($(s Probelauf "dry run")) $datei:"; echo "$inhalt" | sed 's/^/        /'; else printf '%s\n' "$inhalt" > "$datei"; fi
      if [ "$webserver" = "apache2" ]; then
        tu a2enmod -q proxy proxy_http headers
        tu a2ensite -q redclub.conf
        if tu apache2ctl configtest; then tu systemctl reload apache2; vhost_angelegt="$webserver"; else say "    FEHLER: Apache-Konfigtest schlaegt fehl — $datei bitte pruefen." "    ERROR: Apache config test fails — please check $datei."; fi
      else
        if tu httpd -t; then tu systemctl reload httpd; vhost_angelegt="$webserver"; else say "    FEHLER: httpd -t schlaegt fehl — $datei bitte pruefen." "    ERROR: httpd -t fails — please check $datei."; fi
      fi
    fi
  elif [ -z "$webserver" ] && [ -z "$fremd" ] && [ "$vhost_angelegt" != "vorhanden" ]; then
    say "==> Keinen nginx/Apache gefunden — die Vorlage fuer deinen Webserver steht unten." "==> No nginx/Apache found — the template for your web server is shown below."
  fi

  # 7. Zertifikat per certbot (HTTP-01 ueber den gerade angelegten Virtual Host)
  if [ -n "$vhost_angelegt" ] && [ "$vhost_angelegt" != "vorhanden" ]; then
    plugin="nginx"; [ "$vhost_angelegt" = "nginx" ] || plugin="apache"
    meine_ip=$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)
    domain_ip=$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk '{print $1; exit}' || true)
    if [ -n "$meine_ip" ] && [ "$domain_ip" != "$meine_ip" ]; then
      say "==> $DOMAIN zeigt auf '${domain_ip:-nichts}', dieser Server hat $meine_ip — Zertifikat spaeter holen:" "==> $DOMAIN points to '${domain_ip:-nothing}', this server has $meine_ip — get the certificate later:"
      echo "    certbot --$plugin -d $DOMAIN --redirect"
    elif ja "==> $(s "HTTPS-Zertifikat fuer $DOMAIN mit certbot holen (Let's Encrypt)?" "Get an HTTPS certificate for $DOMAIN with certbot (Let's Encrypt)?")" "j"; then
      if ! command -v certbot >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then tu apt-get install -y -qq certbot "python3-certbot-$plugin"
        elif command -v dnf >/dev/null 2>&1; then tu dnf install -y -q certbot "python3-certbot-$plugin"
        else say "    certbot fehlt und konnte nicht installiert werden — bitte von Hand: certbot --$plugin -d $DOMAIN --redirect" "    certbot is missing and could not be installed — please run by hand: certbot --$plugin -d $DOMAIN --redirect"; fi
      fi
      if command -v certbot >/dev/null 2>&1 || [ "${RC_DRY_RUN:-}" = "1" ]; then
        [ -n "$EMAIL" ] || EMAIL=$(frage "    $(s "E-Mail fuer Ablauf-Hinweise von Let's Encrypt (leer = keine)" "Email for Let's Encrypt expiry notices (empty = none)")" "")
        if [ -n "$EMAIL" ]; then mail_arg=(-m "$EMAIL"); else mail_arg=(--register-unsafely-without-email); fi
        if tu certbot "--$plugin" -d "$DOMAIN" --redirect -n --agree-tos "${mail_arg[@]}"; then https_ok=1
        else say "    certbot hat nicht geklappt (Ausgabe oben). Spaeter nochmal: certbot --$plugin -d $DOMAIN --redirect" "    certbot did not work (output above). Try again later: certbot --$plugin -d $DOMAIN --redirect"; fi
      fi
    fi
  fi
fi
}
vhost_einrichten

# 8. Auf die App warten und den Setup-Code zeigen
say "==> Warte auf den Start …" "==> Waiting for the start …"
for n in $(seq 1 60); do
  if docker compose logs app 2>/dev/null | grep -q 'Setup-Code\|bereit\|ready'; then break; fi
  for k in 0 1 2 3 4 5 6 7; do [ -t 1 ] && printf '\r  %s%s%s %s' "$R" "${SPIN[$(( (n * 8 + k) % ${#SPIN[@]} ))]}" "$N" "$(s "RedClub startet" "RedClub is starting") ($((n * 2)) s)"; sleep 0.25; done
done
[ -t 1 ] && printf '\r\033[K'
# IP fuer Links und Kurzzeit-Eintrag: die oeffentliche nur, wenn sie auf dem Server selbst liegt (VPS).
# Sonst steht der Server hinter einem Router (Heimnetz) — dann die IP, ueber die er ins Netz geht.
ip_pub=$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)
ip_lan=$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p' | head -1 || true)
[ -n "$ip_lan" ] || ip_lan=$(hostname -I 2>/dev/null | awk '{print $1}')
hinter_router=""
if [ -n "$ip_pub" ] && ip -4 addr 2>/dev/null | grep -qF "inet ${ip_pub}/"; then ip="$ip_pub"
elif [ -n "$ip_lan" ]; then ip="$ip_lan"; [ -n "$ip_pub" ] && [ "$ip_pub" != "$ip_lan" ] && hinter_router="ja"
else ip="$ip_pub"; fi
code=$(docker compose logs app 2>/dev/null | grep -o 'Setup-Code: *[A-F0-9]\{4\}-[A-F0-9]\{4\}' | tail -1 | sed 's/.*: *//' || true)
echo ""
if [ -n "$code" ]; then
  kasten "$R" "$(s "Setup-Code" "Setup code"):  $code" "$(s "Brauchst du gleich im Browser." "You need it in the browser in a moment.")"
else
  docker compose logs app 2>/dev/null | grep -A1 -B2 'Setup-Code' | tail -5 || true
fi
echo ""

# 9. Kurzzeit-Link: Port-Modus ohne Domain → die Einrichtung voruebergehend ueber http://<Server-IP> erlauben.
#    Ein eigener Eintrag NUR fuer die IP (andere Domains im Webserver bleiben unberuehrt), geschuetzt durch
#    den Setup-Code; nach der Einrichtung (oder bei Abbruch) wird er wieder entfernt. Wurde im Assistenten
#    eine Domain eingetragen, bekommt sie danach ihren Virtual Host und das Zertifikat.
setup_wert() { docker compose exec -T db psql -U redclub -d redclub -tAc "SELECT coalesce(value->>'$2', '') FROM settings WHERE key = '$1'" 2>/dev/null | tr -d '[:space:]'; }
setup_fertig() { [ "$(setup_wert setup done)" = "true" ]; }
kurz_datei=""; kurz_link=""; kurz_web=""; direkt_url=""
direkt_freigeben() { # App direkt im Netz erreichbar: Port auf allen Schnittstellen statt nur 127.0.0.1
  if grep -q '^RC_BIND=' .env; then sed -i 's|^RC_BIND=.*|RC_BIND=0.0.0.0|' .env; else echo "RC_BIND=0.0.0.0" >> .env; fi
  tu docker compose up -d app >/dev/null 2>&1 || true
  direkt_url="http://${ip}:${PORT}"
  echo ""
  say "==> RedClub ist jetzt direkt erreichbar:  ${direkt_url}" "==> RedClub is now directly reachable:  ${direkt_url}"
  say "    Gib dort den Setup-Code von oben ein und waehle „Nur ueber die IP“. Eine Domain geht spaeter:  sudo bash install.sh --domain verein.deinverein.de" "    Enter the setup code from above there and choose “IP address only”. A domain works later:  sudo bash install.sh --domain verein.example.com"
  say "    Firewall: Port ${PORT}/tcp muss erreichbar sein." "    Firewall: port ${PORT}/tcp must be reachable."
  [ -n "$hinter_router" ] && say "    Von ausserhalb deines Netzes nur mit Portweiterleitung im Router (${ip_pub}:${PORT} → ${ip}:${PORT}) — oder per Cloudflare Tunnel im Panel." "    From outside your network only with port forwarding in your router (${ip_pub}:${PORT} → ${ip}:${PORT}) — or via Cloudflare Tunnel in the panel."
  return 0
}
kurz_weg() {
  [ -n "$kurz_datei" ] || return 0
  if [ "$kurz_web" = "apache2" ]; then a2dissite -q redclub-setup.conf >/dev/null 2>&1 || true; fi
  rm -f "$kurz_datei" ${kurz_link:+"$kurz_link"}
  case "$kurz_web" in nginx) nginx -t >/dev/null 2>&1 && { systemctl reload nginx 2>/dev/null || nginx -s reload; } ;; apache2) systemctl reload apache2 ;; httpd) systemctl reload httpd ;; esac
  say "==> Kurzzeit-Eintrag fuer http://${ip} wieder entfernt." "==> Temporary entry for http://${ip} removed again."
  kurz_datei=""
}
# 10. Unter der Domain laeuft schon ein anderer Dienst (eigener Eintrag im Webserver): auf Wunsch umstellen.
#     Der alte Eintrag wird vorher gesichert; ein Zurueck ist jederzeit moeglich.
umzug_anbieten() {
  local ziel port zc zbild stempel sicher datei ok=""
  datei=$(readlink -f "$fremd")
  ziel=$(grep -oE '(proxy_pass|ProxyPass[[:space:]]+/)[[:space:]]+https?://[^;[:space:]]+' "$datei" | head -1 | awk '{print $NF}' | sed 's#/$##')
  port=$(echo "$ziel" | sed -nE 's#^https?://[^/]+:([0-9]+).*#\1#p')
  zc=""; zbild=""
  if [ -n "$port" ]; then
    zc=$(docker ps --format '{{.Names}} {{.Ports}}' | grep -E ":${port}->" | awk '{print $1}' | head -1 || true)
    [ -n "$zc" ] && zbild=$(docker inspect -f '{{.Config.Image}}' "$zc" 2>/dev/null || true)
  fi
  echo ""
  say "==> $DOMAIN zeigt bisher auf ${ziel:-einen anderen Dienst}${zc:+ (Container $zc, $zbild)}." "==> $DOMAIN currently points to ${ziel:-another service}${zc:+ (container $zc, $zbild)}."
  ja "    $(s "$DOMAIN auf RedClub umstellen? (Der bisherige Dienst ist unter dieser Domain dann nicht mehr erreichbar.)" "Switch $DOMAIN to RedClub? (The previous service is then no longer reachable under this domain.)")" "n" || return 1
  # Domain umstellen: im vorhandenen Eintrag nur das Ziel tauschen — Zertifikat und alles andere bleibt
  stempel=$(date +%Y%m%d-%H%M%S); mkdir -p /root/redclub-backup
  sicher="/root/redclub-backup/$(basename "$datei").bak-$stempel"
  cp -a "$datei" "$sicher"
  sed -i -E "s#(proxy_pass[[:space:]]+)https?://[^;[:space:]]+#\1http://127.0.0.1:${PORT}#; s#(ProxyPass(Reverse)?[[:space:]]+/[[:space:]]+)https?://[^[:space:]]+#\1http://127.0.0.1:${PORT}/#" "$datei"
  if grep -q 'proxy_pass' "$datei" && ! grep -q 'proxy_set_header[[:space:]]\+Host' "$datei"; then
    sed -i -E "s#^([[:space:]]*)(proxy_pass[[:space:]]+http://127\.0\.0\.1:${PORT};)#\1\2\n\1proxy_set_header Host \$host;\n\1proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n\1proxy_set_header X-Forwarded-Proto \$scheme;#" "$datei"
  fi
  if grep -q 'proxy_pass' "$datei" && ! grep -q 'client_max_body_size' "$datei"; then
    sed -i -E "s#^([[:space:]]*)(proxy_pass[[:space:]]+http://127\.0\.0\.1:${PORT};)#\1\2\n\1client_max_body_size 110m;#" "$datei"
  fi
  if grep -q 'proxy_pass' "$datei"; then nginx -t >/dev/null 2>&1 && { systemctl reload nginx 2>/dev/null || nginx -s reload; ok=1; }
  elif command -v apache2ctl >/dev/null 2>&1; then apache2ctl configtest >/dev/null 2>&1 && { systemctl reload apache2; ok=1; }
  elif command -v httpd >/dev/null 2>&1; then httpd -t >/dev/null 2>&1 && { systemctl reload httpd; ok=1; }
  fi
  if [ -z "$ok" ]; then
    cp -a "$sicher" "$datei"
    say "    FEHLER: Konfigtest nach dem Umstellen fehlgeschlagen — alter Stand wiederhergestellt ($sicher)." "    ERROR: config test failed after switching — previous state restored ($sicher)."; return 1
  fi
  say "==> $DOMAIN zeigt jetzt auf RedClub (alter Eintrag gesichert: $sicher)." "==> $DOMAIN now points to RedClub (old entry saved: $sicher)."
  echo ""
  say "==> Fertig. RedClub laeuft unter  https://${DOMAIN}" "==> Done. RedClub runs at  https://${DOMAIN}"
  return 0
}

# Schon eingerichtet und die Domain gehoert noch einem anderen Dienst? Dann das Umstellen anbieten.
if [ "$MODUS" = "port" ] && [ -n "$DOMAIN" ] && [ -n "$fremd" ] && [ "${RC_DRY_RUN:-}" != "1" ] && setup_fertig; then
  umzug_anbieten && exit 0
fi

# Kurzzeit-Link auch dann, wenn die Domain noch auf den alten Dienst zeigt (Einrichtung erst, dann Umstellen)
if [ "$MODUS" = "port" ] && [ -z "$vhost_angelegt" ] && { [ -z "$DOMAIN" ] || [ -n "$fremd" ]; } && [ "$VHOST" = "ja" ] && [[ "${ip:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && [ "${RC_DRY_RUN:-}" != "1" ] && ! setup_fertig; then
  if command -v nginx >/dev/null 2>&1; then kurz_web="nginx"
  elif command -v apache2ctl >/dev/null 2>&1; then kurz_web="apache2"
  elif command -v httpd >/dev/null 2>&1; then kurz_web="httpd"
  fi
  if [ -n "$kurz_web" ] && ja "==> $(s "Fuer die Einrichtung voruebergehend unter http://${ip} erreichbar machen? (eigener Eintrag nur fuer die IP, wird danach entfernt — bei Nein direkt unter http://${ip}:${PORT})" "Make it reachable at http://${ip} temporarily for the setup? (own entry for the IP only, removed afterwards — if no, directly at http://${ip}:${PORT})")" "j"; then
    if [ "$kurz_web" = "nginx" ]; then
      if [ -d /etc/nginx/sites-enabled ]; then kurz_datei=/etc/nginx/sites-available/redclub-setup.conf; kurz_link=/etc/nginx/sites-enabled/redclub-setup.conf
      else kurz_datei=/etc/nginx/conf.d/redclub-setup.conf; fi
      printf '%s\n' "# RedClub — nur fuer die Einrichtung, entfernt install.sh wieder" "server {" "    listen 80;" "    server_name ${ip}${hinter_router:+ $ip_pub};" "    client_max_body_size 110m;" \
        "    location / {" "        proxy_pass http://127.0.0.1:${PORT};" "        proxy_set_header Host \$host;" "        proxy_set_header X-Real-IP \$remote_addr;" \
        "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;" "        proxy_set_header X-Forwarded-Proto \$scheme;" "    }" "}" > "$kurz_datei"
      [ -n "$kurz_link" ] && ln -sf "$kurz_datei" "$kurz_link"
      if nginx -t >/dev/null 2>&1; then systemctl reload nginx 2>/dev/null || nginx -s reload; else say "    nginx -t schlaegt fehl — Kurzzeit-Eintrag wieder entfernt." "    nginx -t fails — temporary entry removed again."; kurz_weg; fi
    else
      if [ "$kurz_web" = "apache2" ]; then kurz_datei=/etc/apache2/sites-available/redclub-setup.conf; else kurz_datei=/etc/httpd/conf.d/redclub-setup.conf; fi
      printf '%s\n' "# RedClub — nur fuer die Einrichtung, entfernt install.sh wieder" "<VirtualHost *:80>" "    ServerName ${ip}" ${hinter_router:+"    ServerAlias ${ip_pub}"} "    ProxyPreserveHost On" \
        "    ProxyPass / http://127.0.0.1:${PORT}/" "    ProxyPassReverse / http://127.0.0.1:${PORT}/" "</VirtualHost>" > "$kurz_datei"
      if [ "$kurz_web" = "apache2" ]; then a2enmod -q proxy proxy_http >/dev/null; a2ensite -q redclub-setup.conf >/dev/null; apache2ctl configtest >/dev/null 2>&1 && systemctl reload apache2 || { say "    Apache-Konfigtest schlaegt fehl — Kurzzeit-Eintrag wieder entfernt." "    Apache config test fails — temporary entry removed again."; kurz_weg; }
      else httpd -t >/dev/null 2>&1 && systemctl reload httpd || { say "    httpd -t schlaegt fehl — Kurzzeit-Eintrag wieder entfernt." "    httpd -t fails — temporary entry removed again."; kurz_weg; }; fi
    fi
    if [ -n "$kurz_datei" ]; then
      trap 'echo; kurz_weg; exit 130' INT TERM
      trap 'kurz_weg' EXIT
      echo ""
      say "==> Oeffne jetzt im Browser:  http://${ip}   und gib den Setup-Code von oben ein." "==> Now open in your browser:  http://${ip}   and enter the setup code from above."
      say "    Waehle im Assistenten „Hinter eigenem Webserver“ und trage deine Domain ein — der Installer" "    In the wizard choose “Behind your web server” and enter your domain — the installer"
      say "    legt danach den Virtual Host und das Zertifikat dafuer an. (Strg+C bricht ab.)" "    then creates the virtual host and the certificate for it. (Ctrl+C cancels.)"
      [ -n "$fremd" ] && say "    Hinweis: $DOMAIN zeigt noch auf den alten Dienst — nach der Einrichtung fragt der Installer hier im Terminal, ob er sie umstellen soll." "    Note: $DOMAIN still points to the old service — after the setup the installer asks here in the terminal whether to switch it."
      echo -n "    $(s "Warte auf die Einrichtung" "Waiting for the setup") "
      for _ in $(seq 1 720); do setup_fertig && break; echo -n "."; sleep 10; done
      echo ""
      kurz_weg
      trap - INT TERM EXIT
      if setup_fertig; then
        neu=$(setup_wert net domain | tr 'A-Z' 'a-z' || true)
        if [[ "$neu" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]]; then
          DOMAIN="$neu"
          if grep -q '^RC_PROXY_DOMAIN=' .env; then sed -i "s|^RC_PROXY_DOMAIN=.*|RC_PROXY_DOMAIN=$DOMAIN|" .env; else echo "RC_PROXY_DOMAIN=$DOMAIN" >> .env; fi
          say "==> Einrichtung abgeschlossen. Domain aus dem Assistenten: $DOMAIN" "==> Setup complete. Domain from the wizard: $DOMAIN"
          vhost_einrichten
          if [ -n "$fremd" ]; then umzug_anbieten || true; exit 0; fi
          if [ -n "$vhost_angelegt" ]; then
            if [ -n "${https_ok:-}" ]; then say "==> Fertig. RedClub laeuft unter  https://${DOMAIN}" "==> Done. RedClub runs at  https://${DOMAIN}"; else say "==> Fertig. RedClub laeuft unter  http://${DOMAIN}  (HTTPS: certbot --nginx -d ${DOMAIN} --redirect)" "==> Done. RedClub runs at  http://${DOMAIN}  (HTTPS: certbot --nginx -d ${DOMAIN} --redirect)"; fi
            exit 0
          fi
        else
          say "==> Einrichtung abgeschlossen, aber ohne Domain. Spaeter:  sudo bash install.sh --domain verein.deinverein.de" "==> Setup complete, but without a domain. Later:  sudo bash install.sh --domain verein.example.com"
          exit 0
        fi
      else
        say "==> Zeit abgelaufen. Einfach nochmal:  sudo bash install.sh" "==> Time is up. Simply run again:  sudo bash install.sh"
        exit 0
      fi
    fi
  else
    direkt_freigeben   # „Nein“ oder kein Webserver: einfach die IP mit dem gewaehlten Port
  fi
fi
if [ -n "$direkt_url" ]; then
  say "==> Fertig. Oeffne im Browser:  ${direkt_url}" "==> Done. Open in your browser:  ${direkt_url}"
elif [ "$MODUS" = "port" ]; then
  if [ -n "$vhost_angelegt" ]; then
    if [ -n "${https_ok:-}" ]; then say "==> Fertig. Oeffne im Browser:  https://${DOMAIN}" "==> Done. Open in your browser:  https://${DOMAIN}"; else say "==> Fertig. Oeffne im Browser:  http://${DOMAIN}" "==> Done. Open in your browser:  http://${DOMAIN}"; fi
  else
    say "==> Fertig. Die App hoert auf 127.0.0.1:${PORT}. Trage in deinem Webserver einen Virtual Host ein:" "==> Done. The app listens on 127.0.0.1:${PORT}. Add a virtual host to your web server:"
    echo ""
    echo "    nginx:                                                 Apache:"
    echo "    server {                                               <VirtualHost *:80>"
    echo "        listen 80;                                             ServerName ${DOMAIN:-verein.example.com}"
    echo "        server_name ${DOMAIN:-verein.example.com};          ProxyPreserveHost On"
    echo "        location / {                                           ProxyPass / http://127.0.0.1:${PORT}/"
    echo "            proxy_pass http://127.0.0.1:${PORT};               ProxyPassReverse / http://127.0.0.1:${PORT}/"
    echo "            proxy_set_header Host \$host;                       RequestHeader set X-Forwarded-Proto \"expr=%{REQUEST_SCHEME}\""
    echo "            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;   </VirtualHost>"
    echo "            proxy_set_header X-Forwarded-Proto \$scheme;"
    echo "        }"
    echo "    }"
    echo ""
    say "    HTTPS danach z. B. mit:  certbot --nginx -d ${DOMAIN:-verein.example.com} --redirect" "    HTTPS afterwards e.g. with:  certbot --nginx -d ${DOMAIN:-verein.example.com} --redirect"
    say "    Zum Ausprobieren ohne Domain:  ssh -L ${PORT}:127.0.0.1:${PORT} root@${ip}  und dann  http://127.0.0.1:${PORT}" "    To try it without a domain:  ssh -L ${PORT}:127.0.0.1:${PORT} root@${ip}  and then  http://127.0.0.1:${PORT}"
  fi
  say "    Im Assistenten ist „Hinter eigenem Webserver“ mit deiner Domain schon vorgewaehlt." "    In the wizard, “Behind your web server” with your domain is already preselected."
else
  say "==> Fertig. Oeffne im Browser:  http://${ip}" "==> Done. Open in your browser:  http://${ip}"
  say "    Firewall: Port 80 und 443 muessen von aussen erreichbar sein." "    Firewall: port 80 and 443 must be reachable from outside."
fi
say "    Den Setup-Code siehst du oben (oder: docker compose logs app | grep Setup-Code)." "    You can see the setup code above (or: docker compose logs app | grep Setup-Code)."
# Abschluss: Adresse noch einmal gross
ziel_url=""
if [ -n "$direkt_url" ]; then ziel_url="$direkt_url"
elif [ "$MODUS" = "port" ] && [ -n "${vhost_angelegt:-}" ] && [ -n "${DOMAIN:-}" ]; then ziel_url="$([ -n "${https_ok:-}" ] && echo https || echo http)://${DOMAIN}"
elif [ "$MODUS" != "port" ]; then ziel_url="http://${ip}"; fi
if [ -n "$ziel_url" ]; then echo ""; kasten "$G" "RedClub  ${Z_PUNKT}  $ziel_url"; fi
echo ""
