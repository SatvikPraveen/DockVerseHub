# Docker Troubleshooting Flowcharts & Decision Trees

**Location: `docs/quick-reference/troubleshooting-flowcharts.md`**

## Container Won't Start Flowchart

```
Container Won't Start?
        |
        ▼
Check container status: docker ps -a
        |
        ▼
┌─────────────────────────┐
│ Exit Code Analysis      │
├─────────────────────────┤
│ 0   - Success          │
│ 1   - General error    │
│ 125 - Docker error     │
│ 126 - Not executable   │
│ 127 - Command not found│
│ 137 - Killed (OOM)     │
│ 143 - Terminated       │
└─────────────────────────┘
        |
        ▼
┌──── Exit Code 125? ────┐
├─ YES ─────┬─── NO ─────┤
│           │            │
▼           ▼            ▼
Check       │         Check logs:
Docker      │         docker logs CONTAINER
daemon:     │            │
docker info │            ▼
│           │      ┌─ Error in logs? ─┐
▼           │      ├─ YES ──┬─ NO ────┤
Restart     │      │        │         │
daemon      │      ▼        ▼         ▼
            │    Fix error Check     Check
            │              Dockerfile resources
            │              │         │
            │              ▼         ▼
            │       ┌─ Valid syntax? ─┐ Memory/CPU OK?
            │       ├─ YES ──┬─ NO ──┤    │
            │       │        │       │    ▼
            │       ▼        ▼       │  Increase limits
            │   Check CMD/  Fix      │  or check host
            │   ENTRYPOINT  syntax   │      │
            │       │               │      ▼
            │       ▼               │   Test again
            │   Executable?         │
            │       │               │
            │   ├─ YES ──┬─ NO ─────┤
            │   │        │          │
            │   ▼        ▼          │
            │ Check PATH Add chmod  │
            │            +x         │
            │            │          │
            └────────────┼──────────┘
                         ▼
                    Test with:
                docker run -it IMAGE sh
```

## Network Connectivity Issues

```
Network Issue?
        |
        ▼
┌─ External connectivity? ─┐
├─ YES ────┬─── NO ────────┤
│          │               │
▼          ▼               ▼
Check      Check DNS       Check Docker
inter-     resolution      daemon config
container  │               │
comm.      ▼               ▼
│       nslookup           docker network ls
▼       google.com         │
docker  │                  ▼
exec C1 ├─ Works ─┬─ Fails ┤ Same network?
ping C2 │         │        │
│       ▼         ▼        ├─ YES ──┬─ NO ──┐
├─ Works│      Try custom  │        │       │
│       │      DNS:        ▼        ▼       ▼
▼       │      --dns 8.8.8.8 Check  Connect Create
Check   │      │         internal  to same shared
ports   │      ▼         network   network network
│       │   DNS fixed?    │        │       │
▼       │      │          ▼        ▼       ▼
docker  │   ├─ YES ─┐  Remove     Test    Test
port C1 │   │       │  internal   again   again
│       │   ▼       │  flag       │       │
▼       │  Done     │  │          ▼       ▼
Check   │           │  ▼       Success?  Success?
firewall│           │ Test      │         │
│       │           │ again     ├─ YES ───┤
▼       │           │  │        │         │
iptables│           │  ▼        ▼         ▼
rules   │           │ Success?  Done     Done
OK?     │           │  │
│       │           │  ├─ YES ─┐
├─ YES ─┤           │  │       │
│       │           │  ▼       ▼
▼       │           │ Done    More
Fix app │           │         issues?
config  │           │
        │           │
        └───────────┘
```

## Build Failure Decision Tree

```
Build Failing?
        |
        ▼
Check error type
        |
        ▼
┌─────────────────────────────────┐
│         Common Errors           │
├─────────────────────────────────┤
│ • Syntax error                 │
│ • Context too large            │
│ • Network timeout              │
│ • Permission denied            │
│ • Package install failed       │
│ • File not found               │
└─────────────────────────────────┘
        |
        ▼
┌─── Syntax Error? ───┐
├─ YES ──┬─── NO ─────┤
│        │            │
▼        ▼            ▼
Fix      │       ┌─ Large Context? ─┐
syntax   │       ├─ YES ──┬─ NO ────┤
│        │       │        │         │
▼        │       ▼        ▼         ▼
Retry    │    Add .dockerignore  ┌─ Network Error? ─┐
build    │    │             │    ├─ YES ─┬─ NO ─────┤
         │    ▼             │    │       │          │
         │  Reduce          │    ▼       ▼          ▼
         │  context         │  Check   │      ┌─ Permission ─┐
         │  │               │  proxy   │      │    Error?    │
         │  ▼               │  │       │      ├─ YES ─┬─ NO ─┤
         │ Retry            │  ▼       │      │       │      │
         │ build            │ Fix      │      ▼       ▼      ▼
         │                  │ network  │   Fix file │    Check
         │                  │ │        │   perms    │    other
         │                  │ ▼        │   │        │    issues
         │                  │Retry     │   ▼        │
         │                  │build     │  Retry     │
         │                  │          │  build     │
         └──────────────────┼──────────┼────────────┘
                            ▼          ▼
                         Success?   Success?
                            │          │
                        ├─ YES ─┐ ├─ YES ─┐
                        │       │ │       │
                        ▼       ▼ ▼       ▼
                       Done    Check    Done
                              cache
                              issues
```

