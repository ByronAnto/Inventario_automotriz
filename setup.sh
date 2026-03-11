#!/usr/bin/env bash
###############################################################################
# setup.sh — Script de despliegue automático para AutoPartes Inventory
#
# Detecta la IP pública de la máquina (Oracle Cloud, Azure, AWS, GCP o genérico)
# y configura automáticamente el .env con las URLs correctas.
#
# Uso:
#   chmod +x setup.sh
#   ./setup.sh              # Detecta IP pública automáticamente
#   ./setup.sh 203.0.113.50 # Usa una IP/dominio específico
#   ./setup.sh midominio.com
###############################################################################
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   AutoPartes Inventory — Setup Automático           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ─── 1. Detectar IP pública ──────────────────────────────────────────
detect_public_ip() {
    local ip=""

    # Oracle Cloud Instance Metadata (IMDS v2)
    ip=$(curl -s --connect-timeout 3 -H "Authorization: Bearer Oracle" \
        http://169.254.169.254/opc/v2/vnics/ 2>/dev/null \
        | grep -oP '"publicIp"\s*:\s*"\K[^"]+' | head -1) && [[ -n "$ip" ]] && echo "$ip" && return

    # Oracle Cloud IMDS v1 (fallback)
    ip=$(curl -s --connect-timeout 3 \
        http://169.254.169.254/opc/v1/vnics/ 2>/dev/null \
        | grep -oP '"publicIp"\s*:\s*"\K[^"]+' | head -1) && [[ -n "$ip" ]] && echo "$ip" && return

    # Azure Instance Metadata
    ip=$(curl -s --connect-timeout 3 -H "Metadata:true" \
        "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01&format=text" \
        2>/dev/null) && [[ -n "$ip" && "$ip" != *"error"* ]] && echo "$ip" && return

    # AWS Instance Metadata (IMDSv2)
    local token
    token=$(curl -s --connect-timeout 2 -X PUT \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 30" \
        http://169.254.169.254/latest/api/token 2>/dev/null)
    if [[ -n "$token" ]]; then
        ip=$(curl -s --connect-timeout 2 \
            -H "X-aws-ec2-metadata-token: $token" \
            http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
        [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "$ip" && return
    fi

    # GCP Instance Metadata
    ip=$(curl -s --connect-timeout 3 -H "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" \
        2>/dev/null) && [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "$ip" && return

    # Servicios externos (último recurso)
    for svc in "ifconfig.me" "api.ipify.org" "icanhazip.com" "ipecho.net/plain"; do
        ip=$(curl -s --connect-timeout 5 "$svc" 2>/dev/null | tr -d '[:space:]')
        if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return
        fi
    done

    return 1
}

if [[ $# -ge 1 ]]; then
    PUBLIC_HOST="$1"
    echo -e "${GREEN}✓ Usando host proporcionado:${NC} $PUBLIC_HOST"
else
    echo -e "${YELLOW}⏳ Detectando IP pública automáticamente...${NC}"
    if PUBLIC_HOST=$(detect_public_ip); then
        echo -e "${GREEN}✓ IP pública detectada:${NC} $PUBLIC_HOST"
    else
        echo -e "${RED}✗ No se pudo detectar la IP pública.${NC}"
        echo -e "  Usa: ${CYAN}./setup.sh <IP_O_DOMINIO>${NC}"
        exit 1
    fi
fi

echo ""

# ─── 2. Verificar Docker ─────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    echo -e "${RED}✗ Docker no está instalado. Instálalo primero:${NC}"
    echo "  https://docs.docker.com/engine/install/"
    exit 1
fi

if ! docker compose version &>/dev/null; then
    echo -e "${RED}✗ Docker Compose V2 no está disponible.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker y Docker Compose disponibles${NC}"

# ─── 3. Crear/actualizar .env ─────────────────────────────────────────
ENV_FILE=".env"

if [[ ! -f "$ENV_FILE" ]]; then
    if [[ -f ".env.example" ]]; then
        cp .env.example "$ENV_FILE"
        echo -e "${GREEN}✓ .env creado desde .env.example${NC}"
    else
        echo -e "${RED}✗ No se encontró .env ni .env.example${NC}"
        exit 1
    fi
fi

# Función para actualizar o agregar variable en .env
set_env_var() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

echo -e "${YELLOW}⏳ Actualizando URLs en .env para ${PUBLIC_HOST}...${NC}"

set_env_var "SITE_URL"            "http://${PUBLIC_HOST}:3100"
set_env_var "API_EXTERNAL_URL"    "http://${PUBLIC_HOST}:8000"
set_env_var "SUPABASE_PUBLIC_URL" "http://${PUBLIC_HOST}:8000"
set_env_var "GOTRUE_SITE_URL"     "http://${PUBLIC_HOST}:3100"

echo -e "${GREEN}✓ URLs actualizadas → http://${PUBLIC_HOST}:8000${NC}"

# ─── 4. Verificar puertos del firewall ───────────────────────────────
echo ""
echo -e "${YELLOW}📋 Puertos necesarios (abrir en firewall/Security List):${NC}"
echo -e "   ${CYAN}8000${NC}  — API Gateway (Kong) — Backend"
echo -e "   ${CYAN}3001${NC}  — Frontend Web (Nginx/Flutter)"
echo -e "   ${CYAN}3100${NC}  — Studio (panel admin DB) — opcional"
echo ""

# Verificar si los puertos están abiertos localmente
for port in 8000 3001; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} " || \
       netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
        echo -e "   ${YELLOW}⚠ Puerto ${port} ya está en uso${NC}"
    fi
done

# ─── 5. Construir y levantar todos los servicios ─────────────────────
echo ""
echo -e "${YELLOW}⏳ Construyendo imagen del frontend web...${NC}"
echo -e "   (esto puede tomar 2-5 minutos la primera vez)"
echo ""

docker compose build web-app

echo ""
echo -e "${YELLOW}⏳ Levantando todos los servicios...${NC}"

docker compose up -d

echo ""
echo -e "${YELLOW}⏳ Esperando que los servicios estén saludables...${NC}"
sleep 10

# ─── 6. Verificar servicios ──────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Estado de los servicios${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"

docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

echo ""

# Test de conectividad
API_OK=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8000/rest/v1/" -H "apikey: $(grep '^ANON_KEY=' .env | cut -d= -f2)" 2>/dev/null || echo "000")
WEB_OK=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${WEB_PORT:-3001}" 2>/dev/null || echo "000")

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Tests de conectividad${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"

if [[ "$API_OK" == "200" || "$API_OK" == "401" ]]; then
    echo -e "   ${GREEN}✓ API Backend (Kong):  OK${NC}"
else
    echo -e "   ${RED}✗ API Backend (Kong):  FALLO (HTTP $API_OK)${NC}"
fi

if [[ "$WEB_OK" == "200" ]]; then
    echo -e "   ${GREEN}✓ Frontend Web:        OK${NC}"
else
    echo -e "   ${RED}✗ Frontend Web:        FALLO (HTTP $WEB_OK)${NC}"
fi

# ─── 7. Resumen final ────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Despliegue completado                          ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  🌐 Frontend Web:  ${CYAN}http://${PUBLIC_HOST}:3001${NC}"
echo -e "${GREEN}║${NC}  🔌 API Backend:   ${CYAN}http://${PUBLIC_HOST}:8000${NC}"
echo -e "${GREEN}║${NC}  📊 Studio:        ${CYAN}http://${PUBLIC_HOST}:3100${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  👤 Admin:  admin@autopartes.com / Admin2026!         ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}                                                      ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}💡 Recuerda abrir los puertos 8000 y 3001 en:${NC}"
echo -e "   Oracle Cloud → Networking → VCN → Security Lists → Ingress Rules"
echo -e "   Azure → NSG → Inbound security rules"
echo ""
