# 18 — Troubleshooting & FAQ

This page covers common problems you might run into with KTStack and how to fix them, plus answers to frequently asked questions.

## Troubleshooting common issues

### Sites show "not secure" or "certificate not trusted" in browser

**Symptoms**: Browser shows a lock icon with a red X or "NET::ERR_CERT_AUTHORITY_INVALID" warning.

**Cause**: The local CA (certificate authority) hasn't been trusted in your System Keychain yet.

**Fix**:

1. Open KTStack and go to **Settings** (gear icon).
2. Scroll to **Maintenance** section.
3. Click **Manage…** next to "Local HTTPS Certificates".
4. Click **Install & Trust** (or **Trust** if the CA already exists).
5. macOS may ask for your admin password. Enter it.
6. Wait for the process to complete.
7. Restart your browser or clear the browser cache for `*.test` domains.
8. Reload your site — it should now show a green lock.

**If it still doesn't work**: 
- Make sure you're opening `https://` (not `http://`) in your browser.
- Check that you're using the right TLD (default is `.test`).
- Try restarting KTStack entirely.

See [05 — HTTPS & Certificates](05-https-and-certificates.md) for more details.

---

### `.test` domains don't resolve — "Cannot find the server"

**Symptoms**: Typing `https://myapp.test` shows "This site can't be reached" or "Server not found".

**Cause**: Local DNS (dnsmasq) is not running or is in conflict with another service.

**Fix**:

1. Open the KTStack dashboard.
2. Look at the **Services** section. Find **dnsmasq**.
3. If dnsmasq shows a **red dot** (error) or **gray dot** (stopped):
   - Click the **toggle** to start it.
   - Wait a few seconds and reload your browser.

4. If dnsmasq still won't start, check for a port conflict:
   - Open Terminal and run: `lsof -i :53`
   - If another service is using port 53, you'll see it listed.
   - Stop that service or change KTStack's DNS port in Settings.

5. If DNS shows as enabled but sites still don't resolve, flush your Mac's DNS cache:

```bash
sudo dscacheutil -flushcache
```

6. Try accessing a site again.

**If you see a "Port conflict" warning in the Services banner**:
- Click **Reset** to have KTStack try to recover.
- If that fails, restart KTStack entirely (quit and relaunch).

See [01 — Install & first run](01-install-and-first-run.md) for DNS setup details.

---

### A service won't start (Nginx, PHP-FPM, MySQL, etc.)

**Symptoms**: A service shows a **red dot** (error) or stays stuck with an hourglass icon.

**Fix**:

1. In the **Services** section, find the failing service.
2. Click the service row to see the error message, or look at the **Logs** section:
   - Click **Logs** in the dashboard.
   - Select the service from the list.
   - Read the error message and last few log lines.

3. **If it says "Address already in use"**:
   - Another app is using the same port (e.g., port 3306 for MySQL).
   - Run this to find what's using it: `lsof -i :[port]` (e.g., `lsof -i :3306`).
   - Stop the conflicting app or change KTStack's port in Settings.

4. **If it says "Permission denied"**:
   - Some services (especially dnsmasq) need elevated permissions.
   - Make sure you've completed DNS setup in [01 — Install & first run](01-install-and-first-run.md).
   - You may need to enter your admin password again.

5. **If the service keeps crashing**:
   - Try restarting it: Click the **restart button** (circular arrow) next to the service.
   - If it crashes again, the service data may be corrupted — see "Service data is corrupted" below.

6. Check your internet connection if installing a new service (download may have failed).

---

### Service data is corrupted or has errors

**Symptoms**: A database service gives errors like "database disk image malformed" or "Can't create table".

**Fix**:

1. In the **Services** section, find the affected service.
2. Click the **menu button** (three dots) next to it.
3. Select **Reset Data**.
4. A confirmation dialog appears. Click **Reset [Service] data**.
5. KTStack stops the service, deletes its data, and restarts it empty.
6. You can now recreate any databases you had.

**Warning**: This deletes all data in that service. Restore from a backup first if you have one — see [09 — Database backup & restore](09-database-backup-and-restore.md).

---

### PHP version isn't applying to a site

**Symptoms**: A site is running PHP 8.2, but you set it to PHP 8.4 and it's not updating.

**Fix**:

1. Go to the **Sites** section of the dashboard.
2. Find the site and click its **settings** (gear icon or edit button).
3. Check the "PHP version" dropdown. Make sure it's set to your desired version.
4. Save the settings.
5. Restart the PHP-FPM service:
   - Go to **Services** section.
   - Find **PHP-FPM** and click the **restart button** (circular arrow).
6. Reload your site in the browser.

