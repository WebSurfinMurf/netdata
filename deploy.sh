#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Netdata Deployment with Keycloak OAuth2 ===${NC}"

# Load secrets
source $HOME/projects/secrets/netdata.env

# Verify CLIENT_SECRET is set
if [ -z "$OAUTH2_PROXY_CLIENT_SECRET" ]; then
    echo -e "${RED}Please update CLIENT_SECRET in $HOME/projects/secrets/netdata.env${NC}"
    exit 1
fi

# Stop existing containers
echo -e "${YELLOW}Stopping existing containers...${NC}"
docker stop netdata 2>/dev/null || true
docker rm netdata 2>/dev/null || true
docker stop netdata-auth-proxy 2>/dev/null || true
docker rm netdata-auth-proxy 2>/dev/null || true

# Create data directory and networks
mkdir -p /home/administrator/projects/data/netdata 2>/dev/null || true
docker network create netdata-net 2>/dev/null || echo "Network netdata-net already exists"

# Deploy Netdata (on netdata-net, NOT on traefik-net)
echo -e "${YELLOW}Deploying Netdata container...${NC}"
docker run -d \
  --name netdata \
  --init \
  --restart unless-stopped \
  --network netdata-net \
  --network-alias netdata \
  --cap-add SYS_PTRACE \
  --security-opt apparmor=unconfined \
  -p 127.0.0.1:19999:19999 \
  -v /home/administrator/projects/data/netdata/cache:/var/cache/netdata \
  -v /home/administrator/projects/data/netdata/lib:/var/lib/netdata \
  -v /etc/passwd:/host/etc/passwd:ro \
  -v /etc/group:/host/etc/group:ro \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /etc/os-release:/host/etc/os-release:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -e NETDATA_CLAIM_TOKEN="" \
  -e NETDATA_CLAIM_URL="" \
  -e NETDATA_CLAIM_ROOMS="" \
  -e DOCKER_HOST=unix:///var/run/docker.sock \
  -e PGID=999 \
  netdata/netdata:stable

# Deploy OAuth2 Proxy (WITH Traefik labels)
echo -e "${YELLOW}Deploying OAuth2 Proxy...${NC}"
docker run -d \
  --name netdata-auth-proxy \
  --restart unless-stopped \
  --network traefik-net \
  --env-file $HOME/projects/secrets/netdata.env \
  --label "traefik.enable=true" \
  --label "traefik.http.routers.netdata.rule=Host(\`netdata.ai-servicers.com\`)" \
  --label "traefik.http.routers.netdata.entrypoints=websecure" \
  --label "traefik.http.routers.netdata.tls=true" \
  --label "traefik.http.routers.netdata.tls.certresolver=letsencrypt" \
  --label "traefik.http.services.netdata.loadbalancer.server.port=4180" \
  quay.io/oauth2-proxy/oauth2-proxy:latest

# Connect OAuth2 proxy to additional networks
echo -e "${YELLOW}Connecting OAuth2 proxy to additional networks...${NC}"
docker network connect keycloak-net netdata-auth-proxy 2>/dev/null || true
docker network connect netdata-net netdata-auth-proxy 2>/dev/null || true

# Wait for services to start
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 5

# Check container status
echo -e "${YELLOW}Checking container status...${NC}"
if docker ps | grep -q "netdata" && docker ps | grep -q "netdata-auth-proxy"; then
    echo -e "${GREEN}✓ Both containers are running${NC}"
else
    echo -e "${RED}✗ One or more containers failed to start${NC}"
    docker ps -a | grep -E "netdata|netdata-auth-proxy"
    echo -e "${YELLOW}Checking logs...${NC}"
    docker logs netdata --tail 10 2>&1
    docker logs netdata-auth-proxy --tail 10 2>&1
    exit 1
fi

echo -e "${GREEN}✓ Deployment complete${NC}"
echo ""
echo -e "${GREEN}Access Netdata at: https://netdata.ai-servicers.com${NC}"
echo -e "${YELLOW}Note: You'll need to authenticate with Keycloak (administrators group)${NC}"
echo ""
echo -e "To check logs:"
echo -e "  docker logs netdata-auth-proxy --tail 20"
echo -e "  docker logs netdata --tail 20"