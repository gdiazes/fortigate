# 🛡️ Proyecto FortiGate - Laboratorios y Automatización

Repositorio para la administración, configuración, guías de laboratorio y automatización de firewalls **FortiGate (FortiOS)** en entornos virtuales (PNETLab / EVE-NG) y redes corporativas.

---

## 📐 Topología de Laboratorio

![Topología NAT](img/nat.png)

---

## 📁 Estructura del Repositorio

* **`labs/`**:
  * 📘 [`lab05.md`](labs/lab05.md): **Laboratorio 5: Firewall Authentication** (Autenticación basada en políticas con LDAP / FortiAuthenticator y Portal Cautivo con Disclaimer).
* **`docs/`**:
  * 📄 [`GUIA_CONFIGURACION_NAT.md`](docs/GUIA_CONFIGURACION_NAT.md): Guía detallada del enrutamiento y Port Forwarding en Linux Router (`10.160.10.114`).
* **`scripts/`**:
  * ⚙️ [`config_nat_router.sh`](scripts/config_nat_router.sh): Script en Bash con **backup preventivo automático** y reglas DNAT/SNAT completas.
  * 🔄 [`rollback_nat_router.sh`](scripts/rollback_nat_router.sh): Script de restauración inmediata al estado previo.
* **`img/`**: Diagramas de red y capturas de topología.
* **`configs/`**: Plantillas y respaldos de configuración CLI (`.conf`).

---

## 🚀 Despliegue Rápido en el Linux Router (`10.160.10.114`)

Para aplicar el NAT y acceder a las consolas web de los FortiGate:

```bash
git clone https://github.com/gdiazes/fortigate.git /opt/fortigate
chmod +x /opt/fortigate/scripts/*.sh
bash /opt/fortigate/scripts/config_nat_router.sh
```

### URLs de Acceso a FortiGates:
* **Local-FortiGate:** `https://10.160.10.114:6565`
* **Remote-FortiGate:** `https://10.160.10.114:6666`

---

## 🔄 Rollback de Reglas
Si requieres revertir la configuración en cualquier momento:
```bash
bash /opt/fortigate/scripts/rollback_nat_router.sh
```
