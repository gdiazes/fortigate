# 🛡️ Proyecto FortiGate - Laboratorios y Automatización

Repositorio para la administración, guías de laboratorio y automatización de firewalls **FortiGate (FortiOS)** en entornos virtuales (PNETLab / EVE-NG).

---

## 📁 Contenido del Repositorio

* **`labs/`**:
  * 📘 [`lab05.md`](labs/lab05.md): **Laboratorio 5: Firewall Authentication** (Autenticación basada en políticas con LDAP / FortiAuthenticator y Portal Cautivo por interfaz con Disclaimer).
* **`scripts/`**:
  * ⚙️ [`config_nat_router.sh`](scripts/config_nat_router.sh): Script en Bash con **backup preventivo automático** y reglas DNAT/SNAT completas para acceso a los FortiGate desde Internet tanto por **HTTPS** como por **SSH**.
  * 🔄 [`rollback_nat_router.sh`](scripts/rollback_nat_router.sh): Script de restauración inmediata al estado previo de iptables.

---

## 🚀 Despliegue en el Linux Router (`10.160.10.114`)

Para aplicar el NAT y habilitar los accesos remotos:

```bash
git clone https://github.com/gdiazes/fortigate.git /opt/fortigate
chmod +x /opt/fortigate/scripts/*.sh
bash /opt/fortigate/scripts/config_nat_router.sh
```

*(Si ya clonaste el repositorio previamente, solo ingresa a `/opt/fortigate`, corre `git pull` y ejecuta `bash scripts/config_nat_router.sh`)*.

---

## 🌐 URLs y Puertos de Acceso a FortiGates

### 1. Acceso Web (GUI HTTPS)
* **Local-FortiGate:** `https://10.160.10.114:6565`
* **Remote-FortiGate:** `https://10.160.10.114:6666`

### 2. Acceso por Consola (CLI SSH)
* **Local-FortiGate:**
  ```bash
  ssh admin@10.160.10.114 -p 2221
  # (o puerto alternativo 6522: ssh admin@10.160.10.114 -p 6522)
  ```
* **Remote-FortiGate:**
  ```bash
  ssh admin@10.160.10.114 -p 2222
  # (o puerto alternativo 6622: ssh admin@10.160.10.114 -p 6622)
  ```

---

## 🔄 Rollback de Reglas
Si requieres revertir la configuración en cualquier momento:
```bash
bash /opt/fortigate/scripts/rollback_nat_router.sh
```
