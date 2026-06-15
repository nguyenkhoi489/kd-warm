# KTStack

> Native macOS local development environment for PHP, Node.js, Python and Go.
>
> Run local websites with trusted HTTPS at `https://your-site.test` — no Docker required.

![KTStack Screenshot](docs/images/dashboard.png)

KTStack is a modern alternative to Laravel Herd, Valet and Laragon for macOS.

* 🔒 Trusted local HTTPS with automatic TLS certificates
* 🌐 Automatic `.test` domains (`myapp.test`)
* ⚡ Nginx + PHP-FPM + MySQL + PostgreSQL + Redis
* 📦 On-demand runtime installation
* 🧩 Multiple PHP versions
* 📬 Built-in Mailpit
* 📄 Live log viewer
* 🔄 Sparkle auto updates
* 🍎 Native SwiftUI app

---

## Why KTStack?

Most local development tools force developers to choose between:

| Tool          | Limitation           |
| ------------- | -------------------- |
| Laravel Valet | PHP-focused          |
| Laravel Herd  | Closed-source        |
| Docker        | Heavy resource usage |
| Laragon       | Windows only         |

KTStack combines the best parts of all of them:

* Native macOS experience
* Open source
* Multi-language runtime support
* Automatic HTTPS
* Lightweight (no containers)
* One-click service management

---

## Features

### Automatic Local Domains

Register a project and instantly access:

```text
https://my-project.test
```

No hosts-file editing required.

KTStack automatically configures:

* dnsmasq
* resolver
* Nginx virtual hosts
* TLS certificates

---

### Trusted HTTPS

Powered by mkcert.

Every site receives a trusted local certificate:

```text
https://shop.test
https://api.test
https://admin.test
```

Works with:

* Chrome
* Safari
* Firefox

---

### Runtime Manager

Install runtimes only when needed.

Supported:

* PHP 8.1
* PHP 8.3
* PHP 8.4
* Node.js
* Python
* Go

Per-project version switching:

```bash
.php-version
.nvmrc
.kdwarmrc
```

---

### Service Manager

Control all services from one dashboard.

Supported:

* Nginx
* PHP-FPM
* MySQL
* PostgreSQL
* Redis
* Mailpit
* dnsmasq

Features:

* Start / Stop / Restart
* Live status indicators
* Automatic shutdown when KTStack exits

---

### Built-in Database Support

Install databases on demand:

* MySQL
* PostgreSQL
* Redis

No manual configuration required.

---

### Mail Testing

Mailpit is included.

PHP mail is automatically captured and displayed inside KTStack.

Perfect for:

* Laravel
* Symfony
* WordPress
* Custom PHP applications

---

### Live Logs

Monitor logs directly inside the application.

Features:

* Real-time updates
* Filtering
* Per-site logs
* Per-service logs
* Clear log files

---

## Architecture

KTStack is built using Swift and SwiftUI.

### Components

| Component    | Purpose                   |
| ------------ | ------------------------- |
| KTStack.app  | Main menu-bar application |
| KDWarmKit    | Core framework            |
| KDWarmHelper | Privileged helper         |

Data is stored under:

```text
~/Library/Application Support/KDWarm/
```

---

## Screenshots

### Dashboard

![Dashboard](docs/images/dashboard.png)

### Sites

![Sites](docs/images/sites.png)

### Runtimes

![Runtimes](docs/images/runtimes.png)

### Logs

![Logs](docs/images/logs.png)

---

## Installation

Download the latest release:

```text
GitHub Releases → KTStack.dmg
```

1. Open the DMG
2. Drag KTStack into Applications
3. Launch KTStack
4. Grant permissions when prompted
5. Start building

---

## Build From Source

Requirements:

* macOS 13+
* Xcode 15+
* XcodeGen

```bash
brew install xcodegen

git clone https://github.com/your-org/ktstack.git
cd ktstack

xcodegen generate

xcodebuild \
  -project KDWarm.xcodeproj \
  -scheme KDWarm \
  -destination 'platform=macOS' \
  build
```

---

## Roadmap

* [ ] Docker integration
* [ ] Linux support
* [ ] Automatic project detection
* [ ] GUI database browser
* [ ] Team project sharing

---

## Contributing

Issues and pull requests are welcome.

If KTStack helps your workflow, consider giving the project a ⭐ on GitHub.

---

## License

Open source.

Third-party components retain their original licenses.

See:

```text
NOTICES.txt
```

for complete license information.

---

Built with ❤️ by Nguyên Khôi

https://nguyenkhoi.dev
