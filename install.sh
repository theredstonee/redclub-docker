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
# Nur aktualisieren (nichts neu einrichten, keine Fragen):
#   curl -fsSL https://raw.githubusercontent.com/theredstonee/redclub-docker/main/update.sh | sudo bash
set -euo pipefail
QUELLE="${RC_QUELLE:-https://raw.githubusercontent.com/theredstonee/redclub-docker/main}"   # RC_QUELLE nur fuer Tests
DATEIEN="docker-compose.yml compose.caddy.yml compose.port.yml compose.reddrop.yml compose.hosting.yml compose.sftp.yml compose.phpdb.yml compose.mail.yml compose.mail-caddy.yml compose.mail-le.yml Caddyfile install.sh update.sh .env.example README.md version.json"
# Unraid: ausser /boot (USB-Stick) und /mnt (Array/Cache) liegt alles im Arbeitsspeicher — nach einem Neustart waeren
# Compose-Dateien und .env weg (die Datenbank im Docker-Volume bleibt, passt dann aber nicht mehr zu einer neuen .env).
# Darum gehoert die Installation dort nach /mnt/user/appdata/<Ordnername>: gleicher Name → gleicher Compose-Projektname
# → dieselben Volumes. unraid_ziel <ordner> gibt den dauerhaften Ordner aus, wenn <ordner> im Arbeitsspeicher liegt.
unraid_ziel() {
  [ -f /etc/unraid-version ] && [ -d /mnt/user ] || return 1
  case "$1" in /mnt/*|/boot/*) return 1 ;; esac
  printf '%s' "/mnt/user/appdata/$(basename "$1")"
}
# unraid_umziehen <alt> <neu> — Ordner kopieren, Dienst + Zeitplan auf den neuen Ordner umstellen, alten beiseitelegen.
# Die laufenden Container bleiben, bis sie aus dem neuen Ordner neu gestartet werden (Update/Installation tun das).
unraid_umziehen() {
  local alt="$1" neu="$2" a f
  [ -f "$alt/docker-compose.yml" ] || return 1
  if [ -e "$neu" ] && [ -n "$(ls -A "$neu" 2>/dev/null)" ]; then return 1; fi
  mkdir -p "$neu" && cp -a "$alt/." "$neu/" || { rm -rf "$neu"; return 1; }
  a=$(printf '%s' "$alt" | sed 's/[][\.*^$#]/\\&/g')
  for f in /usr/local/bin/redclub-update /boot/config/plugins/redclub/redclub-update /boot/config/plugins/dynamix/redclub-update.cron /etc/cron.d/root; do
    [ -f "$f" ] && sed -i "s#\\([=\"' ]\\)$a\\([/\"';]\\|\$\\)#\\1$neu\\2#g" "$f"
  done
  if [ -x /usr/local/sbin/update_cron ]; then /usr/local/sbin/update_cron >/dev/null 2>&1 || true; fi
  mv "$alt" "$alt.umgezogen-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
  return 0
}
UNRAID_ZIEL=""
if [ -z "${RC_DIR:-}" ] && [ -f /etc/unraid-version ] && [ -d /mnt/user ]; then
  UNRAID_ZIEL="/mnt/user/appdata/redclub"
  u_hier=""; if [ -f "$0" ] && [ -f "$(dirname "$0")/docker-compose.yml" ]; then u_hier="$(cd "$(dirname "$0")" && pwd)"; fi
  u_alt="${u_hier:-/opt/redclub}"
  if u_neu=$(unraid_ziel "$u_alt") && [ -f "$u_alt/docker-compose.yml" ]; then
    if unraid_umziehen "$u_alt" "$u_neu"; then
      echo "==> Unraid: $u_alt -> $u_neu (übersteht Neustarts / survives reboots)"
      UNRAID_ZIEL="$u_neu"
      if [ -n "$u_hier" ]; then
        cd "$u_neu"
        if { true </dev/tty; } 2>/dev/null; then exec bash ./install.sh "$@" </dev/tty; else exec bash ./install.sh "$@"; fi
      fi
    else
      echo "==> Unraid: $u_alt liegt im Arbeitsspeicher, $u_neu ist schon belegt — bitte selbst umziehen / in RAM, $u_neu is taken — please move it yourself"
      UNRAID_ZIEL=""
    fi
  fi
fi
# Ueber curl | bash gestartet (oder Dateien fehlen): alles nach /opt/redclub (Unraid: /mnt/user/appdata/redclub) holen und dort weitermachen
if [ -f "$0" ] && [ -f "$(dirname "$0")/docker-compose.yml" ]; then
  cd "$(dirname "$0")"
else
  ZIEL="${RC_DIR:-${UNRAID_ZIEL:-/opt/redclub}}"
  echo "==> RedClub: $ZIEL"
  mkdir -p "$ZIEL" && cd "$ZIEL"
  for f in $DATEIEN; do curl -fsSL -o "$f" "$QUELLE/$f" || { [ "$f" = "version.json" ] || { echo "ERROR: $f"; exit 1; }; }; done
  # Fragen brauchen das Terminal (stdin ist bei curl | bash die Leitung) — ohne Terminal gelten die Vorgaben
  # Rest des Skripts aus der curl-Leitung leer lesen: exec schliesst sie sonst, waehrend curl noch schreibt
  # (Meldung „curl: (23) Failure writing output to destination“ am Ende, obwohl alles geklappt hat)
  [ -t 0 ] || cat >/dev/null 2>&1 || true
  if { true </dev/tty; } 2>/dev/null; then exec bash ./install.sh "$@" </dev/tty; else exec bash ./install.sh "$@"; fi
fi

PORT=""; DOMAIN=""; EMAIL=""; MODUS=""; VHOST="ja"; WEG=""; SPR=""; NUR_DIENST=""
while [ $# -gt 0 ]; do
  case "$1" in
    --lang) SPR="${2,,}"; shift 2 ;;
    --port) PORT="$2"; MODUS="port"; shift 2 ;;
    --domain) DOMAIN="${2,,}"; shift 2 ;;
    --email) EMAIL="$2"; shift 2 ;;
    --caddy) MODUS="caddy"; shift ;;
    --no-vhost) VHOST="nein"; shift ;;
    --dienst) NUR_DIENST="ja"; shift ;;   # nur den Update-Dienst neu einrichten (ruft update.sh auf)
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
  rm -f /etc/cron.d/redclub-update
  if [ -f /etc/systemd/system/redclub-update.path ]; then
    systemctl disable --now redclub-update.path redclub-update.timer >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/redclub-update.path /etc/systemd/system/redclub-update.service /etc/systemd/system/redclub-update.timer /usr/local/bin/redclub-update
    systemctl daemon-reload || true
  fi
  # Unraid: Dienst + Zeitplan auf dem USB-Stick
  if [ -d /boot/config/plugins/redclub ]; then
    rm -rf /boot/config/plugins/redclub /boot/config/plugins/dynamix/redclub-update.cron /usr/local/bin/redclub-update
    [ -x /usr/local/sbin/update_cron ] && /usr/local/sbin/update_cron >/dev/null 2>&1
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

# 5b. Update-Dienst: der Knopf „Jetzt aktualisieren“ im Panel legt eine Anfrage-Datei in /data ab, ein
#     systemd-Pfad-Dienst auf dem Server zieht dann das neue Image und startet die App neu. So braucht
#     RedClub selbst keinen Zugriff auf Docker.
updater_einrichten() {
  DIENST_GRUND=""
  local app daten
  app=$(docker compose ps -q app 2>/dev/null || true)
  [ -n "$app" ] || { DIENST_GRUND="$(s "Der App-Container laeuft nicht (docker compose ps app ist leer)." "The app container is not running (docker compose ps app is empty).")"; return 1; }
  daten=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' "$app" 2>/dev/null || true)
  # Docker als Snap: docker inspect nennt /var/lib/docker/…, auf dem Server liegt es unter /var/snap/docker/common/var-lib-docker/…
  if [ -n "$daten" ] && [ ! -d "$daten" ] && [ -d "/var/snap/docker/common/var-lib-docker${daten#/var/lib/docker}" ]; then daten="/var/snap/docker/common/var-lib-docker${daten#/var/lib/docker}"; fi
  [ -n "$daten" ] && [ -d "$daten" ] || { DIENST_GRUND="$(s "Der Datenordner der App ($daten) ist vom Server aus nicht lesbar (Docker rootless oder in einer VM?)." "The app data folder ($daten) is not readable from the server (rootless Docker or inside a VM?).")"; return 1; }
# >>> DIENST (aus deploy/dienst.sh, eingebettet von deploy/einbetten.py — hier nicht von Hand aendern)
  { printf '#!/usr/bin/env bash\n# RedClub — Update-Dienst (angelegt von install.sh; systemd: redclub-update.path)\n'
    printf 'DIR=%q\nDATEN=%q\nQUELLE=%q\n' "$PWD" "$daten" "$QUELLE"
    cat <<'SKRIPT'
# RedClub — Update-Dienst (Stand 3). install.sh schreibt diese Datei nach /usr/local/bin/redclub-update und setzt
# davor DIR (Installationsordner), DATEN (Daten-Volume der App auf dem Server) und QUELLE (Download-Adresse).
#
# Die App legt Auftraege als JSON in $DATEN/.anfragen/ ab (alte Apps: eine Datei $DATEN/.update-anfrage).
# Jeder Auftrag hat eine id; das Ergebnis steht danach in $DATEN/.status/<id>.json (dazu fuer alte Apps die
# bisherigen Sammeldateien .update-status, .tunnel-status, .website-status).
# Es gibt nur die festen Aktionen unten — der Dienst fuehrt nie Befehle aus der Anfrage aus.
set -uo pipefail
umask 022
# cron (z. B. Unraid) startet mit sehr kurzem PATH
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
mkdir -p "$DATEN/.anfragen" "$DATEN/.status"
# die App (uid 1000) muss Auftraege ablegen und Status lesen koennen
chown 1000:1000 "$DATEN/.anfragen" "$DATEN/.status" 2>/dev/null || true
# Nichts zu tun (cron/Zeitgeber schauen jede Minute nach): sofort fertig, ohne auf die Sperre zu warten
[ -n "$(ls -A "$DATEN/.anfragen" 2>/dev/null)" ] || [ -f "$DATEN/.update-anfrage" ] || exit 0
# Immer nur ein Lauf (systemd-Ausloeser + Zeitgeber/cron koennen sich ueberschneiden): der zweite wartet
if command -v flock >/dev/null 2>&1; then exec 9>/run/redclub-update.lock 2>/dev/null || exec 9>/tmp/redclub-update.lock; flock -w 3600 9 || exit 0; fi
# Uebrig gebliebene Teil-Dateien (App beim Schreiben abgestuerzt) halten den Ordner sonst ewig „nicht leer“ —
# systemd startet den Dienst dann im Kreis, bis er die Ueberwachung abschaltet und kein Auftrag mehr ankommt
find "$DATEN/.anfragen" -mindepth 1 -maxdepth 1 ! -name '*.json' -mmin +2 -delete 2>/dev/null
# Hat systemd die Ueberwachung schon abgeschaltet (zu viele Starts), wieder einschalten
if command -v systemctl >/dev/null 2>&1 && systemctl is-failed -q redclub-update.path 2>/dev/null; then systemctl reset-failed redclub-update.path redclub-update.service 2>/dev/null; systemctl start redclub-update.path 2>/dev/null; fi
# Docker-Befehle duerfen nicht ewig haengen (Image-Download ohne Netz o. Ae.): nach 20 Minuten abbrechen.
# Laeuft ein Auftrag (LOG gesetzt), geht die Ausgabe zusaetzlich live ins Protokoll .status/<id>.log — das Panel zeigt es an.
LOG=""
_docker() { if command -v timeout >/dev/null 2>&1; then timeout 1200 docker "$@"; else command docker "$@"; fi; }
docker() { if [ -n "$LOG" ]; then _docker "$@" 2>&1 | tee -a "$LOG"; return "${PIPESTATUS[0]}"; fi; _docker "$@"; }
notiz() { [ -n "$LOG" ] && printf '==> %s\n' "$1" >> "$LOG"; return 0; }

feld() { sed -n "s#.*\"$1\":\"\\([$2]*\\)\".*#\\1#p" "$3" | head -1; }
schreib() { # schreib <id> <alte Sammeldatei> <status> <meldung>
  local z m; z=$(date -Is); m=$(printf '%s' "$4" | tr '\n"\\' '   ' | cut -c1-600)
  case "$3" in fertig) notiz "Fertig${m:+ ($m)}" ;; fehler) notiz "Fehler: $m" ;; esac
  [ -n "$1" ] && { printf '{"id":"%s","status":"%s","zeit":"%s","meldung":"%s"}\n' "$1" "$3" "$z" "$m" > "$DATEN/.status/$1.json"; chmod 644 "$DATEN/.status/$1.json"; }
  [ -n "$2" ] && { printf '{"status":"%s","zeit":"%s","meldung":"%s"}\n' "$3" "$z" "$m" > "$DATEN/$2"; chmod 644 "$DATEN/$2"; }
  return 0
}
kurz() { printf '%s' "$1" | tail -3 | tr '\n' ' '; }
env_setzen() { sed -i "/^$1=/d" .env; echo "$1=$2" >> .env; chmod 600 .env; }
env_lesen() { sed -n "s/^$1=//p" .env | tail -1; }
profil() { # profil an|aus name — Profil in COMPOSE_PROFILES
  local n="$2" p; p=$(env_lesen COMPOSE_PROFILES | tr ',' ' ')
  p=$(echo " $p " | sed "s/ $n / /g" | xargs)
  [ "$1" = "an" ] && p=$(echo "$p $n" | xargs)
  sed -i '/^COMPOSE_PROFILES=/d' .env
  [ -z "$p" ] || echo "COMPOSE_PROFILES=$(echo "$p" | tr ' ' ',')" >> .env
}
datei_an() { # datei_an an|aus compose.x.yml — Zusatzdatei in COMPOSE_FILE
  local f; f=$(env_lesen COMPOSE_FILE); [ -n "$f" ] || f="docker-compose.yml"
  f=$(echo ":$f:" | sed "s/:$2:/:/g; s/^://; s/:$//")
  [ "$1" = "an" ] && f="$f:$2"
  env_setzen COMPOSE_FILE "$f"
}
holen() { [ -f "$1" ] || curl -fsSL --max-time 30 -o "$1" "$QUELLE/$1?t=$(date +%s)"; }
geheim() { head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

# Webserver auf dem Host (nur Port-Modus): nginx oder Apache
ws_finden() {
  WS=""; if command -v nginx >/dev/null 2>&1; then WS=nginx; elif command -v apache2ctl >/dev/null 2>&1; then WS=apache2; elif command -v httpd >/dev/null 2>&1; then WS=httpd; fi
}
neuladen() { case "$WS" in nginx) nginx -t >/dev/null 2>&1 && { systemctl reload nginx 2>/dev/null || nginx -s reload; } ;; apache2) apache2ctl configtest >/dev/null 2>&1 && systemctl reload apache2 ;; *) httpd -t >/dev/null 2>&1 && systemctl reload httpd ;; esac; }
ws_datei() { # ws_datei <name> → DATEI/LINK
  LINK=""
  case "$WS" in
    nginx) if [ -d /etc/nginx/sites-enabled ]; then DATEI=/etc/nginx/sites-available/$1.conf; LINK=/etc/nginx/sites-enabled/$1.conf; else DATEI=/etc/nginx/conf.d/$1.conf; fi ;;
    apache2) DATEI=/etc/apache2/sites-available/$1.conf ;;
    *) DATEI=/etc/httpd/conf.d/$1.conf ;;
  esac
}

# domain_an <id> <altdatei> <domain> "<aliase>" <zert: auto|eigen>
domain_an() {
  local id="$1" alt="$2" dom="$3" alias="$4" zert="$5" port bind name fremd re namen n
  port=$(env_lesen RC_PORT); bind=$(env_lesen RC_BIND); [ -n "$bind" ] && [ "$bind" != "0.0.0.0" ] || bind=127.0.0.1
  [ -n "$dom" ] && [ -n "$port" ] || { schreib "$id" "$alt" fehler "Domain oder Port fehlt (laeuft RedClub im Port-Modus?)"; return 1; }
  ws_finden; [ -n "$WS" ] || { schreib "$id" "$alt" fehler "Kein nginx oder Apache auf dem Server gefunden"; return 1; }
  name="redclub-$dom"; ws_datei "$name"
  namen="$dom $alias"
  for n in $namen; do
    re=$(printf '%s' "$n" | sed 's/[.]/[.]/g')
    fremd=$(grep -RlsE "(^|[[:space:];{])(server_name|ServerName|ServerAlias)[[:space:]]+([^;#]*[[:space:]])?${re}([[:space:];]|$)" /etc/nginx/sites-enabled /etc/nginx/conf.d /etc/apache2/sites-enabled /etc/httpd/conf.d 2>/dev/null | grep -v 'redclub-' | head -1)
    [ -z "$fremd" ] || { schreib "$id" "$alt" fehler "Fuer $n gibt es schon einen Eintrag ($fremd), den fasse ich nicht an"; return 1; }
  done
  # alte Datei fuer dieselbe Domain (aeltere Fassung: redclub-website.conf) aufraeumen
  for f in /etc/nginx/sites-available/redclub-website.conf /etc/nginx/conf.d/redclub-website.conf /etc/apache2/sites-available/redclub-website.conf /etc/httpd/conf.d/redclub-website.conf; do
    [ -f "$f" ] && grep -qE "(server_name|ServerName)[[:space:]]+$(printf '%s' "$dom" | sed 's/[.]/[.]/g')" "$f" && { cp -a "$f" "/root/$(basename "$f").bak-$(date +%Y%m%d-%H%M%S)"; [ "$WS" = apache2 ] && a2dissite -q redclub-website.conf >/dev/null 2>&1; rm -f "$f" /etc/nginx/sites-enabled/redclub-website.conf; }
  done
  [ -f "$DATEI" ] && cp -a "$DATEI" "/root/$name.conf.bak-$(date +%Y%m%d-%H%M%S)"
  local zp="" kp=""
  if [ "$zert" = "eigen" ]; then
    zp="/etc/ssl/redclub/$dom/cert.pem"; kp="/etc/ssl/redclub/$dom/key.pem"
    [ -s "$DATEN/zertifikate/$dom/cert.pem" ] && [ -s "$DATEN/zertifikate/$dom/key.pem" ] || { schreib "$id" "$alt" fehler "Das hochgeladene Zertifikat fehlt im Datenordner"; return 1; }
    mkdir -p "/etc/ssl/redclub/$dom"; install -m 644 "$DATEN/zertifikate/$dom/cert.pem" "$zp"; install -m 600 "$DATEN/zertifikate/$dom/key.pem" "$kp"
  fi
  if [ "$WS" = "nginx" ]; then
    {
      echo "# RedClub: $dom (angelegt vom Update-Dienst)"
      echo "server {"; echo "    listen 80;"; echo "    listen [::]:80;"; echo "    server_name $namen;"
      if [ -n "$zp" ]; then echo '    return 301 https://$host$request_uri;'; echo "}"; echo "server {"; echo "    listen 443 ssl;"; echo "    listen [::]:443 ssl;"; echo "    server_name $namen;"
        echo "    ssl_certificate $zp;"; echo "    ssl_certificate_key $kp;"; echo '    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;'; fi
      echo "    client_max_body_size 200m;"; echo "    location / {"; echo "        proxy_pass http://$bind:$port;"; echo "        proxy_http_version 1.1;"
      echo '        proxy_set_header Host $host;'; echo '        proxy_set_header X-Real-IP $remote_addr;'; echo '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;'
      echo '        proxy_set_header X-Forwarded-Proto $scheme;'; echo '        proxy_set_header Upgrade $http_upgrade;'; echo '        proxy_set_header Connection "upgrade";'; echo "    }"; echo "}"
    } > "$DATEI"
    [ -n "$LINK" ] && ln -sf "$DATEI" "$LINK"
  else
    {
      echo "# RedClub: $dom (angelegt vom Update-Dienst)"
      echo "<VirtualHost *:80>"; echo "    ServerName $dom"; [ -n "$alias" ] && echo "    ServerAlias $alias"
      if [ -n "$zp" ]; then echo '    RewriteEngine On'; echo '    RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]'; echo "</VirtualHost>"; echo "<VirtualHost *:443>"; echo "    ServerName $dom"; [ -n "$alias" ] && echo "    ServerAlias $alias"
        echo "    SSLEngine on"; echo "    SSLCertificateFile $zp"; echo "    SSLCertificateKeyFile $kp"; echo '    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"'; fi
      echo "    ProxyPreserveHost On"; echo "    ProxyPass / http://$bind:$port/"; echo "    ProxyPassReverse / http://$bind:$port/"
      echo '    RequestHeader set X-Forwarded-Proto "expr=%{REQUEST_SCHEME}"'; echo "</VirtualHost>"
    } > "$DATEI"
    [ "$WS" = "apache2" ] && { a2enmod -q proxy proxy_http headers rewrite ssl >/dev/null 2>&1; a2ensite -q "$name.conf" >/dev/null 2>&1; }
  fi
  neuladen || { rm -f "$DATEI" $LINK; neuladen; schreib "$id" "$alt" fehler "Konfigtest des Webservers schlaegt fehl, Eintrag wieder entfernt"; return 1; }
  [ -n "$zp" ] && { schreib "$id" "$alt" fertig "https"; return 0; }
  local plugin=nginx args="" out
  [ "$WS" = "nginx" ] || plugin=apache
  if ! command -v certbot >/dev/null 2>&1; then { apt-get install -y -qq certbot "python3-certbot-$plugin" || dnf install -y -q certbot "python3-certbot-$plugin"; } >/dev/null 2>&1; fi
  for n in $namen; do args="$args -d $n"; done
  # erst mit allen Namen; zeigt ein Zusatzname (z. B. www) noch nicht hierher, dann nur die Hauptdomain
  if out=$(certbot "--$plugin" $args --cert-name "$dom" --redirect --hsts -n --agree-tos --register-unsafely-without-email 2>&1); then schreib "$id" "$alt" fertig "https"
  elif [ -n "$alias" ] && out=$(certbot "--$plugin" -d "$dom" --cert-name "$dom" --redirect --hsts -n --agree-tos --register-unsafely-without-email 2>&1); then schreib "$id" "$alt" fertig "https-ohne-alias"
  else schreib "$id" "$alt" fehler "Virtual Host steht, aber das Zertifikat fehlt (zeigt der DNS-Eintrag auf diesen Server?): $(kurz "$out")"; fi
}
domain_aus() {
  local id="$1" alt="$2" dom="$3"
  ws_finden; [ -n "$WS" ] || { schreib "$id" "$alt" fertig "entfernt"; return 0; }
  ws_datei "redclub-$dom"
  [ -f "$DATEI" ] && cp -a "$DATEI" "/root/redclub-$dom.conf.bak-$(date +%Y%m%d-%H%M%S)"
  [ "$WS" = "apache2" ] && a2dissite -q "redclub-$dom.conf" >/dev/null 2>&1
  rm -f "$DATEI" $LINK
  for f in /etc/nginx/sites-available/redclub-website.conf /etc/nginx/conf.d/redclub-website.conf /etc/apache2/sites-available/redclub-website.conf /etc/httpd/conf.d/redclub-website.conf; do
    [ -f "$f" ] && grep -qE "(server_name|ServerName)[[:space:]]+$(printf '%s' "$dom" | sed 's/[.]/[.]/g')" "$f" && { [ "$WS" = apache2 ] && a2dissite -q redclub-website.conf >/dev/null 2>&1; rm -f "$f" /etc/nginx/sites-enabled/redclub-website.conf; }
  done
  rm -rf "/etc/ssl/redclub/$dom"
  command -v certbot >/dev/null 2>&1 && certbot delete --cert-name "$dom" -n >/dev/null 2>&1
  if neuladen; then schreib "$id" "$alt" fertig "entfernt"; else schreib "$id" "$alt" fehler "Konfigtest des Webservers schlaegt fehl"; fi
}

bearbeiten() { # bearbeiten <anfrage-datei>
  local f="$1" id aktion tok dom alias php zert schalter port adr out
  id=$(feld id 'a-z0-9-' "$f"); aktion=$(feld aktion 'a-z-' "$f"); tok=$(feld token 'A-Za-z0-9+/=_-' "$f")
  dom=$(feld domain 'a-z0-9.-' "$f"); alias=$(feld aliase 'a-z0-9. -' "$f"); php=$(feld php '0-9.' "$f"); zert=$(feld zert 'a-z' "$f"); schalter=$(feld schalter 'a-z' "$f"); port=$(feld port '0-9' "$f")
  adr=$(feld adresse 'a-z0-9._+@-' "$f")
  # Ohne Aktion gilt „update“ nur fuer die Datei alter Apps — sonst ist der Auftrag kaputt
  if [ -z "$aktion" ] && [ "$(basename "$f")" != "0-alt.json" ]; then rm -f "$f"; schreib "$id" "" fehler "Auftrag ohne gueltige Aktion"; return 1; fi
  rm -f "$f"
  # Live-Protokoll dieses Auftrags (die App liest es mit, solange er laeuft)
  LOG=""; if [ -n "$id" ]; then LOG="$DATEN/.status/$id.log"; : > "$LOG"; chmod 644 "$LOG"; notiz "$(date '+%H:%M:%S') Auftrag ${aktion:-update} gestartet"; fi
  cd "$DIR" || { schreib "$id" .update-status fehler "Ordner $DIR fehlt"; return 1; }
  case "${aktion:-update}" in
    tunnel-an)
      schreib "$id" .tunnel-status laeuft ""
      [ -n "$tok" ] || { schreib "$id" .tunnel-status fehler "Kein Tunnel-Token in der Anfrage"; return 1; }
      env_setzen RC_TUNNEL_TOKEN "$tok"; profil an tunnel
      if out=$(docker compose up -d cloudflared 2>&1); then schreib "$id" .tunnel-status fertig ""; else schreib "$id" .tunnel-status fehler "$(kurz "$out")"; fi ;;
    tunnel-aus)
      schreib "$id" .tunnel-status laeuft ""
      if out=$(docker compose stop cloudflared 2>&1 && docker compose rm -f cloudflared 2>&1); then profil aus tunnel; sed -i '/^RC_TUNNEL_TOKEN=/d' .env; schreib "$id" .tunnel-status fertig ""
      else schreib "$id" .tunnel-status fehler "$(kurz "$out")"; fi ;;
    website-an|domain-an) schreib "$id" .website-status laeuft ""; domain_an "$id" .website-status "$dom" "$alias" "${zert:-auto}" ;;
    website-aus|domain-aus) schreib "$id" .website-status laeuft ""; domain_aus "$id" .website-status "$dom" ;;
    hosting-an)
      schreib "$id" "" laeuft ""
      holen compose.hosting.yml || { schreib "$id" "" fehler "compose.hosting.yml liess sich nicht laden"; return 1; }
      [ -n "$(env_lesen PHPDB_ROOT_PASSWORD)" ] || env_setzen PHPDB_ROOT_PASSWORD "$(geheim)"
      [ -n "$(env_lesen RC_PHP_VERSION)" ] || env_setzen RC_PHP_VERSION "${php:-8.3}"
      datei_an an compose.hosting.yml
      notiz "Images fuer PHP und MariaDB laden (beim ersten Mal ein paar Minuten)"
      if out=$(docker compose pull --ignore-pull-failures web phpdb 2>&1 && notiz "Container starten, MariaDB richtet sich ein" && docker compose up -d web phpdb app 2>&1); then schreib "$id" "" fertig ""; else schreib "$id" "" fehler "$(kurz "$out")"; fi ;;
    hosting-aus)
      schreib "$id" "" laeuft ""
      docker compose stop web web82 web83 web84 web85 phpdb >/dev/null 2>&1; docker compose rm -f web web82 web83 web84 web85 phpdb >/dev/null 2>&1
      for p in php82 php83 php84 php85; do profil aus "$p"; done
      datei_an aus compose.hosting.yml; datei_an aus compose.sftp.yml; datei_an aus compose.phpdb.yml
      # Daten (Volumes www, phpdb) bleiben erhalten
      if out=$(docker compose up -d app 2>&1); then schreib "$id" "" fertig ""; else schreib "$id" "" fehler "$(kurz "$out")"; fi ;;
    php-version)
      schreib "$id" "" laeuft ""
      case "$php" in 8.2|8.3|8.4|8.5) ;; *) schreib "$id" "" fehler "Unbekannte PHP-Version $php"; return 1 ;; esac
      env_setzen RC_PHP_VERSION "$php"
      # die App muss die neue Standard-Version kennen (Weiterleitung der Seiten) — also beide neu starten
      if out=$(docker compose pull --ignore-pull-failures web 2>&1 && docker compose up -d web app 2>&1); then schreib "$id" "" fertig "$php"; else schreib "$id" "" fehler "$(kurz "$out")"; fi ;;
    php-zusatz)
      # weitere PHP-Version je Seite (2.0): Container web82 … web85 ueber das Profil php82 … php85 ein- oder ausschalten
      schreib "$id" "" laeuft ""
      case "$php" in 8.2|8.3|8.4|8.5) ;; *) schreib "$id" "" fehler "Unbekannte PHP-Version $php"; return 1 ;; esac
      local nr="${php/./}"
      if [ "$schalter" = an ]; then
        profil an "php$nr"
        if out=$(docker compose pull --ignore-pull-failures "web$nr" 2>&1 && docker compose up -d "web$nr" 2>&1); then schreib "$id" "" fertig "PHP $php laeuft"; else schreib "$id" "" fehler "$(kurz "$out")"; fi
      elif [ "$schalter" = aus ]; then
        docker compose stop "web$nr" >/dev/null 2>&1; docker compose rm -f "web$nr" >/dev/null 2>&1
        profil aus "php$nr"; schreib "$id" "" fertig "PHP $php gestoppt"
      else schreib "$id" "" fehler "schalter fehlt"; return 1; fi ;;
    sftp-an|sftp-aus)
      schreib "$id" "" laeuft ""
      if [ "$aktion" = "sftp-an" ]; then holen compose.sftp.yml || { schreib "$id" "" fehler "compose.sftp.yml liess sich nicht laden"; return 1; }; datei_an an compose.sftp.yml; else datei_an aus compose.sftp.yml; fi
      if out=$(docker compose up -d app 2>&1); then schreib "$id" "" fertig ""; else schreib "$id" "" fehler "$(kurz "$out")"; fi ;;
    phpdb-fern)
      # Fernzugriff auf die Hosting-MariaDB: Port veroeffentlichen (compose.phpdb.yml) oder wieder schliessen
      schreib "$id" "" laeuft ""
      if [ "$schalter" = an ]; then
        # (alle Felder liest der Kopf oben — die Auftragsdatei ist hier schon geloescht)
        [ -n "$port" ] && [ "$port" -ge 1024 ] && [ "$port" -le 65535 ] || port=3306
        holen compose.phpdb.yml || { schreib "$id" "" fehler "compose.phpdb.yml liess sich nicht laden"; return 1; }
        env_setzen RC_PHPDB_FERN_PORT "$port"; datei_an an compose.phpdb.yml
      elif [ "$schalter" = aus ]; then datei_an aus compose.phpdb.yml
      else schreib "$id" "" fehler "schalter fehlt"; return 1; fi
      # --wait: erst „fertig“ melden, wenn MariaDB wieder antwortet (aeltere Compose-Fassungen kennen es nicht)
      phpdb_hoch() { local o; if o=$(docker compose up -d --wait --wait-timeout 120 phpdb 2>&1); then return 0; fi
        if printf '%s' "$o" | grep -qi 'unknown flag'; then o=$(docker compose up -d phpdb 2>&1) && return 0; fi
        printf '%s' "$o"; return 1; }
      if out=$(phpdb_hoch); then schreib "$id" "" fertig "$schalter"
      else
        # z. B. Port schon belegt: MariaDB darf dadurch nicht ausfallen — Freigabe zuruecknehmen und ohne Port neu starten
        datei_an aus compose.phpdb.yml; phpdb_hoch >/dev/null 2>&1
        if printf '%s' "$out" | grep -qi 'address already in use\|port is already allocated'; then out="Port $port ist auf dem Server schon belegt — bitte einen anderen waehlen"; fi
        schreib "$id" "" fehler "$(kurz "$out")"
      fi ;;
    mail-an)
      # Eigener Mailserver (compose.mail.yml); Zertifikat von Caddy bzw. certbot, sonst selbst erzeugt (mailkonfig/ssl)
      schreib "$id" "" laeuft ""
      [ -n "$dom" ] || { schreib "$id" "" fehler "Name des Mailservers fehlt"; return 1; }
      for d in compose.mail.yml compose.mail-caddy.yml compose.mail-le.yml; do holen "$d" || { schreib "$id" "" fehler "$d liess sich nicht laden"; return 1; }; datei_an aus "$d"; done
      env_setzen RC_MAIL_HOST "$dom"; env_setzen RC_MAIL_POSTMASTER "postmaster@${dom#*.}"
      if [ "$schalter" = an ]; then env_setzen RC_MAIL_CLAMAV 1; else env_setzen RC_MAIL_CLAMAV 0; fi
      datei_an an compose.mail.yml
      case "$zert" in
        caddy) if docker compose exec -T caddy test -f "/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$dom/$dom.crt" 2>/dev/null; then datei_an an compose.mail-caddy.yml; else zert=datei; fi ;;
        le) if [ -f "/etc/letsencrypt/live/$dom/fullchain.pem" ]; then datei_an an compose.mail-le.yml; else zert=datei; fi ;;
        *) zert=datei ;;
      esac
      # Konfig-Ordner gehoert der App (Nutzer 1000): sie schreibt Konten, Aliase und DKIM, der Mailserver liest nur.
      # Ohne das legt docker-mailserver das Volume als root an und startet mangels Konten nicht.
      if out=$(docker compose pull --ignore-pull-failures mail 2>&1 && docker compose run --rm --no-deps -u root --entrypoint chown app 1000:1000 /mailkonfig /maildaten 2>&1 && docker compose up -d mail app 2>&1); then schreib "$id" "" fertig "$zert"; else schreib "$id" "" fehler "$(kurz "$out")"; fi ;;
    mail-aus)
      schreib "$id" "" laeuft ""
      docker compose stop mail >/dev/null 2>&1; docker compose rm -f mail >/dev/null 2>&1
      for d in compose.mail.yml compose.mail-caddy.yml compose.mail-le.yml; do datei_an aus "$d"; done
      if out=$(docker compose up -d app 2>&1); then schreib "$id" "" fertig ""; else schreib "$id" "" fehler "$(kurz "$out")"; fi ;;
    mail-ordner-weg)
      # gespeicherte Mails eines geloeschten Postfachs — Adresse streng pruefen (kein „..“, kein „/“)
      local lok="${adr%@*}" mdom="${adr#*@}"
      if [[ "$lok" =~ ^[a-z0-9][a-z0-9._+-]*$ ]] && [[ "$mdom" =~ ^[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$ ]] && [[ "$lok" != *..* ]] && [[ "$mdom" != *..* ]]; then
        if out=$(docker compose exec -T mail rm -rf -- "/var/mail/$mdom/$lok" 2>&1); then schreib "$id" "" fertig ""; else schreib "$id" "" fehler "$(kurz "$out")"; fi
      else schreib "$id" "" fehler "ungueltige Adresse"; fi ;;
    caddy-neu)
      schreib "$id" "" laeuft ""
      if out=$(docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile 2>&1); then schreib "$id" "" fertig ""; else schreib "$id" "" fehler "$(kurz "$out")"; fi ;;
    *)
      schreib "$id" .update-status laeuft ""
      # Erst das neueste update.sh holen: es bringt Dateien, Images und diesen Dienst selbst auf den neuesten Stand
      local neu; neu=$(mktemp)
      if curl -fsSL --max-time 30 -o "$neu" "$QUELLE/update.sh?t=$(date +%s)" 2>/dev/null && bash -n "$neu" 2>/dev/null; then
        [ -n "$id" ] && export RC_STATUS_ID="$id"
        RC_QUELLE="$QUELLE" exec bash "$neu" --dir "$DIR" --status "$DATEN/.update-status"
      fi
      rm -f "$neu"
      # GitHub nicht erreichbar: nur die Images
      local dienste="app"; grep -q '^COMPOSE_PROFILES=.*tunnel' .env && dienste="$dienste cloudflared"; grep -q 'compose.hosting.yml' .env && dienste="$dienste web phpdb"
      if out=$(docker compose pull $dienste 2>&1 && docker compose up -d $dienste 2>&1); then schreib "$id" .update-status fertig ""
      else schreib "$id" .update-status fehler "$(kurz "$out")"; fi ;;
  esac
}

# Alte Apps legen genau eine Datei ab, neue einen Ordner voller Auftraege — beides der Reihe nach abarbeiten
[ -f "$DATEN/.update-anfrage" ] && mv -f "$DATEN/.update-anfrage" "$DATEN/.anfragen/0-alt.json"
for f in $(ls -1 "$DATEN/.anfragen/"*.json 2>/dev/null | sort); do [ -f "$f" ] && bearbeiten "$f"; done
# Liegt nur noch eine frische Teil-Datei da (App schreibt gerade), nicht sofort im Kreis neu starten
[ -n "$(ls -A "$DATEN/.anfragen" 2>/dev/null)" ] && sleep 5
# Status-Dateien aelter als 7 Tage weg
find "$DATEN/.status" -name '*.json' -mtime +7 -delete 2>/dev/null
exit 0
SKRIPT
  } > /usr/local/bin/redclub-update.neu
# <<< DIENST
  # erst fertig schreiben, dann umbenennen: ein gerade laufender Dienst liest so seine alte Fassung zu Ende
  chmod 755 /usr/local/bin/redclub-update.neu && mv -f /usr/local/bin/redclub-update.neu /usr/local/bin/redclub-update
  local ausloeser=""
  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    mkdir -p "$daten/.anfragen" "$daten/.status"; chown 1000:1000 "$daten/.anfragen" "$daten/.status" 2>/dev/null || true
    printf '%s\n' "[Unit]" "Description=RedClub: Auftrag aus dem Panel" "[Path]" "PathExists=$daten/.update-anfrage" "DirectoryNotEmpty=$daten/.anfragen" "[Install]" "WantedBy=multi-user.target" > /etc/systemd/system/redclub-update.path
    # StartLimitIntervalSec=0: viele Auftraege kurz hintereinander duerfen die Ueberwachung nie abschalten
    printf '%s\n' "[Unit]" "Description=RedClub aktualisieren" "StartLimitIntervalSec=0" "ConditionDirectoryNotEmpty=|$daten/.anfragen" "ConditionPathExists=|$daten/.update-anfrage" "[Service]" "Type=oneshot" "ExecStart=/usr/local/bin/redclub-update" > /etc/systemd/system/redclub-update.service
    # Rueckfallebene: jede Minute nachsehen, falls die Pfad-Ueberwachung doch einmal ausfaellt
    printf '%s\n' "[Unit]" "Description=RedClub: Auftraege nachsehen" "[Timer]" "OnBootSec=1min" "OnUnitInactiveSec=1min" "AccuracySec=10s" "[Install]" "WantedBy=timers.target" > /etc/systemd/system/redclub-update.timer
    if systemctl daemon-reload && systemctl enable --now redclub-update.path >/dev/null 2>&1; then ausloeser="systemd"; rm -f /etc/cron.d/redclub-update; systemctl reset-failed redclub-update.path redclub-update.service >/dev/null 2>&1; systemctl restart redclub-update.path >/dev/null 2>&1; systemctl enable --now redclub-update.timer >/dev/null 2>&1; fi
  fi
  # Unraid: kein systemd, /etc und /usr/local liegen im Arbeitsspeicher (nach dem Neustart weg), und cron liest
  # /etc/cron.d als Crontabs je Benutzer (Datei „root“, ohne Benutzerfeld) — eine eigene Datei dort laeuft nie.
  # update_cron baut die root-Crontab aus /boot/config/plugins/dynamix/*.cron (+ Ordner installierter Plugins mit .plg)
  # — bei jedem Start und jeder Zeitplan-Aenderung. Darum: Dienst auf den USB-Stick, Zeitplan nach dynamix/.
  if [ -z "$ausloeser" ] && [ -f /etc/unraid-version ] && [ -d /boot/config ]; then
    mkdir -p /boot/config/plugins/redclub /boot/config/plugins/dynamix
    cp -f /usr/local/bin/redclub-update /boot/config/plugins/redclub/redclub-update
    local zeile="* * * * * bash /boot/config/plugins/redclub/redclub-update >/dev/null 2>&1"
    printf '%s\n' "# RedClub: Auftraege aus dem Panel (angelegt von install.sh)" "$zeile" "" > /boot/config/plugins/dynamix/redclub-update.cron
    rm -f /etc/cron.d/redclub-update /boot/config/plugins/redclub/redclub.cron
    # steht der Eintrag in der Crontab, die Unraid-cron liest? (ohne Pipe: install.sh laeuft mit pipefail)
    rc_cron_drin() { local alle; alle="$(cat /etc/cron.d/root 2>/dev/null || true)"; case "$alle" in *plugins/redclub/redclub-update*) return 0 ;; esac; return 1; }
    # 1. Unraid-Weg
    if [ -x /usr/local/sbin/update_cron ]; then /usr/local/sbin/update_cron >/dev/null 2>&1 || true; fi
    # 2. update_cron fehlt oder liest dynamix/ nicht: direkt in die root-Crontab und cron neu laden lassen
    if ! rc_cron_drin && [ -d /etc/cron.d ]; then
      { cat /etc/cron.d/root 2>/dev/null || true; echo "$zeile"; } > /tmp/redclub-cron.$$ && cat /tmp/redclub-cron.$$ > /etc/cron.d/root
      rm -f /tmp/redclub-cron.$$; crontab /etc/cron.d/root -c /etc/cron.d >/dev/null 2>&1 || true
    fi
    if rc_cron_drin; then ausloeser="cron (Unraid)"
    else
      DIENST_GRUND="$(s "Unraid: der Zeitplan liess sich nicht eintragen" "Unraid: the schedule could not be added") (Unraid $(cat /etc/unraid-version 2>/dev/null | tr -dc '0-9.' | head -c 12), update_cron: $([ -x /usr/local/sbin/update_cron ] && echo ja || echo nein), /etc/cron.d: $(ls /etc/cron.d 2>/dev/null | tr '\n' ' '), crond: $(pgrep -x crond >/dev/null 2>&1 && echo laeuft || echo aus))."
      return 1
    fi
  fi
  # Ohne systemd (z. B. Container-Server, Alpine): cron schaut jede Minute nach einer Anfrage
  if [ -z "$ausloeser" ] && [ -d /etc/cron.d ] && { pgrep -x cron >/dev/null 2>&1 || pgrep -x crond >/dev/null 2>&1; }; then
    printf '%s\n' "# RedClub: Auftrag aus dem Panel (angelegt von install.sh, ohne systemd)" "* * * * * root /usr/local/bin/redclub-update >/dev/null 2>&1" > /etc/cron.d/redclub-update
    chmod 644 /etc/cron.d/redclub-update; ausloeser="cron"
  fi
  [ -n "$ausloeser" ] || { DIENST_GRUND="$(s "Weder systemd noch cron laufen auf diesem Server – ohne einen davon kann der Knopf im Panel nichts ausloesen." "Neither systemd nor cron is running on this server – without one the panel button cannot trigger anything.")"; return 1; }
  printf '%s\naktionen=update tunnel website domain hosting php sftp caddy zert anfragen phpzusatz phpdbfern mail\nstand=4\n' "$PWD" > "$daten/.updater"; chmod 644 "$daten/.updater"
  say "==> Update-Dienst eingerichtet ($ausloeser; Panel → Version unten links → „Jetzt aktualisieren“)" "==> Update service set up ($ausloeser; panel → version at the bottom left → “Update now”)"
}


# Nur den Update-Dienst neu einrichten (update.sh ruft das nach jedem Update auf) — ohne Fragen, sonst bleibt alles
if [ -n "$NUR_DIENST" ]; then
  updater_einrichten || { say "FEHLER: Update-Dienst nicht eingerichtet: $DIENST_GRUND" "ERROR: update service not set up: $DIENST_GRUND"; exit 1; }
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
# 3a. .env fehlt, aber die Container dieser Installation gibt es noch (z. B. Unraid nach einem Neustart: Ordner im RAM weg,
#     Docker-Volumes noch da): Datenbank-Passwort von dort — ein neu gewuerfeltes passte nicht mehr zur Datenbank.
#     Eine NEU angelegte .env wird bei einem Abbruch (Strg+C) vor Schritt 4 wieder entfernt — sonst fehlte spaeter der Weg nach aussen.
ENV_NEU=0; WEG_FERTIG=0
if [ ! -f .env ]; then
  env_db=$(docker ps -aq --filter "label=com.docker.compose.project=$(basename "$PWD")" --filter label=com.docker.compose.service=db 2>/dev/null || true)
  env_db=${env_db%%$'\n'*}
  env_pw=""
  [ -n "$env_db" ] && env_pw=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$env_db" 2>/dev/null | sed -n 's/^POSTGRES_PASSWORD=//p' || true)
  if [ -n "$env_pw" ]; then
    printf 'DB_PASSWORD=%s\nTZ=Europe/Berlin\n' "$env_pw" > .env && chmod 600 .env
    say "==> .env fehlte — Datenbank-Passwort aus dem vorhandenen Datenbank-Container übernommen" "==> .env was missing — database password taken from the existing database container"
  else
    ENV_NEU=1
  fi
fi
trap 'if [ "${ENV_NEU:-0}" = 1 ] && [ "${WEG_FERTIG:-0}" != 1 ]; then rm -f "$PWD/.env"; fi' EXIT
if [ ! -f .env ]; then
  printf 'DB_PASSWORD=%s\nTZ=Europe/Berlin\n' "$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')" > .env
  chmod 600 .env
  say "==> .env mit zufaelligem Datenbank-Passwort angelegt" "==> Created .env with a random database password"
fi
# Sprache merken — gilt auch fuer den Einrichtungs-Assistenten
if grep -q '^RC_LANG=' .env; then sed -i "s/^RC_LANG=.*/RC_LANG=$SPR/" .env; else echo "RC_LANG=$SPR" >> .env; fi

# Weg nach aussen sichern: kennt die .env keinen (z. B. nach einer abgebrochenen Einrichtung), wuerde ein Neustart den
# freigegebenen Port bzw. Caddy verlieren — dann vom laufenden Container uebernehmen, sonst aus der letzten Sicherung.
weg_retten() {
  WEG_GERETTET=""
  if grep -q '^COMPOSE_FILE=' .env 2>/dev/null; then return 0; fi
  local proj c port ip alt
  proj=$(basename "$PWD")
  c=$(docker ps -q --filter "label=com.docker.compose.project=$proj" --filter label=com.docker.compose.service=caddy 2>/dev/null || true)
  if [ -n "$c" ]; then
    echo "COMPOSE_FILE=docker-compose.yml:compose.caddy.yml" >> .env; WEG_GERETTET="Caddy"; return 0
  fi
  c=$(docker ps -q --filter "label=com.docker.compose.project=$proj" --filter label=com.docker.compose.service=app 2>/dev/null || true)
  c=${c%%$'\n'*}
  port=""; ip=""
  if [ -n "$c" ]; then
    port=$(docker inspect -f '{{with index .HostConfig.PortBindings "3000/tcp"}}{{(index . 0).HostPort}}{{end}}' "$c" 2>/dev/null || true)
    ip=$(docker inspect -f '{{with index .HostConfig.PortBindings "3000/tcp"}}{{(index . 0).HostIp}}{{end}}' "$c" 2>/dev/null || true)
  fi
  if [ -n "$port" ]; then
    # leere HostIp heisst: auf allen Adressen (so war es bisher erreichbar)
    printf 'COMPOSE_FILE=docker-compose.yml:compose.port.yml\nRC_PORT=%s\nRC_BIND=%s\n' "$port" "${ip:-0.0.0.0}" >> .env
    WEG_GERETTET="Port ${ip:-0.0.0.0}:$port"; return 0
  fi
  for alt in $(ls -1d .sicherung/*/ 2>/dev/null | sort -r); do
    if grep -q '^COMPOSE_FILE=' "${alt}.env" 2>/dev/null; then
      grep -E '^(COMPOSE_FILE|RC_PORT|RC_BIND|RC_PROXY_DOMAIN)=' "${alt}.env" >> .env || true
      WEG_GERETTET="Sicherung ${alt%/}"; return 0
    fi
  done
  return 0
}
weg_retten
[ -n "$WEG_GERETTET" ] && say "==> Die .env kannte keinen Weg nach außen — vom laufenden RedClub übernommen ($WEG_GERETTET)" "==> .env had no way in — taken over from the running RedClub ($WEG_GERETTET)"

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

WEG_FERTIG=1
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

# Passt das Datenbank-Passwort der .env nicht mehr zur Datenbank (.env neu angelegt, das Daten-Volume ist aber das
# alte — etwa nach einem Unraid-Neustart oder einer zweiten Installation), kommt die App nie an ihre Daten (502).
# Im Datenbank-Container geht der lokale Socket ohne Passwort: darueber das Passwort der .env setzen, Daten bleiben.
# Geprueft wird ueber die Netz-Adresse des Containers (wie die App) — 127.0.0.1 ist dort ohne Passwort erlaubt.
# Rueckgabe: 0 = passt, 2 = angeglichen (App neu gestartet), 1 = liess sich nicht angleichen
db_passwort_angleichen() {
  local i
  [ -n "$(docker compose ps -q db 2>/dev/null)" ] || return 0
  for i in $(seq 1 30); do docker compose exec -T db pg_isready -q >/dev/null 2>&1 && break; sleep 1; done
  docker compose exec -T db sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$(hostname -i 2>/dev/null | cut -d" " -f1)" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select 1"' >/dev/null 2>&1 && return 0
  printf '%s\n' "ALTER USER CURRENT_USER PASSWORD :'pw';" | docker compose exec -T db sh -c 'psql -q -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -v pw="$POSTGRES_PASSWORD"' >/dev/null 2>&1 || return 1
  docker compose exec -T db sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$(hostname -i 2>/dev/null | cut -d" " -f1)" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select 1"' >/dev/null 2>&1 || return 1
  docker compose restart app >/dev/null 2>&1 || true
  return 2
}

# 5. Starten
if [ -d .output ]; then docker compose up -d --build; else docker compose pull && docker compose up -d; fi
db_rc=0; db_passwort_angleichen || db_rc=$?
if [ "$db_rc" = 2 ]; then say "    Das Datenbank-Passwort passte nicht zur .env — angeglichen (Daten bleiben)." "    The database password did not match .env — fixed (data kept)."
elif [ "$db_rc" = 1 ]; then say "    FEHLER: Das Datenbank-Passwort passt nicht zur .env und liess sich nicht angleichen." "    ERROR: The database password does not match .env and could not be fixed."; fi

# 5b. Update-Dienst einrichten (Funktion steht oben)
updater_einrichten || say "    Update-Dienst nicht eingerichtet: $DIENST_GRUND" "    Update service not set up: $DIENST_GRUND"

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
  fremd=$(grep -RlsE "(^|[[:space:];{])(server_name|ServerName|ServerAlias)[[:space:]]+([^;#]*[[:space:]])?${DOMAIN//./\\.}([[:space:];]|$)" /etc/nginx/sites-enabled /etc/nginx/conf.d /etc/apache2/sites-enabled /etc/httpd/conf.d 2>/dev/null | grep -v 'redclub' | head -1 || true)
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
