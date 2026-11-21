#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE CONFIGURACIÓN DE NAT Y ENRUTAMIENTO EN LINUX ROUTER
# Topología: img/nat.png
# IP WAN (Internet): 10.160.10.114 (eth0)
# Local-FortiGate:   10.200.1.1 (vía eth1: 10.200.1.254) -> Puerto 6565
# Remote-FortiGate:  10.200.3.1 (vía eth3: 10.200.3.254) -> Puerto 6666
# ==============================================================================

set -e

echo "=== 1. Habilitando IP Forwarding en el Kernel ==="
sysctl -w net.ipv4.ip_forward=1
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

echo "=== 2. Definiendo Variables de Red ==="
WAN_IF="eth0"
WAN_IP="10.160.10.114"

LOCAL_FGT_IP="10.200.1.1"
LOCAL_FGT_PORT_EXT="6565"

REMOTE_FGT_IP="10.200.3.1"
REMOTE_FGT_PORT_EXT="6666"

FGT_MGMT_PORT="443" # Puerto HTTPS por defecto de FortiOS

echo "=== 3. Aplicando Reglas de Port Forwarding (DNAT en PREROUTING) ==="
# Acceso a Local-FortiGate (Puerto 6565 -> 10.200.1.1:443)
iptables -t nat -A PREROUTING -p tcp -d "$WAN_IP" --dport "$LOCAL_FGT_PORT_EXT" -j DNAT --to-destination "$LOCAL_FGT_IP:$FGT_MGMT_PORT"

# Acceso a Remote-FortiGate (Puerto 6666 -> 10.200.3.1:443)
iptables -t nat -A PREROUTING -p tcp -d "$WAN_IP" --dport "$REMOTE_FGT_PORT_EXT" -j DNAT --to-destination "$REMOTE_FGT_IP:$FGT_MGMT_PORT"

echo "=== 4. Permitiendo Tráfico en la Cadena FORWARD ==="
iptables -A FORWARD -p tcp -d "$LOCAL_FGT_IP" --dport "$FGT_MGMT_PORT" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p tcp -d "$REMOTE_FGT_IP" --dport "$FGT_MGMT_PORT" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

echo "=== 5. Aplicando Masquerade / SNAT (Garantiza respuesta bidireccional) ==="
# SNAT para que los FortiGate respondan al Linux Router directamente
iptables -t nat -A POSTROUTING -o eth1 -d "$LOCAL_FGT_IP" -p tcp --dport "$FGT_MGMT_PORT" -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth3 -d "$REMOTE_FGT_IP" -p tcp --dport "$FGT_MGMT_PORT" -j MASQUERADE

# Enmascaramiento general de salida hacia Internet para los laboratorios
iptables -t nat -A POSTROUTING -o "$WAN_IF" -j MASQUERADE

echo "=== 6. Guardando Reglas para Persistencia ==="
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save
elif command -v iptables-save >/dev/null 2>&1; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
fi

echo "=== Reglas de NAT y Forwarding aplicadas con éxito ==="
iptables -t nat -L PREROUTING -n -v --line-numbers
