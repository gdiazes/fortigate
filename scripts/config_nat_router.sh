#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE CONFIGURACIÓN DE NAT Y ENRUTAMIENTO EN LINUX ROUTER
# Topología: img/nat.png
# IP WAN (Internet): 10.160.10.114 (eth0)
#
# Mapeo de Puertos:
# - Local-FortiGate (10.200.1.1 vía eth1):
#     * HTTPS GUI:  WAN 6565 -> 10.200.1.1:443
#     * SSH CLI:    WAN 2221 (o 6522) -> 10.200.1.1:22
# - Remote-FortiGate (10.200.3.1 vía eth3):
#     * HTTPS GUI:  WAN 6666 -> 10.200.3.1:443
#     * SSH CLI:    WAN 2222 (o 6622) -> 10.200.3.1:22
# ==============================================================================

set -e

echo "=================================================================="
echo "🛡️  INICIANDO CONFIGURACIÓN DE NAT (HTTPS + SSH) EN LINUX ROUTER"
echo "=================================================================="

# ------------------------------------------------------------------------------
# FASE 0: BACKUP PREVENTIVO AUTOMÁTICO
# ------------------------------------------------------------------------------
echo "=== [0/6] Generando Backup Preventivo de la Configuración Actual ==="
BACKUP_DIR="/root/backup_iptables"
mkdir -p "$BACKUP_DIR"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/iptables_pre_nat_${TIMESTAMP}.rules"
LATEST_BACKUP="${BACKUP_DIR}/iptables_latest_backup.rules"

iptables-save > "$BACKUP_FILE"
cp "$BACKUP_FILE" "$LATEST_BACKUP"

echo "✅ Backup guardado con éxito en:"
echo "   - $BACKUP_FILE"
echo "   - $LATEST_BACKUP"
echo "   (Para hacer rollback en cualquier momento ejecuta: iptables-restore < $LATEST_BACKUP)"
echo ""

# ------------------------------------------------------------------------------
# FASE 1: IP FORWARDING
# ------------------------------------------------------------------------------
echo "=== [1/6] Habilitando IP Forwarding en el Kernel ==="
sysctl -w net.ipv4.ip_forward=1
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# ------------------------------------------------------------------------------
# FASE 2: VARIABLES DE RED
# ------------------------------------------------------------------------------
echo "=== [2/6] Definiendo Variables de Red ==="
WAN_IF="eth0"
WAN_IP="10.160.10.114"

LOCAL_FGT_IP="10.200.1.1"
LOCAL_FGT_HTTPS_PORT="6565"
LOCAL_FGT_SSH_PORT="2221"
LOCAL_FGT_SSH_ALT="6522"

REMOTE_FGT_IP="10.200.3.1"
REMOTE_FGT_HTTPS_PORT="6666"
REMOTE_FGT_SSH_PORT="2222"
REMOTE_FGT_SSH_ALT="6622"

FGT_HTTPS="443"
FGT_SSH="22"

# ------------------------------------------------------------------------------
# FASE 3: REGLAS DNAT (PORT FORWARDING HTTPS + SSH)
# ------------------------------------------------------------------------------
echo "=== [3/6] Aplicando Reglas de Port Forwarding (DNAT en PREROUTING) ==="

# --- HTTPS (Web GUI) ---
iptables -t nat -A PREROUTING -p tcp -d "$WAN_IP" --dport "$LOCAL_FGT_HTTPS_PORT" -j DNAT --to-destination "$LOCAL_FGT_IP:$FGT_HTTPS"
iptables -t nat -A PREROUTING -p tcp -d "$WAN_IP" --dport "$REMOTE_FGT_HTTPS_PORT" -j DNAT --to-destination "$REMOTE_FGT_IP:$FGT_HTTPS"

# --- SSH (CLI Management) ---
# Local-FortiGate SSH (puertos 2221 y 6522)
iptables -t nat -A PREROUTING -p tcp -d "$WAN_IP" --dport "$LOCAL_FGT_SSH_PORT" -j DNAT --to-destination "$LOCAL_FGT_IP:$FGT_SSH"
iptables -t nat -A PREROUTING -p tcp -d "$WAN_IP" --dport "$LOCAL_FGT_SSH_ALT" -j DNAT --to-destination "$LOCAL_FGT_IP:$FGT_SSH"

