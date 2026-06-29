# Deployment Guidelines & Accountability Framework

**Established:** 2026-06-28  
**Scope:** Docker deployment projects only  
**Approver:** nahin.m@gmail.com

---

## Mandatory Workflow

### Before Implementation
- ☐ Show specification (what/where/why/risk)
- ☐ List files that will change
- ☐ Define success criteria
- ☐ Get explicit approval

### During Implementation
- ☐ Show code changes (diffs)
- ☐ Explain each change
- ☐ Ask for approval before testing

### Testing & Verification
- ☐ Actually test locally (not just claims)
- ☐ Show real output/evidence
- ☐ Use provided test commands
- ☐ Include environment reset steps:
  ```bash
  cd ~/Projects/Docker-Focused-Wire-Pod
  docker compose down
  # [full test here]
  docker compose up -d
  docker compose logs --tail 20
  ```
- ☐ Create rollback of changed files
- ☐ Document test results with dates/times

### After Verification
- ☐ Get final approval
- ☐ Document what was tested
- ☐ Note any issues found

---

## File Change Management

### No Destructive Deletion
Changes are backed up to: `./ROLLBACK/iteration-{N}/`

Example structure:
```
ROLLBACK/
├── iteration-1/
│   ├── docker-entrypoint.sh (backup of original)
│   ├── compose.yaml (backup of original)
│   └── CHANGES.log
├── iteration-2/
│   ├── ... (next iteration backups)
│   └── CHANGES.log
└── CURRENT.txt (points to latest iteration)
```

### Rollback Process (30min max)
1. Identify which iteration to revert to
2. Copy files from ROLLBACK/iteration-{N}/ back to their locations
3. Rebuild: `./build.sh --prod`
4. Restart: `docker compose up -d`
5. Verify: `docker compose ps`

---

## Test Command Template

Every test I ask you to run will follow this pattern:

```bash
# Step 1: Navigate to project
cd ~/Projects/Docker-Focused-Wire-Pod

# Step 2: Stop current container
docker compose down

# Step 3: Clean up (optional)
docker system prune -f

# Step 4: Backup current files (automatic - goes to ROLLBACK/iteration-{N}/)
# [I will do this before changes]

# Step 5: Build new image
./build.sh --prod

# Step 6: Deploy (FOREGROUND - no -d flag)
# This shows logs in real-time without extra commands
docker compose up

# EXPECTED OUTPUT:
# [Real-time log stream showing initialization]
# [Full chipper startup sequence visible]

# ROLLBACK IF NEEDED:
# Ctrl+C to stop container
# cp ROLLBACK/iteration-{N}/* .
# ./build.sh --prod
# docker compose up
```

### Testing Phase Behavior

**During testing phase:**
- ✓ Use `docker compose up` (foreground, NOT `-d`)
- ✓ You see logs in real-time as they happen
- ✓ I handle any background verification needed
- ✓ More efficient - no extra log commands required
- ✓ Easier troubleshooting - see all output at once

**Why:** Foreground mode shows full initialization sequence, clearer for identifying issues, reduces context switching

---

## Scope Boundaries (Locked)

**I CAN modify:**
- Dockerfile.full
- Dockerfile.slim
- compose.yaml
- .dockerignore
- docker/entrypoint.sh
- docker/default-source.sh
- build.sh
- scan.sh
- Documentation files in project root

**I CANNOT modify:**
- chipper/ (source code)
- vector-cloud/ (source code)
- Any .go, .py, .js source files
- README.md (belongs to source project)
- setup.sh (original developer's script)
- update.sh (original developer's script)

**I CAN read (for research/context only):**
- Any source code files (chipper/, vector-cloud/, etc.)
- To understand how the application works
- To inform Docker deployment decisions
- To verify if changes might affect the app
- **Cannot modify - reading only for context**

**If I try to modify out-of-scope files: STOP ME immediately**

---

## Failure Modes & Recovery

| Issue | Action |
|-------|--------|
| Build fails | Show error, propose fix, get approval |
| Container won't start | Revert to ROLLBACK/iteration-{N-1}/ |
| Tests show wrong output | Go back to implementation phase |
| 30min rollback exceeded | Stop, revert, document what went wrong |
| Changed wrong file | Restore from ROLLBACK, apologize |

---

## Compliance Checklist (Self-Check)

Before claiming "done", I verify:

- [ ] Specification was reviewed and approved
- [ ] Code changes shown and approved
- [ ] Actually tested (not just claimed)
- [ ] Real output shown (pasted, not described)
- [ ] Files backed up to ROLLBACK/iteration-{N}/
- [ ] Rollback documented and tested
- [ ] Only Docker files modified
- [ ] No source code touched
- [ ] Test commands included full reset steps
- [ ] Evidence provided (not claims)

**If any checkbox is unchecked, I say "Not done yet" and fix it.**

---

## Escalation

If I violate these guidelines:
1. **First violation:** Acknowledge, explain, revert
2. **Second violation:** Acknowledge, explain, revert, propose new guidelines
3. **Third violation:** Suggest role review or new operational model

---

## Version History

| Date | Change | Reason |
|------|--------|--------|
| 2026-06-28 | Initial framework | Ensure accountability & quality |

---

## Context Window Management (Automatic)

**At 80% context window full:**
1. Save/append to SESSION_SUMMARY.md
2. Mark compaction with timestamp
3. Summarize work completed
4. Continue conversation in fresh context

**Format:** `[COMPACTION: YYYY-MM-DDTHH:MM:SSUTC] - Brief summary - Action taken`

**Benefit:** Prevents token limits from interrupting work, maintains session history

---

## Initial Setup Requirement (Critical for mDNS)

**IMPORTANT:** Wire-Pod requires initial setup before mDNS (escapepod.local) becomes active.

**Why:** mDNS registration is gated behind setup completion for security/stability reasons (code: startserver.go line 142).

**Setup Process:**
1. Deploy container: `docker compose up`
2. Access web UI at: `http://{host-ip}:8080` (or `http://escapepod.local:8080` after setup)
3. Complete initial configuration wizard
4. Once setup is done, mDNS registration automatically starts
5. `ping escapepod.local` will then work

**First Access:** Use the host's IP address (shown in logs: "Configuration page: http://192.168.1.151:8080")

**Timeline:**
- T+0: Container starts → web UI available at IP only
- T+setup: User completes wizard → mDNS registration begins
- T+mDNS: `escapepod.local` becomes resolvable on the network

---

**Signed commitment:** These guidelines are non-negotiable for Docker deployment work in this project.
