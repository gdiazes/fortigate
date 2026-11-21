# 🛡️ Scripts de Automatización - FortiGate Lab

Repositorio para la sincronización y ejecución automatizada de scripts de red en el Linux Router para la administración de firewalls FortiGate en PNETLab.

---

## 📁 Contenido del Repositorio

* **`scripts/config_nat_router.sh`**: Script en Bash que aplica automáticamente:
  1. Habilitación de `net.ipv4.ip_forward=1` en el kernel de Linux.
  2. Reglas de **DNAT (Port Forwarding)**:
     * Puerto WAN `6565` $\rightarrow$ Local-FortiGate (`10.200.1.1:443`).
     * Puerto WAN `6666` $\rightarrow$ Remote-FortiGate (`10.200.3.1:443`).
  3. Reglas de filtrado **FORWARD** en iptables.
  4. Enmascaramiento **MASQUERADE / SNAT** para garantizar el retorno de paquetes.
  5. Persistencia automática con `iptables-persistent`.

---

## 🚀 Ejecución Automatizada en el Linux Router (`10.160.10.114`)

Puedes ejecutarlo en el servidor Linux Router de cualquiera de estas dos formas:

### Opción 1: Ejecución directa en una sola línea (Vía curl)
```bash
curl -sSL https://raw.githubusercontent.com/gdiazes/fortigate/main/scripts/config_nat_router.sh | bash
```

### Opción 2: Clonando el repositorio
```bash
git clone git@github.com:gdiazes/fortigate.git /opt/fortigate
chmod +x /opt/fortigate/scripts/config_nat_router.sh
bash /opt/fortigate/scripts/config_nat_router.sh
```

---

## 🌐 URLs de Acceso Resultantes
* **Local-FortiGate:** `https://10.160.10.114:6565`
* **Remote-FortiGate:** `https://10.160.10.114:6666`
