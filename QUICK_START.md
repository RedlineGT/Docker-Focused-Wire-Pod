# Quick Start: New Docker Setup

Get Wire-Pod running with the optimized Docker setup in 5 minutes.

## Installation (First Time)

```bash
# 1. Build production image
./build.sh --prod

# 2. Run with Docker Compose
docker compose up -d

# 3. Wait for startup
sleep 15

# 4. Access web UI
open http://localhost:8080   # macOS
xdg-open http://localhost:8080  # Linux

# 5. Or test with curl
curl http://localhost:8080/ok
```

That's it! Wire-Pod is running.

---

## Common Commands

```bash
# View logs
docker compose logs -f

# Check status
docker compose ps

# Stop
docker compose down

# Restart
docker compose restart

# Access shell
docker compose exec wire-pod /bin/bash

# Rebuild after code changes
./build.sh --prod
docker compose up -d --build
```

---

## Build Options

```bash
# Production (Alpine, ~180MB, ~3min to build)
./build.sh --prod

# Debug (Ubuntu, ~630MB, includes tools like nano, jq)
./build.sh --debug

# For different architecture
./build.sh --prod --platform linux/arm64
./build.sh --prod --platform linux/armv7

# With security scanning
./build.sh --prod --scan

# With SBOM generation
./build.sh --prod --sbom

# All features
./build.sh --prod --scan --sbom
```

---

## Security

```bash
# Scan for vulnerabilities
./scan.sh wire-pod:latest

# High/Critical only
./scan.sh wire-pod:latest --severity HIGH,CRITICAL

# Generate JSON report
./scan.sh wire-pod:latest --format json > report.json

# With SBOM
./scan.sh wire-pod:latest --sbom
```

---

## Volume/Data

Wire-Pod persists data in `./data/` directory:
```
./data/
├── certs/              # TLS certificates
├── chipper/
│   ├── apiConfig.json  # API settings
│   ├── botConfig.json  # Robot config
│   ├── plugins/        # User plugins
│   └── session-certs/  # Robot auth
├── stt/                # STT models
├── vosk/               # Vosk library
└── whisper.cpp/        # Whisper models
```

Back up before major updates:
```bash
tar czf backup-$(date +%Y%m%d).tar.gz ./data/
```

---

## Troubleshooting

**Container won't start?**
```bash
docker compose logs --tail 50
```

**Audio not working?**
```bash
# Add to compose.yaml under wire-pod service:
devices:
  - /dev/snd:/dev/snd
```

**Port already in use?**
```bash
# Change in compose.yaml:
ports:
  - "8080:8080"  # Instead of 80:80
```

**Need debug/dev tools?**
```bash
./build.sh --debug  # Ubuntu image with nano, jq, etc.
```

---

## Docker Compose Override

Create `compose.override.yaml` for local customization (git-ignored):

```yaml
services:
  wire-pod:
    # Add dev-only settings here
    # They override compose.yaml
    devices:
      - /dev/snd:/dev/snd
    environment:
      WIREPOD_DEBUG_LOGGING: "true"
```

---

## Environment Variables

```yaml
# In compose.yaml, add to environment:
WIREPOD_STT_SERVICE: "vosk"  # STT engine (vosk, whisper.cpp, leopard, etc.)
WIREPOD_DEBUG_LOGGING: "true"  # Enable verbose logging
WIREPOD_STT_LANGUAGE: "en"  # Language code
WIREPOD_USE_INBUILT_BLE: "true"  # Use built-in Bluetooth LE
WIREPOD_PICOVOICE_APIKEY: "your-api-key"  # For Leopard/Rhino STT
```

---

## Images

- **`ghcr.io/kercre123/wire-pod:latest`** (Alpine, ~180MB)
- **`ghcr.io/kercre123/wire-pod:debug`** (Ubuntu, ~630MB)
- **`ghcr.io/kercre123/wire-pod:main`** (Latest from git main branch)

---

## Documentation

- **DOCKER_IMPROVEMENTS.md** – Detailed explanation of all changes
- **MIGRATION_GUIDE.md** – Step-by-step migration from old setup
- **DEPLOYMENT_CHECKLIST.md** – Pre-deployment verification
- **DOCKER_ANALYSIS.md** – Original analysis and findings

---

## Need Help?

1. Check logs: `docker compose logs -f`
2. Read DOCKER_IMPROVEMENTS.md for detailed info
3. Check troubleshooting section above
4. GitHub Issues: https://github.com/kercre123/wire-pod/issues

---

## Version Info

To see your current setup:
```bash
./build.sh --help    # Build script options
./scan.sh --help     # Security scan options
docker compose version
docker --version
```

---

### Next Steps

- [ ] Run: `./build.sh --prod`
- [ ] Deploy: `docker compose up -d`
- [ ] Verify: `curl http://localhost:8080/ok`
- [ ] Read: `DOCKER_IMPROVEMENTS.md` for details
- [ ] Scan: `./scan.sh wire-pod:latest` for security

**Questions?** Check the documentation files above! 🚀
