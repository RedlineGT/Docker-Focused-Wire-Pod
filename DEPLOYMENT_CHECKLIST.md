# Wire-Pod Docker Deployment Checklist

Use this checklist before deploying Wire-Pod to production or to a new environment.

## Pre-Deployment

- [ ] **Review changes**
  - [ ] Read `DOCKER_IMPROVEMENTS.md`
  - [ ] Understand differences between `Dockerfile.full` (prod) and `Dockerfile.slim` (debug)
  - [ ] Review updated `compose.yaml`

- [ ] **Local testing**
  - [ ] Build production image: `./build.sh --prod`
  - [ ] Verify image size: `docker images | grep wire-pod`
  - [ ] Run with compose: `docker compose up -d`
  - [ ] Test web UI: `curl http://localhost:8080`
  - [ ] Check logs: `docker compose logs -f`
  - [ ] Stop and verify persistence: `docker compose down && docker compose up -d`

- [ ] **Security validation**
  - [ ] Scan for vulnerabilities: `./scan.sh ghcr.io/kercre123/wire-pod:latest --severity HIGH,CRITICAL`
  - [ ] Review SBOM: `./build.sh --prod --sbom` (generates `wire-pod-prod-sbom.json`)
  - [ ] Check if HIGH/CRITICAL vulnerabilities are acceptable/patchable

## Deployment Options

### Option 1: Local Docker (Single Host)

- [ ] **Environment setup**
  - [ ] Verify Docker is installed: `docker --version`
  - [ ] Verify Docker Compose: `docker compose version`
  - [ ] Create persistent data directory: `mkdir -p ./data`

- [ ] **Configuration**
  - [ ] Update `compose.yaml` image tag if using custom registry
  - [ ] Adjust resource limits (`memory`, `cpus`) based on host
  - [ ] Verify port mappings (80, 443, 8080, 8084)

- [ ] **Deployment**
  - [ ] Run: `docker compose up -d`
  - [ ] Wait 30 seconds for startup
  - [ ] Check health: `docker compose ps` (should show "healthy")
  - [ ] Access web UI: `http://your-ip:8080`

- [ ] **Post-deployment**
  - [ ] Verify data persistence: `ls -la ./data/`
  - [ ] Check logs: `docker compose logs`
  - [ ] Configure Vector robot to connect to host

### Option 2: Docker Swarm (Multiple Hosts)

- [ ] **Prerequisites**
  - [ ] Initialize Swarm: `docker swarm init`
  - [ ] Add worker nodes if needed
  - [ ] Create shared storage (NFS, etc.)

- [ ] **Deployment**
  - [ ] Convert compose.yaml to stack: `docker stack deploy -c compose.yaml wire-pod`
  - [ ] Verify: `docker stack ps wire-pod`
  - [ ] Monitor: `docker service logs wire-pod_wire-pod`

### Option 3: Kubernetes (Production)

- [ ] **Prerequisites**
  - [ ] Kubernetes cluster running
  - [ ] `kubectl` configured
  - [ ] Persistent Volume provisioned

- [ ] **Deployment**
  - [ ] Convert compose to K8s manifest (use `kompose` or manual)
  - [ ] Create namespace: `kubectl create namespace wire-pod`
  - [ ] Deploy: `kubectl apply -f k8s-manifest.yaml`
  - [ ] Verify: `kubectl get pods -n wire-pod`

---

## Security Checklist

- [ ] **Access Control**
  - [ ] Verify root user limitation: `docker inspect wire-pod | grep User`
  - [ ] Check capability drops: `docker inspect wire-pod | grep CapDrop`
  - [ ] Review network policies if using Kubernetes

- [ ] **Secrets Management**
  - [ ] Verify `.env` is NOT in image: `docker run -rm wire-pod:latest ls .env` (should not exist)
  - [ ] Verify API keys are passed via environment, not config files
  - [ ] Check data volume permissions: `ls -la ./data/`

- [ ] **Scanning**
  - [ ] Run vulnerability scan before production
  - [ ] Review SBOM for problematic licenses
  - [ ] Set up automated scanning (GitHub Actions, Dependabot, etc.)

---

## Performance Validation

- [ ] **Size comparison**
  - [ ] Alpine (prod): ~180MB
  - [ ] Ubuntu (debug): ~630MB
  - [ ] Verify your build: `docker images | grep wire-pod`

- [ ] **Startup time**
  - [ ] Measure cold start: `time docker compose up -d`
  - [ ] Expected: 5-15 seconds to "healthy"
  - [ ] Check health: `docker compose ps`

