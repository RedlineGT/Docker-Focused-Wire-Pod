# Wire-Pod Setup Checklist

**For first-time deployment or fresh start**

---

## Pre-Deployment

- [ ] Docker and Docker Compose installed
- [ ] Project cloned: `~/Projects/Docker-Focused-Wire-Pod/`
- [ ] Network accessible to Vector robot (same LAN)
- [ ] Host machine has static/predictable IP or hostname

---

## Deployment

- [ ] Navigate to project: `cd ~/Projects/Docker-Focused-Wire-Pod`
- [ ] Build image: `./build.sh --prod`
- [ ] Start container (foreground): `docker compose up`
- [ ] Wait for startup messages (~15-30 seconds)
- [ ] Container shows "healthy" status
- [ ] Logs show: "Configuration page: http://{host-ip}:8080"

**Important:** Use `docker compose up` (NOT `-d` flag) during initial setup to see startup progress.

---

## Web UI Setup (Critical for mDNS)

**Access the web UI:**
- ✅ Use the IP address shown in logs (e.g., `http://192.168.1.151:8080`)
- ❌ Do NOT use `escapepod.local` yet (won't resolve until setup is complete)

**In the setup wizard, you will configure:**

1. **Audio/STT Settings**
   - Select speech-to-text service (Vosk recommended)
   - Configure audio input device

2. **Server Configuration**
   - Enable "Escape Pod mode" (required for mDNS)
   - This is the `EPConfig` flag in code
   - **Without this, mDNS registration will NOT start**

3. **Optional: Vector Robot Settings**
   - Add Vector robot credentials (if connecting to Vector)
   - Configure bot-specific settings

4. **Save Configuration**
   - Complete wizard
   - Configuration saves to `/data/chipper/apiConfig.json`

---

## Post-Setup Verification

After web UI setup completes:

- [ ] Container continues running without errors
- [ ] Logs show mDNS registration: `"Running mDNS..."`
- [ ] Test mDNS resolution: `ping escapepod.local`
- [ ] Access web UI via domain: `http://escapepod.local:8080`
- [ ] Health check passes: `curl http://escapepod.local:8080/ok` → returns "ok"

---

## Troubleshooting

### mDNS Still Not Working After Setup

**Check:**
```bash
# Verify container is running
docker compose ps

# Check if mDNS is registered
avahi-browse -a -t | grep -i escapepod

# Check if port 5353 is bound
sudo lsof -i :5353

# View full container logs
docker compose logs wire-pod
```

**Common Issues:**

| Issue | Solution |
|-------|----------|
| `escapepod.local` doesn't resolve | Verify setup was completed; check "Escape Pod mode" is enabled |
| Web UI not accessible at IP | Check `docker compose ps` shows container is healthy; verify firewall |
| "Wire-pod is not setup" message | Complete the web UI wizard at http://{ip}:8080 |
| Container exits after start | Check logs: `docker compose logs wire-pod` |

---

## Next: Connect Vector Robot

Once mDNS is working and web UI accessible via `escapepod.local`:

1. Reset Vector robot to factory settings
2. Power on Vector
3. Vector will discover `escapepod.local` via mDNS
4. Complete Vector onboarding to point to Wire-Pod
5. Vector should connect and authenticate with the server

See Wire-Pod documentation for detailed Vector setup: https://github.com/kercre123/wire-pod/wiki

---

## Rollback

If you need to revert to a previous configuration:

```bash
# Stop current deployment
docker compose down

# Restore previous files
cp ROLLBACK/iteration-{N}/compose.yaml .
cp ROLLBACK/iteration-{N}/Dockerfile.full .
cp ROLLBACK/iteration-{N}/Dockerfile.slim .

# Rebuild and redeploy
./build.sh --prod
docker compose up
```

See `ROLLBACK/iteration-{N}/CHANGES.log` for what changed in each iteration.

---

## Port Reference

| Port | Service | Purpose |
|------|---------|---------|
| 80 | HTTP | Connection check, web redirects |
| 443 | HTTPS | Secure Vector communication |
| 8080 | Web UI | Setup wizard, admin dashboard |
| 8084 | Protocol Buffers | Vector protocol (debug/STT) |

All ports exposed via host network mode after setup.

---

## Configuration Files

After setup, Wire-Pod creates:

```
/data/chipper/
├── apiConfig.json      # Main configuration (created during setup)
├── botConfig.json      # Bot-specific settings
├── customIntents.json  # Custom voice intents
└── [other runtime files]
```

Persist these by keeping the `wire-pod-data` volume mounted.

---

**Need help?** Check DEPLOYMENT_GUIDELINES.md for deployment best practices.