**If that doesn't work**:
- Check that the PHP version is installed. Go to **Runtimes** and verify it's listed.
- If it's not installed, install it first — see [04 — PHP & runtimes](04-php-and-runtimes.md).

---

### Node app isn't running or shows an error

**Symptoms**: A Node site shows a 502 Bad Gateway or "Connection refused".

**Cause**: The Node process exited, the port is in use, or there's a startup error.

**Fix**:

1. Check the logs:
   - Go to the **Logs** section.
   - Find the Node app in the list (usually named like `node-myapp.out.log`).
   - Read the last few lines to see why it exited.

2. **If it says "port is already in use"**:
   - Another app is listening on that port.
   - Edit the site and change the port number.
   - Restart the site.

3. **If it shows a JavaScript error**:
   - Fix the error in your Node code.
   - Restart the site to reload it.

4. **If the Node version is too old**:
   - Install a newer Node version — see [04 — PHP & runtimes](04-php-and-runtimes.md).
   - Edit the site and select the new Node version.
   - Restart the site.

---

### Email isn't appearing in Mailpit

**Symptoms**: Your app sends an email, but it doesn't show up in Mailpit.

**Cause**: The app isn't configured to send via Mailpit, or Mailpit isn't running.

**Fix**:

1. Check that Mailpit is running:
   - Go to **Services** section.
   - Find **Mailpit** — if it has a gray dot, click the toggle to start it.

2. Configure your app to send mail to Mailpit:
   - **For PHP apps (Laravel, WordPress, etc.)**: Set `MAIL_HOST=127.0.0.1`, `MAIL_PORT=1025` in `.env`.
   - **For Node apps**: Use a mailer like Nodemailer configured to `host: '127.0.0.1', port: 1025`.

3. Check the Mailpit port:
   - By default, it listens on port 1025 for SMTP.
   - If you changed the port in Settings, update your app's config to match.

4. Test sending an email from your app.
5. Open the **Mailpit** section in the KTStack dashboard to view captured emails.

See [10 — Email testing with Mailpit](10-email-testing-mailpit.md) for more.

---

### Port 80 or 443 is already in use

**Symptoms**: Nginx won't start with "Address already in use".

**Cause**: Another service (web server, VPN, proxy) is using port 80 or 443.

**Fix**:

1. Open Terminal and find what's using the port:

```bash
sudo lsof -i :80
sudo lsof -i :443
```

2. Note the process name and PID.
3. Stop that process or application (e.g., stop Docker, stop a local Apache server, disable a VPN).
4. In KTStack, restart Nginx:
   - Go to **Services** section.
   - Click the restart button (circular arrow) next to **Nginx**.
5. Try accessing a site again.

If you can't stop the other service, you could run KTStack on different ports, but this requires manual Nginx configuration.

---

### Can't install a PHP/Node runtime — "Download failed"

**Symptoms**: Installing a new PHP or Node version shows "Download failed" or hangs.

**Cause**: Network issue, server is down, or storage is full.

**Fix**:

1. Check your internet connection.
2. Wait a moment and try again.
3. If it keeps failing, check available disk space:

```bash
df -h | grep -E "/$|/Users"
```

4. You need at least 1–2 GB free per runtime.
5. If you're very low on space, uninstall unused services or runtimes to free up room.

See [04 — PHP & runtimes](04-php-and-runtimes.md) for uninstall instructions.

---

### Helper won't approve or asks for password repeatedly

**Symptoms**: macOS keeps asking for admin password, or a permission prompt won't go away.

**Cause**: The privileged helper install failed, or the signature is invalid.

**Fix**:

1. Quit KTStack completely (`Cmd+Q`).
2. Relaunch KTStack.
3. When the DNS setup prompt appears, click **Enable DNS** and enter your admin password.
4. If it fails again, restart your Mac and try once more.

**If it still fails**:
- Uninstall and reinstall KTStack.
- Make sure you're running macOS 13 (Ventura) or later.
- Check that you have admin privileges on your account.

---

## Frequently Asked Questions

### Does KTStack require Docker?

**No**. KTStack runs everything natively on your Mac — no virtual machines, no containers, no Docker Desktop required. All services (Nginx, PHP-FPM, MySQL, etc.) run directly as macOS processes, which is why they start instantly and use minimal memory.

---

### Does KTStack cost money?

