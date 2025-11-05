# Netdata - Real-time Performance Monitoring

## Executive Summary
Netdata is a real-time performance and health monitoring system for systems and applications. It provides detailed metrics with per-second granularity and sophisticated visualizations.

## Current Status
- **Status**: ✅ Working (with Keycloak SSO)
- **External URL**: https://netdata.ai-servicers.com
- **Internal URL**: http://netdata:19999
- **Containers**: netdata, netdata-auth-proxy
- **Network**: traefik-net
- **Authentication**: Keycloak OAuth2 (administrators group)

## Architecture
- Collects 2000+ metrics per second
- Zero configuration auto-detection
- Real-time visualization
- Stores metrics in time-series database (dbengine)
- Monitors system, containers, and applications

## File Locations
- **Project**: `/home/administrator/projects/netdata/`
- **Data**: `/home/administrator/projects/data/netdata/`
- **Config**: `/home/administrator/projects/netdata/netdata.conf`
- **Secrets**: `$HOME/projects/secrets/netdata.env`
- **Deploy Script**: `/home/administrator/projects/netdata/deploy.sh` (with Keycloak OAuth2)

## Access Methods
- **Web Dashboard**: https://netdata.ai-servicers.com (requires Keycloak login)
- **Internal API**: http://netdata:19999/api/v1/ (from containers)
- **Metrics Export**: http://netdata:19999/api/v1/allmetrics?format=prometheus
- **OAuth2 Endpoints**:
  - Login: https://netdata.ai-servicers.com/oauth2/start
  - Userinfo: https://netdata.ai-servicers.com/oauth2/userinfo

## Common Operations

### Deploy/Update
```bash
cd /home/administrator/projects/netdata && ./deploy.sh
```

### View Logs
```bash
# Netdata service logs
docker logs netdata --tail 50 -f

# OAuth2 proxy logs
docker logs netdata-auth-proxy --tail 50 -f
```

### Get System Metrics
```bash
# From inside containers (use container name)
docker run --rm --network traefik-net curlimages/curl \
  curl "http://netdata:19999/api/v1/data?chart=system.cpu&after=-60&format=json"

# Memory usage
docker run --rm --network traefik-net curlimages/curl \
  curl "http://netdata:19999/api/v1/data?chart=system.ram&after=-60"

# List all charts
docker run --rm --network traefik-net curlimages/curl \
  curl "http://netdata:19999/api/v1/charts"
```

### Restart
```bash
docker restart netdata netdata-auth-proxy
```

## Key Metrics Collected
- **System**: CPU, RAM, disk I/O, network
- **Containers**: Per-container CPU, memory, network
- **Applications**: Database connections, web server requests
- **Disks**: Usage, I/O, latency
- **Network**: Bandwidth, packets, errors

## Troubleshooting

### Issue: 502 Bad Gateway
- Check if both containers are running: `docker ps | grep netdata`
- Verify network alias: `docker inspect netdata | grep -A 5 Aliases`
- Check OAuth2 proxy can reach Netdata: `docker logs netdata-auth-proxy --tail 20`

### Issue: 403 Forbidden
- User not in administrators group in Keycloak
- Clear browser cookies and try again
- Check user info: https://netdata.ai-servicers.com/oauth2/userinfo

### Issue: High CPU usage
- Adjust update frequency in netdata.conf
- Disable unnecessary plugins
- Check for metric collection loops

### Issue: Cannot see container metrics
- Verify Docker socket mount in deployment script
- Check container has proper permissions
- Ensure Netdata is on traefik-net network

## API Examples
```bash
# Get last hour of CPU data (from another container)
docker run --rm --network traefik-net curlimages/curl \
  curl "http://netdata:19999/api/v1/data?chart=system.cpu&after=-3600"

# Get current RAM usage
docker run --rm --network traefik-net curlimages/curl \
  curl "http://netdata:19999/api/v1/data?chart=system.ram&points=1"

# Export metrics in Prometheus format
docker run --rm --network traefik-net curlimages/curl \
  curl "http://netdata:19999/api/v1/allmetrics?format=prometheus"
```

## Integration Points
- **Docker**: Monitors all containers via socket
- **System**: Direct access to /proc and /sys
- **MCP Server**: Will query metrics via API

## Performance Notes
- Uses ~100MB RAM for typical system
- Minimal CPU impact (<2%)
- 1GB disk space for 30 days of metrics

## Authentication Details
- **Provider**: Keycloak OAuth2 via oauth2-proxy
- **Allowed Groups**: administrators
- **Session Duration**: 7 days
- **Client ID**: netdata

## Network Requirements
- **Netdata**: Must be on `traefik-net` network (NOT host network)
- **OAuth2 Proxy**: Must be on `traefik-net` (for web traffic) and `keycloak-net` (for token validation)
- Container alias required for internal name resolution

## Key Configuration Notes
- Original deployment used `--network host` which prevented Traefik routing (502 error)
- OAuth2 proxy MUST be connected to both networks for authentication to work
- Netdata container needs network alias for proxy to reach it by name
- Data directories may have permission issues - deployment script handles gracefully

## Last Updated
- 2025-09-01 14:20 - Initial deployment with host network (had 502 error)
- 2025-09-01 21:53 - Fixed network configuration, added Keycloak OAuth2 authentication
- 2025-09-01 22:16 - Documented network requirements and common issues