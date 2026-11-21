#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE ROLLBACK PARA RESTAURAR LA CONFIGURACIÓN PREVIA DE IPTABLES
# ==============================================================================

set -e

BACKUP_DIR="/root/backup_iptables"
LATEST_BACKUP="${BACKUP_DIR}/iptables_latest_backup.rules"

echo "=================================================================="
echo "🔄 INICIANDO ROLLBACK DE IPTABLES"
echo "=================================================================="

if [ -f "$LATEST_BACKUP" ]; then
    echo "Restaurando desde backup: $LATEST_BACKUP..."
    iptables-restore < "$LATEST_BACKUP"
    
    # Persistir restauracion
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save
    elif command -v iptables-save >/dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4
    fi
    echo "✅ Configuración previa restaurada exitosamente."
else
    echo "⚠️ No se encontró $LATEST_BACKUP."
    echo "Limpiando tablas NAT y FORWARD manualmente como alternativa de seguridad..."
    iptables -t nat -F PREROUTING
    iptables -t nat -F POSTROUTING
    iptables -F FORWARD
    echo "✅ Reglas de NAT y Forward eliminadas."
fi

echo ""
echo "Estado actual de PREROUTING (NAT):"
iptables -t nat -L PREROUTING -n -v
