# 00 — Introduction

## What KTStack is

KTStack is a menu-bar app that turns your Mac into a complete local web development environment. Instead of wrestling with Docker, Homebrew services, and `/etc/hosts` entries, you create a site in a couple of clicks and open it at a real HTTPS address like `https://myapp.test`.

Everything runs natively on macOS. There is no virtual machine and no container layer, so sites start instantly and use very little memory.

![KTStack dashboard overview](images/00-overview.png)

## What you can do with it

- **Serve local sites** at `https://<name>.test` with browser-trusted HTTPS.
- **Run multiple PHP versions** (7.4 through 8.4) and pick a different one per project.
- **Run Node apps** behind the same friendly domains.
- **Use bundled databases** — MySQL, PostgreSQL, Redis, and MongoDB — without installing anything separately.
- **Test outgoing email** with the built-in Mailpit inbox.
- **Browse and edit databases** with a full SQL editor, data grid, and ER diagram.
- **Watch logs live** and capture `dump()` / `dd()` output from your PHP app.
- **Share a site publicly** through a Cloudflare Tunnel, complete with a QR code.

## Core concepts

Understanding four words makes the rest of this guide easy.

| Term | Meaning |
|------|---------|
| **Site** | A local project folder that KTStack serves at `https://<name>.test`. |
| **Service** | A background process KTStack supervises for you: Nginx, PHP-FPM, MySQL, PostgreSQL, Redis, MongoDB, Mailpit, and dnsmasq. |
| **Runtime** | A language version you install and switch between — PHP and Node. |
| **TLD** | The domain suffix used for local sites. The default is `.test`. |

## How a request works

When you open `https://myapp.test` in your browser, this is what happens behind the scenes:

1. macOS asks KTStack's DNS service where `myapp.test` lives, and it answers `127.0.0.1` (your own Mac).
2. Nginx receives the request on port 443, serves the local HTTPS certificate, and forwards it to the right runtime.
3. The matching PHP-FPM pool or Node process handles the request and returns the response.

You never configure any of this by hand — KTStack wires it up when you create a site.

## What you need

- A Mac running **macOS 13 (Ventura) or later**.
- An administrator password the **first** time you enable local DNS (KTStack installs a small privileged helper for that one job, then never needs the password again for normal use).
- About 1 GB of free disk space for the app plus each runtime you install.

## Where to go next

Continue to [01 — Install & first run](01-install-and-first-run.md) to get KTStack set up, then [03 — Managing sites](03-managing-sites.md) to create your first site.