**No**. KTStack is completely free and open source. You can download it from [GitHub Releases](https://github.com/KTStackAPP/KTStack/releases) at no cost. There are no subscriptions, ads, or paid tiers.

---

### Do I need to enter my password every time?

**No**. The admin password is only needed once when you first enable DNS. After that, KTStack runs without needing a password for normal operations. Some settings changes (like changing the TLD) may require your password again because they modify system-level DNS configuration.

---

### Where is my KTStack data stored?

All KTStack data lives in:

```
~/Library/Application Support/KTStack/
```

This folder contains:
- `runtimes/` — Installed PHP and Node versions
- `config/` — Site configs, Nginx settings, PHP settings
- `data/` — Database files (MySQL, PostgreSQL, MongoDB, Redis, SQLite)
- `logs/` — Service logs
- `backups/` — Database backups
- `ca/` — Local certificate authority files
- `certs/` — Site certificates

You can back up this entire folder to preserve your sites and databases.

---

### Can I change the `.test` suffix to something else?

**Yes**. Go to **Settings > Sites & Network > Local TLD** and enter a new suffix (e.g., `local`, `dev`, `localhost`). KTStack will relaunch with the new TLD applied. See [16 — Settings & Preferences](16-settings-and-preferences.md) for details.

**Important**: Existing sites keep their old `.test` domains until you manually edit them. Changing the TLD is not reversible.

---

### Which macOS versions are supported?

**macOS 13 (Ventura) or later**. KTStack requires:
- macOS 13 (Ventura) or macOS 14 (Sonoma) or macOS 15 (Sequoia)
- Apple Silicon (M1, M2, M3, etc.) or Intel processor
- At least 1 GB of free disk space (more if installing multiple runtimes or databases)

Check your macOS version: **Apple menu > System Settings > General > About**.

---

### Can I run multiple sites at the same time?

**Yes**. Create as many sites as you want. They'll all be served simultaneously as long as their services are running. You can have 10, 50, or 100 sites pointing to different folders.

---

### Can I use KTStack for production?

**No**. KTStack is designed for **local development only**. It uses self-signed certificates, relies on local DNS, and is not configured for security, performance, or uptime requirements of production. Always deploy to a real server or hosting platform for live use.

---

### What happens to my sites if I restart my Mac?

All your sites stay where they are (in your chosen sites root folder). When you restart:
1. KTStack is not running yet.
2. Sites are inaccessible until you relaunch KTStack.
3. If "Auto-start server" is on in Settings, services start automatically when you log in.
4. Open a site once services are running.

See [16 — Settings & Preferences](16-settings-and-preferences.md) for launch and auto-start options.

---

### Can I edit nginx or PHP config files manually?

**Yes**, but with caution. Config files are located in:
- Nginx: `~/Library/Application Support/KTStack/config/nginx/`
- PHP: `~/Library/Application Support/KTStack/config/php/[version]/php.ini`

After editing:
1. Go to **Services** section.
2. Click **Restart All** (or restart the specific service).
3. KTStack reloads the new config.

If you break the syntax, the service will fail to start. Check the logs for error messages.

---

### How do I back up my databases?

See [09 — Database backup & restore](09-database-backup-and-restore.md) for full instructions. In short:

1. Go to **Database > Backups** tab.
2. Click **Create Backup** for each connection.
3. Backups are saved in `~/Library/Application Support/KTStack/backups/`.

---

### Can I share a site with someone on my network?

**Yes**, using Cloudflare Tunnel. KTStack generates a public URL and QR code so others can access your site. See [13 — Sharing with Cloudflare Tunnel](13-sharing-cloudflare-tunnel.md).

---

### My issue isn't listed here. Where do I get help?

1. **Check the [GitHub Issues](https://github.com/KTStackAPP/KTStack/issues)** to see if someone has reported the same problem.
2. **Search KTStack documentation** — each guide has a troubleshooting section.
3. **Post a new GitHub issue** with:
   - A clear description of the problem
   - Steps to reproduce it
   - Your macOS version and KTStack version
   - Any error messages from the Logs section
4. **Ask on the community forums** (if available).

---

## Where to go next

If your issue is resolved, head back to the guide for that feature. If you need to remove KTStack, see [17 — Uninstall & reset](17-uninstall-and-reset.md).

For more specific help, refer to the relevant guide:
- [01 — Install & first run](01-install-and-first-run.md) — Installation issues
- [05 — HTTPS & Certificates](05-https-and-certificates.md) — Certificate warnings
- [06 — Services](06-services.md) — Service startup and management
- [04 — PHP & runtimes](04-php-and-runtimes.md) — Runtime installation and switching
- [10 — Email testing with Mailpit](10-email-testing-mailpit.md) — Email issues
- [15 — Shell integration](15-shell-integration.md) — Terminal version switching

![Logs section showing service errors](images/18-logs-error-details.png)

![Services section with error indicator](images/18-services-error.png)
