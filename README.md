# 🛡️ Scripts de Automatización - FortiGate Lab

Repositorio para la sincronización y ejecución automatizada de scripts de red en el Linux Router para la administración de firewalls FortiGate en PNETLab.

---

## 🔍 1. Comandos para Revisar la Configuración Actual

Antes de modificar el firewall, ejecuta estos comandos en tu Linux Router (`10.160.10.114`) para auditar las reglas actuales:

```bash
# Ver reglas activas de NAT (PREROUTING y POSTROUTING)
iptables -t nat -L -n -v --line-numbers

# Ver reglas activas de filtrado (FORWARD, INPUT, OUTPUT)
iptables -L -n -v --line-numbers

# Verificar si el reenvío de paquetes (routing) está activo
sysctl net.ipv4.ip_forward
```

---

## 💾 2. Generación Manual de Backup

Para crear un respaldo manual inmediato de todas tus reglas antes de hacer cualquier cambio:

```bash
mkdir -p /root/backup_iptables
iptables-save > /root/backup_iptables/iptables_manual_backup_$(date +%Y%m%d_%H%M%S).rules
cp /root/backup_iptables/iptables_manual_backup_*.rules /root/backup_iptables/iptables_latest_backup.rules
```

---

## 🔄 3. Cómo hacer Rollback (Restauración Inmediata)

Si experimentas algún problema de conectividad y deseas revertir al estado anterior:

```bash
# Restaurar desde el último backup
iptables-restore < /root/backup_iptables/iptables_latest_backup.rules

# O mediante el script automatizado de rollback:
bash /opt/fortigate/scripts/rollback_nat_router.sh
```

---

## 📁 Contenido del Repositorio

* **`scripts/config_nat_router.sh`**: 
  * Genera un **backup automático** en `/root/backup_iptables/` antes de realizar cambios.
  * Habilita `net.ipv4.ip_forward=1`.
  * Aplica **DNAT**:
    * Puerto WAN `6565` $\rightarrow$ Local-FortiGate (`10.200.1.1:443`).
    * Puerto WAN `6666` $\rightarrow$ Remote-FortiGate (`10.200.3.1:443`).
  * Configura **FORWARD** y **MASQUERADE / SNAT**.
  * Guarda las reglas de forma persistente.
* **`scripts/rollback_nat_router.sh`**: Script de reversión inmediata al estado previo al NAT.

---

## 🚀 Ejecución en el Linux Router (`10.160.10.114`)

### Opción A: Vía Git (Recomendado)
```bash
git clone git@github.com:gdiazes/fortigate.git /opt/fortigate
chmod +x /opt/fortigate/scripts/*.sh
bash /opt/fortigate/scripts/config_nat_router.sh
```

### Opción B: Ejecución directa en una línea (curl)
```bash
curl -sSL https://raw.githubusercontent.com/gdiazes/fortigate/main/scripts/config_nat_router.sh | bash
```

---

## 🌐 URLs de Acceso Resultantes
* **Local-FortiGate:** `https://10.160.10.114:6565`
* **Remote-FortiGate:** `https://10.160.10.114:6666`
