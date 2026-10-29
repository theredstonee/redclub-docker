# RedClub

**Selbst gehostete Vereinsverwaltung** für Vereine in Deutschland, Österreich und der Schweiz. RedClub läuft als Docker-Paket auf eurem eigenen Server — die Daten eurer Mitglieder bleiben bei euch. Das HTTPS-Zertifikat holt RedClub selbst.

By [TheRedStonee](https://www.theredstonee.de/) · 5 Tage kostenlos testen, danach mit Lizenz

> **English:** Self-hosted club management for associations in Germany, Austria and Switzerland. Runs as a Docker package on your own server, so your members' data stays with you. Members, groups, events with sign-ups and helper shifts, newsletters, a members area (installable app with push notices), double-entry bookkeeping with DATEV export, invoices with Swiss QR-bill / GiroCode, SEPA direct debit, Stripe and bank-statement import, donation receipts, certificates, volunteer hours and coach payouts, RedDrop files and single sign-on for other apps, plus a website builder for the club homepage with membership form and contact form. Web hosting like Plesk/KeyHelp (PHP 8.2–8.5 per site, 13 one-click apps, site migration, MariaDB with remote access, SFTP, cron), an own mail server with webmail, and encrypted restic backups to SFTP, S3, WebDAV, FTP or Dropbox. Cloudflare Tunnel for servers without open ports. 5-day trial, then with a licence — without one everything stays readable and exportable. One `docker compose up`, automatic HTTPS via Let's Encrypt. German and English. Jump to [Quick start](#schnellstart).

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
- **Website-Baukasten:** die Vereins-Homepage aus Blöcken (Titelbild, Text, Termine, Trainingszeiten, News, Vorstand, Beiträge, Spenden, Galerie, Anfahrt, Fragen) mit Live-Vorschau — auf eurer eigenen Domain mit automatischem HTTPS oder unter `/web`. Mitgliedsantrag (auf Wunsch mit SEPA-Mandat) und Kontaktformular landen direkt im Panel; Impressum und Datenschutz entstehen aus den Vereinsdaten.
  Dazu Code-Seiten, eigene fertige Websites als ZIP, Weiterleitungen auf eigene Server und vier Vorlagen (Sport, Coding, Musik, Feuerwehr).
- **Hosting wie bei Plesk/KeyHelp:** weitere Websites mit eigener Domain, **PHP 8.2 bis 8.5 je Seite wählbar**, **13 Apps mit einem Klick** (WordPress, Joomla, Nextcloud, Drupal, MODX, Grav, OpenCart, Flarum, phpBB, MediaWiki, BookStack, Lychee, Piwigo), **Umzug bestehender Websites** (ZIP/tar, All-in-One-WP-Migration, SFTP/FTP mit Datenbank), MariaDB-Datenbanken mit Adminer und Fernzugriff, Dateimanager mit Archiven und Rechten, SFTP, Cronjobs mit Assistent, HTTPS/HSTS je Seite, Speicher- und Traffic-Übersicht — [mehr dazu](#hosting).
- **Eigener Mailserver:** Postfächer, Aliase, Weiterleitungen, Sammeladresse, **Verteiler direkt aus den Gruppen**, Spam- und Virenfilter, DKIM, DNS-Assistent, SMTP für Websites und Apps — und ein **Webmail** im Panel, das auch fremde Postfächer (IMAP/SMTP) verbindet — [mehr dazu](#e-mail).
- **Backups mit restic:** verschlüsselt, dedupliziert, nach Zeitplan auf SFTP, S3, WebDAV/Nextcloud, FTP(S) oder Dropbox; einzelne Dateien und Datenbanken zurückholen — [mehr dazu](#sicherung).
- **Module zum Einschalten:** Abstimmungen und digitale Mitgliederversammlung, Inventar mit Verleih und Raumbuchung, Shop, digitaler Mitgliederausweis mit Einlass-Scanner, Auswertungen mit Monatsbericht — und Erweiterungen von Dritten (abgeschottet, nur mit freigegebenen Rechten).
- **Löschschutz:** Papierkorb für 30 Tage, „Rückgängig“ direkt nach dem Löschen, große Löschungen nur mit eingetipptem Namen.
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
| mit Hosting | + 1 GB RAM | + 2 GB RAM, Platz für die Websites |
| mit Mailserver | + 400 MB RAM | + 1,5 GB RAM mit Virenscanner, Platz für die Postfächer |

- Ein Linux-Server (Debian oder Ubuntu) mit Root-Zugriff.
- Port **80** und **443** von außen erreichbar, ein schon laufender nginx/Apache, hinter den sich RedClub hängt — oder ein [Cloudflare Tunnel](#cloudflare-tunnel-ohne-offene-ports), dann muss gar kein Port offen sein.
- Für HTTPS eine (Sub-)Domain, deren DNS-A-Eintrag auf den Server zeigt. Push-Hinweise und Passkeys brauchen HTTPS.

## Schnellstart

```bash
curl -fsSL https://raw.githubusercontent.com/theredstonee/redclub-docker/main/install.sh | sudo bash
```

Das Skript erledigt Folgendes:
- legt alles nach **`/opt/redclub`** (anderer Ordner: `curl … | sudo RC_DIR=/srv/redclub bash`; auf **Unraid** nach `/mnt/user/appdata/redclub`, weil dort alles außerhalb von `/boot` und `/mnt` nach einem Neustart weg ist — eine bestehende Installation in `/opt` zieht beim nächsten Update von selbst um)
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

## Hosting

Weitere Websites des Vereins (oder WordPress, Joomla, Nextcloud) laufen direkt auf dem RedClub-Server. Einschalten im Panel unter **Module → Hosting**, dann **Hosting → Einschalten** und PHP-Version wählen. Der Update-Dienst startet dafür zwei Container: `web` (Apache mit PHP) und `phpdb` (MariaDB). Beide liegen in einem eigenen Netz — PHP-Code der Websites erreicht weder die Vereinsdatenbank noch RedClub selbst.

- **PHP je Seite:** Standard ist die beim Einschalten gewählte Version; weitere Versionen (8.2 bis 8.5) startet der Update-Dienst als eigene Container `web82` … `web85`, sobald eine Seite sie braucht.
- **Apps und Umzug:** Apps mit Admin-Konto in einem Schritt (die Versionen kommen von den Herstellern, mit Prüfsumme). Bestehende Websites ziehen per Archiv, `.wpress`-Datei oder direkt vom alten Server (SFTP/FTP, Datenbank per Fernzugriff oder Export-Skript) um — WordPress-Adressen werden dabei umgeschrieben, auf Wunsch als Testkopie ohne Suchmaschinen.
- **Seiten:** je Seite eine Domain (auf Wunsch mit `www.`), ein eigener Ordner, eigene PHP-Werte und Speichergrenze. Das Zertifikat kommt wie bei der Vereins-Website von selbst (eigener Caddy, Cloudflare Tunnel oder per certbot hinter nginx/Apache). Eigene Zertifikate oder Cloudflare-Origin-Zertifikate lassen sich je Domain hochladen.
- **Dateien:** Dateimanager im Browser (hochladen, ZIP entpacken, bearbeiten, Papierkorb) oder per **SFTP** — einschalten unter Hosting → SFTP, Standard-Port `2222` (in der `.env`: `RC_SFTP_PORT`, nur lokal: `RC_SFTP_BIND=127.0.0.1`). Jedes SFTP-Konto sieht nur seine Seite, eine Shell gibt es nicht.
- **Datenbanken:** je Datenbank ein eigener Benutzer, Host für Apps `phpdb`, Port `3306`. Verwalten im Browser mit Adminer (Anmeldung ohne Passwort im Browser), Import und Export als SQL. **Fernzugriff** je Datenbank nur für freigegebene IPs — öffnet Port `3306` (in der `.env`: `RC_PHPDB_FERN_PORT`).
- **Aufgaben:** Cronjobs als Befehl oder Aufruf einer Adresse, mit Klartext-Anzeige („jeden Montag um 3:00“), Protokoll und Mail bei Fehlern.
- **Sicherungen** täglich oder wöchentlich je Seite (Dateien und Datenbanken), Zurückholen mit einem Klick — oder mit [restic](#sicherung) auf einen fremden Speicher.
- **Mit Traefik oder Nginx Proxy Manager:** RedClub im Port-Modus installieren und jede Hosting-Domain in deinem Proxy auf den RedClub-Port leiten — RedClub verteilt die Anfragen selbst auf die richtige Seite.

Hosting braucht zusätzlich etwa **1 GB RAM** und den Platz für die Websites. Ausschalten stoppt PHP und MariaDB, Dateien und Datenbanken bleiben erhalten.

## E-Mail

Panel → **E-Mail → Einschalten**: RedClub startet einen eigenen Mailserver ([docker-mailserver](https://github.com/docker-mailserver/docker-mailserver) mit Rspamd) für eure Domains. Nötig sind eine **öffentliche IP** mit offenen Ports **25, 465, 587 und 993** und ein DNS-Eintrag für den Namen des Mailservers (z. B. `mail.meinverein.de`). Über einen Cloudflare Tunnel geht das nicht.

- **Postfächer** mit Kontingent, **Aliase und Weiterleitungen** (auch nach außen, mit SRS), **Sammeladresse** je Domain und **Verteiler aus den Gruppen** — die Empfänger kommen aus der Mitgliederliste, auf Wunsch nur für Absender aus dem Verein.
- **DNS-Assistent:** zeigt MX, SPF, DKIM, DMARC und PTR zum Abtippen und prüft, was schon stimmt. Ist ausgehender Port 25 gesperrt, gehen Mails über einen **Relay-Server** (z. B. euer Anbieter).
- **SMTP für Websites und Apps:** je App ein eigenes Konto mit Versand-Grenze. RedClub selbst kann Rundmails und Rechnungen ebenfalls darüber senden.
- **Spam und Viren:** Spam landet im Ordner „Junk“; die Grenzen sind einstellbar. Der Virenscanner ClamAV braucht etwa 1,2 GB RAM zusätzlich und ist daher abschaltbar.
- **Webmail** (Panel → E-Mail → Webmail): jedes Vorstandskonto verbindet eigene Postfächer — vom eigenen Mailserver oder von einem anderen Anbieter. HTML-Mails werden bereinigt und abgeschottet angezeigt, externe Bilder erst auf Klick.

Der Mailserver braucht etwa **400 MB RAM** (mit Virenscanner rund 1,5 GB). Das Zertifikat kommt von Caddy bzw. certbot, sobald der DNS-Eintrag stimmt; bis dahin nimmt er ein selbst erzeugtes.

## Push aufs Handy

Panel → **Einstellungen → Benachrichtigungen → Push aufs Handy** → „Auf diesem Gerät einschalten“. Auf Android und am Rechner geht das direkt im Browser; auf dem **iPhone** zuerst RedClub über Teilen → „Zum Home-Bildschirm“ installieren und von dort öffnen. Die Schlüssel für den Versand erzeugt RedClub selbst — es braucht kein Konto bei einem Push-Anbieter.

## Update

Am einfachsten im Panel: unten links in der Seitenleiste steht die Version — ein roter Punkt heißt „neue Version da“, Klick → **Jetzt aktualisieren**. Das holt das neue Image, die aktuellen Compose-Dateien und bringt auch den Update-Dienst selbst auf den neuesten Stand.

Auf dem Server geht dasselbe mit einem Befehl — er richtet **nichts neu ein**, fragt nichts und lässt `.env`, Daten und Domain, wie sie sind (alte Dateien landen in `.sicherung/`):

```bash
curl -fsSL https://raw.githubusercontent.com/theredstonee/redclub-docker/main/update.sh | sudo bash
```

Installationen von vor diesem Befehl brauchen ihn **einmal** — danach aktualisiert der Knopf im Panel auch den Dienst. Ganz von Hand, nur das Image:

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

Panel → **System → Backups**: RedClub sichert Vereinsdatenbank, Belege und Dokumente sowie auf Wunsch die Hosting-Seiten und ihre Datenbanken mit **restic** — verschlüsselt und dedupliziert (unveränderte Daten kosten keinen Platz).

- **Ziele:** SFTP, S3 (auch kompatible Anbieter), WebDAV/Nextcloud, FTP(S), Dropbox oder ein Ordner auf dem Server. Mehrere Pläne mit eigenem Zeitplan und Aufbewahrung (z. B. 7 täglich, 4 wöchentlich, 12 monatlich).
- **Wiederherstellungsschlüssel:** einmal beim Einrichten angezeigt und als Notfallblatt (PDF) zum Ausdrucken — ohne ihn lassen sich die Backups nicht lesen.
- **Zurückholen:** Snapshots durchstöbern, einzelne Dateien herunterladen oder ganze Seiten und Datenbanken zurückspielen.

Von Hand geht es weiterhin so:

- **Datenbank** (alle Vereinsdaten): `docker compose exec db pg_dump -U redclub redclub > redclub.sql`
- **Belege und Dokumente:** das Volume `daten` (im Container `/data`).

## Hilfe

- **Zwei-Faktor-Gerät verloren und keine Notfall-Codes:** den Container einmal mit `RC_RESET_2FA=<benutzername>` in der `.env` starten (`docker compose up -d`), danach die Zeile wieder entfernen.
- **Setup-Code nicht mehr da:** `docker compose logs app | grep Setup-Code`
- **Logs:** `docker compose logs -f app`

---

RedClub ist ein Produkt von [TheRedStonee](https://www.theredstonee.de/). Der Quelltext ist nicht öffentlich; dieses Repository enthält die Installationsdateien für das Docker-Image `ghcr.io/theredstonee/redclub`.