- [ ] **Resource usage**
  - [ ] Monitor memory: `docker stats wire-pod`
  - [ ] Expected: 200-500MB RAM
  - [ ] Monitor CPU: Should be low when idle

- [ ] **Network connectivity**
  - [ ] Web UI accessible: `curl http://localhost:8080`
  - [ ] mDNS working: `avahi-browse -a | grep escapepod`
  - [ ] Vector robot can connect

---

## Monitoring & Maintenance

- [ ] **Logging setup**
  - [ ] Verify logs are JSON-formatted: `docker compose logs --tail 10 | grep -o '{.*}' | head -1`
  - [ ] Configure log rotation (compose.yaml has max-size and max-file)
  - [ ] Set up log aggregation if needed (ELK, Splunk, etc.)

- [ ] **Health checks**
  - [ ] Web UI health endpoint: `curl http://localhost:8080/ok`
  - [ ] Expected response: HTTP 200 OK
  - [ ] Automatic restart on unhealthy: Enabled in compose.yaml

- [ ] **Scheduled tasks**
  - [ ] Monthly: Run vulnerability scan
  - [ ] Monthly: Update base image (`--pull --no-cache`)
  - [ ] Quarterly: Review SBOM and security reports

- [ ] **Backup & Recovery**
  - [ ] Data volume backup: `docker cp wire-pod:/data ./backup-$(date +%Y%m%d)`
  - [ ] Test recovery: Restore to clean host
  - [ ] Document recovery procedure

---

## Troubleshooting Guide

### Container Won't Start

**Check logs first:**
```bash
docker compose logs --tail 50
```

**Common issues:**

1. **Audio device not available**
   - Check: `docker exec wire-pod ls -la /dev/snd/`
   - Fix: Add device volumes to compose.yaml
   - ```yaml
     devices:
       - /dev/snd:/dev/snd
     ```

2. **Port already in use**
   - Check: `sudo lsof -i :80`
   - Fix: Change port in compose.yaml or stop conflicting service

3. **Insufficient memory**
   - Check: `free -h`
   - Fix: Increase swap or reduce other services
   - Reduce compose.yaml memory limit if needed

4. **Permission denied on volume**
   - Check: `ls -la ./data/`
   - Fix: `sudo chown $USER:$USER ./data` or adjust volume permissions

### Container Crashes/Restarts

**Check restart policy:**
```bash
docker compose ps  # Look for "(restarting)" status
```

**Enable debug logging:**
```yaml
environment:
  WIREPOD_DEBUG_LOGGING: "true"
```

**Then check detailed logs:**
```bash
docker compose logs -f wire-pod
```

### Web UI Not Responding

**Test connectivity:**
```bash
curl -v http://localhost:8080
docker compose exec wire-pod curl -v http://localhost:8080
```

**Check if service is running:**
```bash
docker compose ps
docker compose exec wire-pod ps aux | grep chipper
```

### Poor Performance

**Check resource usage:**
```bash
docker stats wire-pod
```

**If CPU high:**
- Check for excessive logging
- Review STT service (may be slow)
- Check network connectivity

**If memory high:**
- Increase compose.yaml memory limit
- Check for memory leaks in logs
- Reduce number of plugins if using many

---

## Rollback Procedure

If new version has issues:

```bash
# Stop current version
docker compose down

# Restore old data if backed up
docker cp ./backup-20240101/data/. wire-pod:/data

# Use old Dockerfile
docker build -f dockerfile -t wire-pod:old .
docker compose up -d
```

---

## Documentation

- **DOCKER_IMPROVEMENTS.md** – Detailed explanation of all changes
- **DOCKER_ANALYSIS.md** – Original analysis and findings
- **README.md** – Installation and usage instructions
- **GitHub Wiki** – Feature documentation and troubleshooting

---

## Support Resources

- **GitHub Issues:** https://github.com/kercre123/wire-pod/issues
- **GitHub Discussions:** https://github.com/kercre123/wire-pod/discussions
- **Community Discord:** [Link if available]
- **Security Vulnerabilities:** See README for responsible disclosure

---

## Sign-Off

- [ ] **Deployment owner:** __________________
- [ ] **Date:** __________________
- [ ] **Environment:** ☐ Local  ☐ Staging  ☐ Production
- [ ] **Notes/Issues:**
  ```
  
  
  ```

---

## Post-Deployment Validation (24 hours)

- [ ] Web UI stable and responsive
- [ ] Vector robot connected and functioning
- [ ] No errors in logs
- [ ] Health checks passing
- [ ] Data persisting across restarts
- [ ] No high CPU/memory usage

**If all checks pass:** ✓ Deployment successful!

**If issues found:** Refer to troubleshooting section above