## Performance Issues

```
Performance Issue?
        |
        ▼
┌─────────────────────────┐
│     Symptom Type        │
├─────────────────────────┤
│ • High CPU              │
│ • High Memory           │
│ • Slow I/O              │
│ • Network latency       │
└─────────────────────────┘
        |
        ▼
┌─── High CPU? ───┐
├─ YES ──┬─ NO ───┤
│        │        │
▼        ▼        ▼
Check    │   ┌─ High Memory? ─┐
process  │   ├─ YES ─┬─ NO ───┤
list:    │   │       │        │
docker   │   ▼       ▼        ▼
top C1   │ Check   │     ┌─ Slow I/O? ─┐
│        │ usage:  │     ├─ YES ─┬─ NO ─┤
▼        │ docker  │     │       │      │
Expected?│ stats   │     ▼       ▼      ▼
│        │ │       │  Check    │   Check
├─ YES ──┤ ▼       │  disk     │   network
│        │OOM      │  usage:   │   latency:
▼        │killed?  │  df -h    │   ping test
Scale or │ │       │  │        │   │
optimize ├─ YES ──┬─ NO ─┐    │   ▼
app      │       │      │     │ High latency?
         ▼       ▼      ▼     │ │
      Increase Check  Check   │ ├─ YES ─┬─ NO ──┐
      memory   for    disk    │ │       │       │
      limit    leaks  space   │ ▼       ▼       ▼
      │        │      full?   │Check   Check   Debug
      ▼        │      │       │DNS     network app
   Test again  │  ├─ YES ─┬─ NO ┤      routing
               │  │       │     │
               │  ▼       ▼     │
               │ Clean   Check  │
               │ up      I/O    │
               │ space   wait   │
               │ │       │      │
               │ ▼       ▼      │
               │Retry   Add     │
               │       volume   │
               │       │        │
               └───────┼────────┘
                       ▼
                   Monitor
                   improvements
```

## Storage Issues

```
Storage Issue?
        |
        ▼
┌─────────────────────────┐
│      Issue Type         │
├─────────────────────────┤
│ • Volume not mounting  │
│ • Permission denied    │
│ • Data not persisting  │
│ • Disk space full      │
└─────────────────────────┘
        |
        ▼
┌─ Volume mounting? ─┐
├─ NO ──┬─── YES ────┤
│       │            │
▼       ▼            ▼
Check   │      ┌─ Permissions? ─┐
volume  │      ├─ DENIED ─┬─ OK ─┤
exists: │      │          │      │
docker  │      ▼          ▼      ▼
volume  │   Check file   │   ┌─ Data persisting? ─┐
ls      │   ownership:   │   ├─ NO ──┬─── YES ────┤
│       │   ls -la       │   │       │            │
├─ NO ──┤   │            │   ▼       ▼            ▼
│       │   ▼            │ Check   │        ┌─ Disk full? ─┐
▼       │ Fix ownership: │ volume  │        ├─ YES ─┬─ NO ─┤
Create  │ chown user:    │ type    │        │       │      │
volume  │ group path     │ │       │        ▼       ▼      ▼
│       │ │              │ ▼       │     Clean    │   Check
▼       │ ▼              │Named/   │     up       │   other
Test    │Retry mount     │anon?    │     space    │   issues
mount   │ │              │ │       │     │        │
        │ ▼              │ ├─ ANON ─┤     ▼        │
        │Success?        │ │       │   Add        │
        │ │              │ ▼       │   storage    │
        │ ├─ YES ─┐      │Data     │   │          │
        │ │       │      │lost     │   ▼          │
        │ ▼       ▼      │ │       │  Test        │
        │Done   More     │ ▼       │  again       │
        │      issues?   │Use      │              │
        │               │named     │              │
        │               │volume    │              │
        │               │ │        │              │
        └───────────────┼─┼────────┼──────────────┘
                        ▼ ▼        ▼
                      Test       Success?
                      again        │
                                ├─ YES ─┐
                                │       │
                                ▼       ▼
                               Done    Continue
```

