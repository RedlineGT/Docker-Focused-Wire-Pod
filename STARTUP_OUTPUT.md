# Docker Startup Output Guide

When you start Wire-Pod with Docker, you'll see different output depending on which variant you're using.

## Production Variant (Dockerfile.full)

**Clean, minimal output. Best for production.**

### Command:
```bash
docker compose up -d
```

### Output:
```
Wire-Pod started successfully
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  📱 Web UI:        http://localhost:8080
  🚀 Image Size:    186 MB (Alpine-based, optimized)
  ✓ Status:         Ready

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Features:**
- ✓ Quick to scan (8 lines)
- ✓ Web UI link ready to click
- ✓ Shows actual image size (calculated dynamically)
- ✓ Minimal resource overhead

---

## Debug Variant (Dockerfile.slim)

**Detailed diagnostic output. Best for debugging & development.**

### Commands:
```bash
# Option 1: Using compose override
docker compose -f compose.yaml up -d

# But update compose.yaml first:
# - Change dockerfile: Dockerfile.full → Dockerfile.slim
# - Change image: ghcr.io/kercre123/wire-pod:debug

# Option 2: Direct build & run
./build.sh --debug
docker run -it ghcr.io/kercre123/wire-pod:debug
```

### Output:
```
Wire-Pod Debug Container Started
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📱 ACCESS POINTS:
  Web UI:         http://localhost:8080
  mDNS Hostname:  http://escapepod.local
  Container ID:   a1b2c3d4e5f6

🖥️  IMAGE INFORMATION:
  Size:           630 MB (Ubuntu-based, includes debug tools)
  Base:           ubuntu:22.04
  Commit:         a1b2c3d

📂 MOUNT POINTS:
  Data Volume:    /data
  Configs:        /data/chipper/
  Certificates:   /data/certs/
  STT Models:     /data/stt/
  Vosk Library:   /data/vosk/
  Plugins:        /data/chipper/plugins/

⚙️  ENVIRONMENT VARIABLES:
  WIREPOD_DATA_DIR:      /data
  STT_SERVICE:           vosk (default)
  DEBUG_LOGGING:         false

🔧 AVAILABLE DEBUG TOOLS:
  ✓ nano              (Text editor)
  ✓ jq                (JSON processor)
  ✓ dnsutils          (DNS diagnostics)
  ✓ net-tools         (Network tools)
  ✓ curl              (HTTP testing)

🔒 SECURITY:
  User:               root (required for audio access)
  Capabilities:       NET_BIND_SERVICE enabled

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 DEBUGGING COMMANDS:
  • Logs:             docker compose logs -f wire-pod
  • Shell:            docker compose exec wire-pod /bin/bash
  • Test health:      curl http://localhost:8080/ok
  • View config:      docker compose exec wire-pod cat /data/chipper/botConfig.json | jq .
```

**Features:**
- ✓ Comprehensive diagnostic info (35 lines)
- ✓ Mount points clearly listed
- ✓ Environment variables shown
- ✓ Available debug tools listed
- ✓ Troubleshooting commands provided
- ✓ Actual image size calculated dynamically
- ✓ Commit SHA from build shown

---

## How It Works

### Variant Detection

The startup script automatically detects which variant you're running by checking if "debug" appears in the image name:

```bash
# This triggers PRODUCTION output (minimal)
image: ghcr.io/kercre123/wire-pod:main
image: ghcr.io/kercre123/wire-pod:latest

# This triggers DEBUG output (detailed)
image: ghcr.io/kercre123/wire-pod:debug
image: ghcr.io/kercre123/wire-pod:debug-latest
```

### Image Size Calculation

Image size is calculated **dynamically at runtime** using `du`:
- Production: Shows actual Alpine image size (~186MB)
- Debug: Shows actual Ubuntu image size (~630MB)
- Sizes may vary slightly based on build

### Commit SHA

The commit SHA comes from:
1. Build time: Captured from `git rev-parse --short HEAD`
2. Stored in: `/opt/wire-pod/.wirepod-version`
3. Displayed at: Container startup (debug variant only)

### Hostname

Always shows **escapepod.local** for mDNS compatibility.
- Required for Vector robot to discover the pod
- If changed, Vector connection may break

---

## Switching Variants

### To use Debug variant temporarily:

Edit `compose.yaml`:
```yaml
build:
  dockerfile: Dockerfile.slim  # Changed from Dockerfile.full
image: ghcr.io/kercre123/wire-pod:debug  # Add "debug" to image name
```

Then:
```bash
docker compose up -d --build
```

### To switch back to Production:

Edit `compose.yaml`:
```yaml
build:
  dockerfile: Dockerfile.full  # Back to production
image: ghcr.io/kercre123/wire-pod:main  # Remove "debug"
```

Then:
```bash
docker compose up -d --build
```

---

## What Changed

The `docker/entrypoint.sh` script now:
1. Detects image variant (looks for "debug" in image name)
2. Calculates actual image size at runtime
3. Reads commit SHA from `.wirepod-version`
4. Prints appropriate startup message
5. Then executes the main process

**No impact on:**
- Build time
- Runtime performance
- Memory usage
- Functionality

---

## Troubleshooting

**Q: I don't see the startup message**
- Check: `docker compose logs wire-pod` (should show startup info at top)
- It prints to stdout, so it appears when container starts

**Q: Image size shows "unknown"**
- Normal on some systems where `du` is unavailable
- Container still works fine

**Q: How do I always use debug variant?**
- Edit `compose.yaml` to use `Dockerfile.slim` and image name with "debug"
- Then `docker compose up -d` always uses debug

**Q: Can I disable the startup output?**
- Not recommended (it's helpful)
- But you can suppress with: `docker compose up -d` (stdout hidden in daemon mode)
- Or redirect: `docker compose up -d 2>&1 | grep -v "Wire-Pod"`

---

## Next Steps

1. **Build & test:** `./build.sh --prod && docker compose up -d`
2. **Check output:** `docker compose logs --tail 50`
3. **Access web UI:** `http://localhost:8080`
4. **For debugging:** Switch to Dockerfile.slim and rebuild
