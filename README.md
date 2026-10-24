# RedClub

**Selbst gehostete Vereinsverwaltung** für Vereine in Deutschland, Österreich und der Schweiz. RedClub läuft als Docker-Paket auf eurem eigenen Server — die Daten eurer Mitglieder bleiben bei euch. Das HTTPS-Zertifikat holt RedClub selbst.

By [TheRedStonee](https://www.theredstonee.de/) · 5 Tage kostenlos testen, danach mit Lizenz

> **English:** Self-hosted club management for associations in Germany, Austria and Switzerland. Runs as a Docker package on your own server, so your members' data stays with you. Members, groups, events with sign-ups and helper shifts, newsletters, a members area (installable app with push notices), double-entry bookkeeping with DATEV export, invoices with Swiss QR-bill / GiroCode, SEPA direct debit, Stripe and bank-statement import, donation receipts, certificates, volunteer hours and coach payouts, RedDrop files and single sign-on for other apps, plus a website builder for the club homepage with membership form and contact form. Cloudflare Tunnel for servers without open ports. 5-day trial, then with a licence — without one everything stays readable and exportable. One `docker compose up`, automatic HTTPS via Let's Encrypt. German and English. Jump to [Quick start](#schnellstart).

---

## Was es kann

- **Mitglieder:** Stammdaten, Gruppen und Ämter, Familien, Ein- und Austritt, Import aus CSV und Excel (mit Vorlagen), Export.
- **Mitgliederbereich:** Mitglieder melden sich mit einem Code per E-Mail (oder Passwort) an, sehen ihre Daten, Termine, Rechnungen, Stunden und freigegebene Dateien — als App aufs Handy mit Push-Hinweisen.
- **Termine:** Anmeldungen, Helfer-Schichten, Kalender-Abo (iCal), Erinnerungen.
- **News und Rundmails** mit Vorlagen, Abmelde-Link und automatischen Mails (z. B. Geburtstage, Jubiläen).
- **Buchhaltung:** doppelte Buchführung mit Vereins-Kontenplan je Land, steuerliche Bereiche (Sphären), Belege, Jahresabschluss mit Vorträgen, Berichte und **DATEV-Export**.
- **Rechnungen und Beiträge:** Beitragsarten und Beitragslauf, Rechnungen als PDF mit **Swiss QR-Bill** (CH) bzw. **GiroCode** (DE/AT), Mahnungen, **SEPA-Lastschrift** (pain.008), Online-Zahlung per **Stripe**, Kontoauszug-Import (camt.053/054, MT940, CSV) mit Abgleich und Rücklastschriften.
- **Spenden:** Online-Spenden, **Zuwendungsbestätigungen** nach amtlichem Muster (DE), Jahresmeldung an **FinanzOnline** (AT).
- **Urkunden und Qualifikationen:** Urkunden als PDF mit eigenen Vorlagen und Prüf-Link, Lizenzen und Ausbildungen mit Ablaufdatum und Erinnerung.
- **Stunden:** Helfer- und Pflichtstunden (mit Ersatzabgabe), Trainer- und Übungsleiter-Abrechnung mit Jahresgrenzen, Projekte und Vorstandsarbeit.
- **Website-Baukasten:** die Vereins-Homepage aus über 25 Blöcken — Titelbild, Bildstrecke, Galerie mit Großansicht, Team mit Fotos, Zahlen, Sponsoren-Laufband, Video (lädt erst nach Klick), Downloads, Countdown, Termine, News, Berichte, Mitgliedsantrag, Spenden und mehr. Gestaltung je Abschnitt (Hintergrund, Foto, Breite, Kante), sechs Vorlagen mit eigenen Schriften, dunkle Variante, sanftes Scrollen und Animationen; freie Fotos zum Loslegen. Editor mit Ziehen & Ablegen, Rückgängig und Live-Vorschau. Eigene Seiten für News und Termine (mit Anmeldung für Gäste), Berichte/Blog, englische Fassung, Besucherzahlen ohne Cookies. Alles selbst ausgeliefert — keine Google Fonts, kein Tracking. Auf eurer eigenen Domain mit automatischem HTTPS oder unter `/web`; Impressum und Datenschutz automatisch oder selbst geschrieben.
- **Support mit dem TRS Ticket-Portal:** Support-Formular auf der Website mit den Themen und Feldern eures Portals, Kontaktformular auf Wunsch als Ticket, Tickets beantworten im Panel, Mitglieder sehen ihre Anfragen im Mitgliederbereich. Der geheime API-Schlüssel bleibt auf eurem Server.
- **Verbindungen:** Dateien und Fotos über [RedDrop](https://www.theredstonee.de/reddrop/) (Ordner im Mitgliederbereich, Upload-Links), **Anmeldung mit dem RedClub-Zugang** in anderen Apps (OpenID Connect), automatische Mitglieder-Lizenzen aus einer [TRS License](https://www.theredstonee.de/license/).
- **Konten für den Vorstand** mit Rollen (Inhaber, Admin, Mitarbeit), **Zwei-Faktor-Anmeldung** und **Passkeys**, Protokoll aller Änderungen.
- **Erreichbar, wie es passt:** eigene Domain mit automatischem HTTPS, hinter eurem nginx/Apache — oder per **Cloudflare Tunnel** ohne offene Ports.
- **Updates per Knopf** im Panel. **Hell und dunkel, Deutsch und Englisch.**

### Testphase und Lizenz

- Beim Einrichten startet eine **5-tägige Testphase** mit allen Funktionen. Dafür meldet sich RedClub einmal mit E-Mail-Adresse und Vereinsname bei `license.redst.de` — so lässt sich die Testphase nicht beliebig wiederholen.
- Danach läuft RedClub mit einem **Lizenzschlüssel** weiter (Panel → **Lizenz**). Die Installation prüft ihn alle 6 Stunden; ist der Lizenzserver einmal nicht erreichbar, läuft alles 7 Tage normal weiter.
- **Ohne Lizenz geht nichts verloren:** RedClub ist dann nur lesbar — ansehen und exportieren geht weiter.
- Ohne Internet: eine **Offline-Lizenzdatei** aus dem Kunden-Portal auf license.redst.de einspielen.

## Voraussetzungen

| | Minimum | Empfohlen |
|---|---|---|
| CPU | 1 vCPU | 2 vCPU |
| RAM | 1 GB | 2 GB |
| Speicher | 5 GB | 10 GB + Belege und Dokumente |

- Ein Linux-Server (Debian oder Ubuntu) mit Root-Zugriff.
- Port **80** und **443** von außen erreichbar, ein schon laufender nginx/Apache, hinter den sich RedClub hängt — oder ein [Cloudflare Tunnel](#cloudflare-tunnel-ohne-offene-ports), dann muss gar kein Port offen sein.
- Für HTTPS eine (Sub-)Domain, deren DNS-A-Eintrag auf den Server zeigt. Push-Hinweise und Passkeys brauchen HTTPS.

## Schnellstart

```bash
curl -fsSL https://raw.githubusercontent.com/theredstonee/redclub-docker/main/install.sh | sudo bash
```

Das Skript erledigt Folgendes:
- legt alles nach **`/opt/redclub`** (anderer Ordner: `curl … | sudo RC_DIR=/srv/redclub bash`)
- installiert Docker, falls nötig
- erzeugt ein Datenbank-Passwort und startet alles
- zeigt am Ende die Adresse und den **Setup-Code**

Öffne die Adresse im Browser und folge dem Assistenten.

<details>
<summary>Lieber von Hand?</summary>

```bash
mkdir redclub && cd redclub
for f in docker-compose.yml compose.caddy.yml compose.port.yml Caddyfile .env.example; do curl -fsSLO "https://raw.githubusercontent.com/theredstonee/redclub-docker/main/$f"; done
cp .env.example .env
nano .env                # DB_PASSWORD setzen (lang und zufällig)
docker compose up -d
docker compose logs app | grep Setup-Code
```

Danach `http://<IP-deines-Servers>` im Browser öffnen.
</details>

### Domain und HTTPS

Im Assistenten gibst du deine Domain ein. Er zeigt die erkannte Server-IP und den nötigen DNS-Eintrag, prüft ihn und holt das Zertifikat.

- Lege einen **A-Eintrag** auf die IP deines Servers an.
- Bei **Cloudflare** den Proxy ausschalten (graue Wolke), sonst kann das Zertifikat nicht ausgestellt werden.

### Hinter deinem eigenen Webserver

Läuft auf dem Server schon nginx, Apache oder ein Panel wie Plesk auf Port 80/443, merkt `install.sh` das und richtet RedClub **ohne eigenen Caddy** ein:
- Die App bekommt einen freien Port auf `127.0.0.1`.
- Auf Nachfrage legt das Skript für deine Domain den Virtual Host an und holt per `certbot` das Zertifikat.
- Noch keine Domain? Dann ist RedClub **nur für die Einrichtung** unter `http://<Server-IP>` erreichbar: ein eigener Eintrag nur für die IP, geschützt durch den Setup-Code. Nach dem Assistenten entfernt das Skript ihn wieder und richtet für die Domain aus dem Assistenten Virtual Host und Zertifikat ein.

Für Belege und Dokumente die Upload-Grenze im Webserver großzügig setzen (nginx: `client_max_body_size 110m;`).

Ohne Nachfragen geht es mit Schaltern:

```bash
sudo bash install.sh --port 8080 --domain verein.example.com --email vorstand@example.com
```

`--no-vhost` lässt den Webserver unangetastet, `--caddy` erzwingt den eigenen Caddy.

### Cloudflare Tunnel (ohne offene Ports)

Für Heimserver oder Server hinter einer Firewall: RedClub baut über einen eigenen `cloudflared`-Container die Verbindung zu Cloudflare auf, Cloudflare liefert deine Domain samt HTTPS aus — Port 80/443 müssen nicht offen sein. Einrichten gleich im **Einrichtungs-Assistenten** (Schritt „Adresse & HTTPS“ → „Cloudflare Tunnel“) oder später im Panel unter **Einstellungen → Installation → Cloudflare Tunnel**, auf zwei Wegen:

- **Tunnel-Token:** Tunnel im Cloudflare-Dashboard anlegen (Zero Trust → Networks → Tunnels), als Public Hostname deine Domain mit Service `HTTP` → `app:3000`, dann den Token im Panel einfügen.
- **Automatisch:** ein Cloudflare-API-Token mit den Rechten „Account → Cloudflare Tunnel → Edit“ und „Zone → DNS → Edit“ einfügen — RedClub legt Tunnel, Weiterleitung und DNS-Eintrag selbst an und räumt sie auf Wunsch wieder ab.

### Eigene Domain für die Vereins-Website

Die Website ist ohne weiteres unter `https://<RedClub-Adresse>/web` erreichbar. Eine eigene Domain (z. B. `www.meinverein.de`) richtest du im Panel unter **Website → Gestaltung & Einstellungen → Adresse** ein — je nach Installation:

- **Eigener Caddy:** DNS-Eintrag auf den Server setzen, das Zertifikat holt RedClub beim ersten Aufruf selbst.
- **Cloudflare Tunnel (automatisch eingerichtet):** RedClub trägt die Domain selbst als weiteren Hostnamen im Tunnel ein und legt den DNS-Eintrag an. Beim Tunnel per Token den Hostnamen im Cloudflare-Dashboard ergänzen.
- **Hinter nginx/Apache:** Der Server-Dienst legt einen Virtual Host für die Domain an und holt per certbot das Zertifikat (HTTPS-Weiterleitung, HSTS). Fremde Einträge für die Domain fasst er nicht an. Auf älteren Installationen dafür einmal `sudo bash install.sh` ausführen.

### RedDrop für Dateien und Fotos

Mit eigenem Caddy fragt `install.sh`, ob [RedDrop](https://www.theredstonee.de/reddrop/) gleich mitinstalliert werden soll (eigene Domain nötig). Danach in RedDrop einen API-Token anlegen und in RedClub unter **Verwaltung → Verbindungen** eintragen. Dort lässt sich auch RedClub als Anmelde-Dienst für RedDrop eintragen — Vorstand und Mitglieder melden sich dann mit ihrem RedClub-Zugang an.

## Push aufs Handy

Panel → **Einstellungen → Benachrichtigungen → Push aufs Handy** → „Auf diesem Gerät einschalten“. Auf Android und am Rechner geht das direkt im Browser; auf dem **iPhone** zuerst RedClub über Teilen → „Zum Home-Bildschirm“ installieren und von dort öffnen. Die Schlüssel für den Versand erzeugt RedClub selbst — es braucht kein Konto bei einem Push-Anbieter.

## Update

Am einfachsten im Panel: unten links in der Seitenleiste steht die Version — ein roter Punkt heißt „neue Version da“, Klick → **Jetzt aktualisieren**. Von Hand:

```bash
cd /opt/redclub
docker compose pull && docker compose up -d
```

Die Datenbank wird beim Start automatisch nachgezogen. Ein zweiter Aufruf von `sudo bash install.sh` macht dasselbe und bringt auch den Update-Dienst auf den neuesten Stand.

## Entfernen

```bash
sudo bash /opt/redclub/install.sh --deinstallieren
```

Stoppt und entfernt die Container und die Webserver-Einträge von RedClub (gesichert nach `/root/redclub-backup`). Vereinsdaten und Ordner werden nur nach einer Rückfrage und dem Eintippen von `loeschen` gelöscht; sonst bleiben sie für einen Neustart erhalten.

## Umzug auf einen anderen Server

Panel → **Einstellungen → Umzug** (nur der Inhaber): „Umzugsdatei erstellen“ packt alle Vereinsdaten, Konten, Einstellungen, Belege und Website-Bilder in eine mit deinem Passwort verschlüsselte Datei (`.rcumzug`). Auf dem neuen Server RedClub installieren und einrichten, dann dort unter **Umzug** die Datei hochladen. Danach gelten die Konten des alten RedClub; Adresse, HTTPS und Lizenz der neuen Installation bleiben. Vor dem Import legt RedClub eine Sicherung des bisherigen Stands an (7 Tage).

## Sicherung

- **Datenbank** (alle Vereinsdaten): `docker compose exec db pg_dump -U redclub redclub > redclub.sql`
- **Belege und Dokumente:** das Volume `daten` (im Container `/data`).

## Hilfe

- **Zwei-Faktor-Gerät verloren und keine Notfall-Codes:** den Container einmal mit `RC_RESET_2FA=<benutzername>` in der `.env` starten (`docker compose up -d`), danach die Zeile wieder entfernen.
- **Setup-Code nicht mehr da:** `docker compose logs app | grep Setup-Code`
- **Logs:** `docker compose logs -f app`

---

RedClub ist ein Produkt von [TheRedStonee](https://www.theredstonee.de/). Der Quelltext ist nicht öffentlich; dieses Repository enthält die Installationsdateien für das Docker-Image `ghcr.io/theredstonee/redclub`.