## Service Discovery

```
Service Discovery Issue?
        |
        ▼
Can't reach service by name?
        |
        ▼
┌─ Default bridge network? ─┐
├─ YES ─────┬──── NO ───────┤
│           │               │
▼           ▼               ▼
Default     Check same      Check network
bridge has  custom network  configuration:
no DNS      │               docker network
│           ▼               inspect NET
▼       ┌─ Same network? ─┐ │
Use IP  ├─ YES ─┬─ NO ────┤ ▼
or      │       │         │ DNS issues?
create  ▼       ▼         ▼ │
custom  Check   Connect   ├─ YES ─┬─ NO ──┐
bridge  DNS:    to same   │       │       │
│       docker  network   ▼       ▼       ▼
▼       exec C1 │         Fix    Check   Check
docker  nslookup│         DNS    direct  app
network C2      ▼         config IP      config
create  │    Success?     │      conn.   │
mynet   │       │         │      │       ▼
│    ├─ YES ──┬─ NO ─┐    │      ▼       Fix app
▼    │       │      │     │   Works?    and test
docker▼       ▼      ▼     │      │
run  Check   Try    Debug  │  ├─ YES ─┐
--net ports  diff   further│  │       │
mynet │      DNS           │  ▼       ▼
C1    ▼      │              │ Network DNS
      OK?    ▼              │ OK     issue
      │   Success?          │        │
   ├─ YES ─┐  │             │        ▼
   │       │  ├─ YES ─┐     │     Fix DNS
   ▼       ▼  │       │     │     config
  Done    Fix ▼       ▼     │
          app Done   More   │
          config    issues? │
                           │
          └────────────────┘
```

## Quick Decision Matrix

### Container Issues

| Exit Code | Likely Cause      | First Action          |
| --------- | ----------------- | --------------------- |
| 125       | Docker daemon     | Check `docker info`   |
| 126       | Not executable    | `chmod +x` script     |
| 127       | Command not found | Fix CMD/ENTRYPOINT    |
| 137       | OOM killed        | Increase memory limit |
| 143       | Terminated        | Check stop signals    |

### Network Issues

| Symptom                | Check        | Solution              |
| ---------------------- | ------------ | --------------------- |
| Can't reach external   | DNS config   | Custom DNS servers    |
| Container-to-container | Same network | Custom bridge network |
| Port not accessible    | Port mapping | Correct -p syntax     |
| DNS not working        | Network type | Use custom bridge     |

### Build Issues

| Error Type        | Cause          | Fix               |
| ----------------- | -------------- | ----------------- |
| Syntax error      | Bad Dockerfile | Fix syntax        |
| Context large     | Too many files | Add .dockerignore |
| Network timeout   | Connectivity   | Check proxy/DNS   |
| Permission denied | File ownership | Fix permissions   |

### Performance Issues

| Symptom      | Diagnostic     | Action             |
| ------------ | -------------- | ------------------ |
| High CPU     | `docker top`   | Scale or optimize  |
| High memory  | `docker stats` | Increase limits    |
| Slow I/O     | `df -h`        | Add volume/storage |
| Network slow | `ping` test    | Check DNS/routing  |

## Emergency Commands

### Quick Diagnostics

```bash
# System status
docker info
docker system df
docker system events --since 1h

# Container status
docker ps -a
docker stats --no-stream
docker logs CONTAINER

# Network diagnostics
docker network ls
docker exec CONTAINER ping 8.8.8.8
docker port CONTAINER
```

### Quick Fixes

```bash
# Clean up resources
docker system prune -f

# Restart container
docker restart CONTAINER

# Force remove container
docker rm -f CONTAINER

# Reset network
docker network prune -f

# Emergency stop all
docker stop $(docker ps -q)
```

### Log Analysis

```bash
# Container logs with timestamps
docker logs -t CONTAINER

# Follow logs in real-time
docker logs -f --tail 100 CONTAINER

# System logs (Ubuntu/Debian)
journalctl -u docker --since "1 hour ago"

# Docker daemon logs
tail -f /var/log/docker.log
```

This comprehensive troubleshooting guide provides systematic approaches to diagnose and resolve Docker issues through visual decision trees and practical command references.