# Remote-FortiGate SSH (puertos 2222 y 6622)
iptables -t nat -A PREROUTING -p tcp -d "$WAN_IP" --dport "$REMOTE_FGT_SSH_PORT" -j DNAT --to-destination "$REMOTE_FGT_IP:$FGT_SSH"
iptables -t nat -A PREROUTING -p tcp -d "$WAN_IP" --dport "$REMOTE_FGT_SSH_ALT" -j DNAT --to-destination "$REMOTE_FGT_IP:$FGT_SSH"

# ------------------------------------------------------------------------------
# FASE 4: FILTRADO FORWARD
# ------------------------------------------------------------------------------
echo "=== [4/6] Permitiendo Tráfico en la Cadena FORWARD ==="
# Tráfico hacia Local-FortiGate (HTTPS 443 y SSH 22)
iptables -A FORWARD -p tcp -d "$LOCAL_FGT_IP" --dport "$FGT_HTTPS" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p tcp -d "$LOCAL_FGT_IP" --dport "$FGT_SSH" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Tráfico hacia Remote-FortiGate (HTTPS 443 y SSH 22)
iptables -A FORWARD -p tcp -d "$REMOTE_FGT_IP" --dport "$FGT_HTTPS" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p tcp -d "$REMOTE_FGT_IP" --dport "$FGT_SSH" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# ------------------------------------------------------------------------------
# FASE 5: MASQUERADE / SNAT
# ------------------------------------------------------------------------------
echo "=== [5/6] Aplicando Masquerade / SNAT (Garantiza respuesta bidireccional) ==="
# SNAT hacia Local-FortiGate
iptables -t nat -A POSTROUTING -o eth1 -d "$LOCAL_FGT_IP" -p tcp --dport "$FGT_HTTPS" -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth1 -d "$LOCAL_FGT_IP" -p tcp --dport "$FGT_SSH" -j MASQUERADE

# SNAT hacia Remote-FortiGate
iptables -t nat -A POSTROUTING -o eth3 -d "$REMOTE_FGT_IP" -p tcp --dport "$FGT_HTTPS" -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth3 -d "$REMOTE_FGT_IP" -p tcp --dport "$FGT_SSH" -j MASQUERADE

# Enmascaramiento general de salida hacia Internet para los laboratorios
iptables -t nat -A POSTROUTING -o "$WAN_IF" -j MASQUERADE

# ------------------------------------------------------------------------------
# FASE 6: PERSISTENCIA
# ------------------------------------------------------------------------------
echo "=== [6/6] Guardando Reglas para Persistencia ==="
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save
elif command -v iptables-save >/dev/null 2>&1; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
fi

echo ""
echo "=================================================================="
echo "🎉 CONFIGURACIÓN (HTTPS + SSH) APLICADA EXITOSAMENTE"
echo "=================================================================="
echo "🌐 Acceso Web (HTTPS):"
echo "   👉 Local-FortiGate:  https://${WAN_IP}:${LOCAL_FGT_HTTPS_PORT}"
echo "   👉 Remote-FortiGate: https://${WAN_IP}:${REMOTE_FGT_HTTPS_PORT}"
echo ""
echo "💻 Acceso Consola (SSH CLI):"
echo "   👉 Local-FortiGate:  ssh admin@${WAN_IP} -p ${LOCAL_FGT_SSH_PORT}  (o puerto ${LOCAL_FGT_SSH_ALT})"
echo "   👉 Remote-FortiGate: ssh admin@${WAN_IP} -p ${REMOTE_FGT_SSH_PORT}  (o puerto ${REMOTE_FGT_SSH_ALT})"
echo ""
echo "En caso de emergencia para restaurar la configuración anterior:"
echo "   👉 iptables-restore < ${LATEST_BACKUP}"
echo "=================================================================="
