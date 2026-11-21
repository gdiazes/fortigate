#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE CONFIGURACIÓN DE NAT Y ENRUTAMIENTO EN LINUX ROUTER
# Topología: img/nat.png
# IP WAN (Internet): 10.160.10.114 (eth0)
# Local-FortiGate:   10.200.1.1 (vía eth1: 10.200.1.254) -> Puerto 6565
# Remote-FortiGate:  10.200.3.1 (vía eth3: 10.200.3.254) -> Puerto 6666
# ==============================================================================

set -e

echo "=================================================================="
echo "🛡️  INICIANDO CONFIGURACIÓN DE NAT EN LINUX ROUTER"
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
LOCAL_FGT_PORT_EXT="6565"

REMOTE_FGT_IP="10.200.3.1"
REMOTE_FGT_PORT_EXT="6666"

FGT_MGMT_PORT="443" # Puerto HTTPS por defecto de FortiOS

# ------------------------------------------------------------------------------
# FASE 3: REGLAS DNAT (PORT FORWARDING)
# ------------------------------------------------------------------------------
echo "=== [3/6] Aplicando Reglas de Port Forwarding (DNAT en PREROUTING) ==="
# Acceso a Local-FortiGate (Puerto 6565 -> 10.200.1.1:443)
iptables -t nat -A PREROUTING -p tcp -d "$WAN_IP" --dport "$LOCAL_FGT_PORT_EXT" -j DNAT --to-destination "$LOCAL_FGT_IP:$FGT_MGMT_PORT"

# Acceso a Remote-FortiGate (Puerto 6666 -> 10.200.3.1:443)
iptables -t nat -A PREROUTING -p tcp -d "$WAN_IP" --dport "$REMOTE_FGT_PORT_EXT" -j DNAT --to-destination "$REMOTE_FGT_IP:$FGT_MGMT_PORT"

# ------------------------------------------------------------------------------
# FASE 4: FILTRADO FORWARD
# ------------------------------------------------------------------------------
echo "=== [4/6] Permitiendo Tráfico en la Cadena FORWARD ==="
iptables -A FORWARD -p tcp -d "$LOCAL_FGT_IP" --dport "$FGT_MGMT_PORT" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p tcp -d "$REMOTE_FGT_IP" --dport "$FGT_MGMT_PORT" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# ------------------------------------------------------------------------------
# FASE 5: MASQUERADE / SNAT
# ------------------------------------------------------------------------------
echo "=== [5/6] Aplicando Masquerade / SNAT (Garantiza respuesta bidireccional) ==="
# SNAT hacia los FortiGate para garantizar que respondan al Linux Router
iptables -t nat -A POSTROUTING -o eth1 -d "$LOCAL_FGT_IP" -p tcp --dport "$FGT_MGMT_PORT" -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth3 -d "$REMOTE_FGT_IP" -p tcp --dport "$FGT_MGMT_PORT" -j MASQUERADE

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
echo "🎉 CONFIGURACIÓN APLICADA EXITOSAMENTE"
echo "=================================================================="
echo "Acceso Web a FortiGates:"
echo "👉 Local-FortiGate:  https://${WAN_IP}:${LOCAL_FGT_PORT_EXT}"
echo "👉 Remote-FortiGate: https://${WAN_IP}:${REMOTE_FGT_PORT_EXT}"
echo ""
echo "En caso de emergencia para restaurar la configuración anterior:"
echo "👉 iptables-restore < ${LATEST_BACKUP}"
echo "=================================================================="
