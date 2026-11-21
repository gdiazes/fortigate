# Laboratorio 5: Firewall Authentication (FortiGate)


## Objetivos del Laboratorio
1. Configurar **autenticación activa basada en política** (*Policy-based*) contra un servidor **LDAP remoto** (FortiAuthenticator).
2. Integrar grupos remotos en una política de firewall con inspección de contenido (*Web Filter*) y visibilidad de usuario.
3. Configurar **autenticación activa basada en interfaz** (*Interface-based*) mediante **Portal Cautivo** (*Captive Portal*) con exenciones básicas y mensaje legal (**Disclaimer**).
4. Validar, monitorear y diagnosticar sesiones autenticadas tanto por GUI como por CLI.

---

## Prerrequisitos: Restaurar el estado base del laboratorio

1. Conéctate a la GUI de **Local-FortiGate** (`https://10.0.1.254` o a través de tu NAT `https://10.160.10.114:6565`) con:
   * **Usuario:** `admin`
   * **Contraseña:** `password`
2. En la esquina superior derecha, haz clic en **`admin` > `Configuration` > `Revisions`**.
3. Expande la lista de revisiones (`+`), selecciona la revisión con el comentario **`local-firewall-authentication`** *(nota: en algunas imágenes aparece con la errata `local-firewall-authenticaiton`)* y haz clic en **Revert** > **OK** para reiniciar.

> **💡 Nota técnica:** Restaurar la revisión garantiza que las interfaces (`port1` WAN y `port3` LAN), la política `Full_Access`, el perfil `Category_Monitor` y el usuario local `student` estén exactamente en el punto de partida esperado.

---

# Ejercicio 1: Autenticación Remota mediante LDAP (Basada en Política)

En este ejercicio, FortiGate no almacenará contraseñas de los usuarios finales; delegará la validación de credenciales al servidor **FortiAuthenticator (`10.0.1.150`)** que actúa como directorio LDAP.

## Paso 1.1: Configurar el servidor LDAP en FortiGate

1. En **Local-FortiGate**, ve a **`User & Authentication > LDAP Servers`** y haz clic en **Create New**.
2. Completa los campos exactamente con estos valores **(con el DN de `Username` ya corregido)**:

| Campo | Valor | Explicación |
| :--- | :--- | :--- |
| **Name** | `External_Server` | Nombre identificador del objeto LDAP en FortiGate (*case-sensitive*). |
| **Server IP/Name** | `10.0.1.150` | Dirección IP del FortiAuthenticator en la LAN (`port3`). |
| **Server Port** | `389` | Puerto estándar LDAP. *(Ver recomendación de LDAPS/636 abajo).* |
| **Common Name Identifier** | `uid` | Atributo que identifica el nombre de usuario en este directorio LDAP. |
| **Distinguished Name** | `ou=Training,dc=trainingAD,dc=training,dc=lab` | Rama base (*Base DN*) donde FortiGate buscará usuarios y grupos. |
| **Bind Type** | `Regular` | Usa una cuenta de servicio para buscar el DN completo del usuario antes de autenticarlo. |
| **Username** | `uid=adadmin,cn=Users,ou=Training,dc=trainingAD,dc=training,dc=lab` | **[Corregido]** En el árbol real de FortiAuthenticator, `cn=Users` reside dentro de `ou=Training`. |
| **Password** | `Training!` | Contraseña de la cuenta de enlace (*Bind*) `adadmin`. |
| **Secure Connection** | Desactivado *(para el lab básico)* | Ver nota de endurecimiento abajo para activar cifrado LDAPS. |

3. Haz clic en **Test Connectivity** y verifica que el estado muestre **Successful** (en verde).
4. Haz clic en **OK**.

> **💡 Nota técnica (¿Por qué `Bind Type: Regular`?):**
> Cuando un usuario inicia sesión escribiendo solo `aduser1`, FortiGate no sabe en qué subcarpeta del árbol LDAP está ubicado. Con el tipo **Regular**, FortiGate se conecta primero usando la cuenta `adadmin`, busca dónde vive `uid=aduser1` dentro del *Base DN*, obtiene su ruta completa y finalmente valida la contraseña de `aduser1` contra LDAP.

> **🔒 Recomendación de Seguridad (Endurecimiento / Producción):**
> El puerto `389` sin cifrado envía credenciales en texto plano. En producción (y como prueba opcional en este lab si importas el certificado CA del FortiAuthenticator), debes activar **Secure Connection**, seleccionar **LDAPS (puerto 636)** o **STARTTLS**, y elegir el certificado de la CA emisora. Además, usa siempre una cuenta de servicio LDAP con permisos de **solo lectura**.

### Equivalente rápido en CLI (opcional):
```text
config user ldap
    edit "External_Server"
        set server "10.0.1.150"
        set port 389
        set cnid "uid"
        set dn "ou=Training,dc=trainingAD,dc=training,dc=lab"
        set type regular
        set username "uid=adadmin,cn=Users,ou=Training,dc=trainingAD,dc=training,dc=lab"
        set password Training!
    next
end
```

---

## Paso 1.2: Asociar el grupo LDAP a un Firewall User Group

FortiGate no aplica políticas directamente sobre un servidor LDAP completo, sino sobre **User Groups** (grupos de firewall) que filtran qué grupos remotos están autorizados.

1. Ve a **`User & Authentication > User Groups`** y edita el grupo preconfigurado **`Remote-users`** *(verifica que sea de tipo **Firewall**)*.
2. En la tabla **Remote Groups**, haz clic en **Add**.
3. En **Remote Server**, selecciona **`External_Server`**.
4. En la pestaña **Groups**, busca el grupo **`AD_users`** *(nota: con guion bajo, no guion medio)*, haz clic derecho sobre él y selecciona **Add Selected**.
5. Confirma que aparece con un check verde (`cn=AD_users,ou=Training,dc=trainingAD,dc=training,dc=lab`) y haz clic en **OK** dos veces para guardar.

> **💡 Nota técnica:** Al hacer *group matching* contra `AD_users`, solo los usuarios LDAP que pertenezcan a ese grupo (como `aduser1` y `aduser2`) podrán hacer coincidencia (*match*) con las políticas que exijan el grupo `Remote-users`. Cualquier otro usuario LDAP válido fuera de ese grupo será rechazado por la política.

---

## Paso 1.3: Validar la autenticación LDAP desde la CLI antes de tocar políticas

*(Buena práctica: siempre valida la autenticación a nivel de servidor antes de exigirla en una política de producción).*

1. Abre la consola CLI de **Local-FortiGate** y ejecuta:
   ```text
   diagnose test authserver ldap External_Server aduser1 Training!
   ```
2. Debes ver un resultado similar a:
   ```text
   authenticate 'aduser1' against 'External_Server' succeeded!
   Group membership(s) - cn=AD_users,ou=Training,dc=trainingAD,dc=training,dc=lab
   ```

> **🛠️ Tip de diagnóstico:** Si alguna vez falla esta prueba, activa el depurador del demonio de autenticación (`fnbamd`) en tiempo real:
> ```text
> diagnose debug reset
> diagnose debug application fnbamd -1
> diagnose debug enable
> ```
> Ejecuta de nuevo la prueba y, al terminar, apaga el debug con `diagnose debug disable`.

---

## Paso 1.4: Aplicar el grupo de usuarios a la política de firewall

1. Ve a **`Policy & Objects > Firewall Policy`** y edita la política **`Full_Access`** (`port3` ➔ `port1`).
2. En **Source**, haz clic en **`+`**, ve a la pestaña **User** y agrega **`Remote-users`** *(dejando también `LOCAL_SUBNET`)*.
3. En **Security Profiles**, habilita **Web Filter** y selecciona **`Category_Monitor`** *(bloquea categorías como Hacking, Security Risk y Adult/Mature Content)*. Verifica que **SSL Inspection** esté en `certificate-inspection`.
4. En **Logging Options**, habilita **Log Allowed Traffic** y selecciona **All Sessions**.
5. Haz clic en **OK**.

> **💡 Nota técnica:**
> * En **Source**, FortiGate evalúa **IP AND Usuario**: el tráfico debe venir de `LOCAL_SUBNET` **y además** pertenecer a un usuario autenticado de `Remote-users`.
> * Como el tráfico aún no está autenticado y la política es la única que coincide, FortiGate interceptará la primera solicitud HTTP del cliente para pedir credenciales (**autenticación activa basada en política**).

---

## Paso 1.5: Probar, monitorear y revocar la autenticación

1. En la VM **Local-Client**, abre una **ventana de navegación privada/incógnito** *(recomendación clave para evitar caché de redirecciones del navegador)* y navega a:
   ```text
   http://elite-hackers.com
   ```
2. Cuando aparezca el formulario de autenticación de FortiGate, inicia sesión con:
   * **Username:** `aduser1`
   * **Password:** `Training!`
3. **Resultado esperado:** Tras autenticarse correctamente, el perfil `Category_Monitor` bloqueará el sitio y mostrará la página de reemplazo indicando:
   * **Category:** `Hacking`
   * **Username:** `aduser1`
   * **Group Name:** `Remote-users`
4. Vuelve a la GUI de **Local-FortiGate**, ve a **`Dashboard > Users & Devices`** y haz clic en el widget **Firewall Users** para expandirlo.
   * Verás a `aduser1` (`10.0.1.10`) bajo el grupo `Remote-users` y método `Firewall`.
   * *(Opcional por CLI)*: Ejecuta `diagnose firewall auth list` y `show full-configuration user setting` para ver la sesión y el tiempo de expiración (`auth-timeout`, por defecto 5 minutos de inactividad).
5. Selecciona **`aduser1`**, haz clic en **Deauthenticate** y confirma con **OK**.

> **💡 Nota técnica:** Al desautenticar manualmente, FortiGate elimina inmediatamente la entrada de la tabla de usuarios autenticados en memoria (`firewall auth list`), obligando al usuario a volver a iniciar sesión en su próxima solicitud.

---

## Paso 1.6: Limpieza obligatoria antes del Ejercicio 2

1. En **Local-FortiGate**, ve a **`Policy & Objects > Firewall Policy`** y edita **`Full_Access`**.
2. En **Source**, elimina **`Remote-users`** (haciendo clic en la `X`), dejando únicamente **`LOCAL_SUBNET`**.
3. Haz clic en **OK**.
4. Cierra la ventana privada del navegador en **Local-Client**.

> **⚠️ ¿Por qué es crítico este paso?** Si dejas `Remote-users` en la política, cuando el usuario local `student` se autentique por Captive Portal en el Ejercicio 2, no pertenecerá a `Remote-users` y el tráfico será bloqueado por la política de firewall.

---

# Ejercicio 2: Portal Cautivo (Basado en Interfaz) y Disclaimer

En este ejercicio, la obligación de autenticarse se mueve **de la política a la interfaz `port3`**. Cualquier dispositivo conectado a `port3` deberá autenticarse en el portal cautivo y aceptar un acuerdo legal antes de navegar.

## Paso 2.1: Crear un grupo de usuarios para el Captive Portal

1. En **Local-FortiGate**, ve a **`User & Authentication > User Groups`** y haz clic en **Create New**.
2. Configura:
   * **Name:** `CP-group`
   * **Type:** `Firewall`
   * **Members:** selecciona el usuario local preconfigurado **`student`**.
3. Haz clic en **OK**.

> **💡 Nota técnica:** En este laboratorio usamos el usuario local `student` para simplificar la práctica; sin embargo, en producción el grupo del Captive Portal puede (y debe) apuntar a un servidor **LDAP/RADIUS/SAML** o a un portal de invitados en **FortiAuthenticator** para centralizar la gestión y auditoría.

---

## Paso 2.2: Habilitar Captive Portal en la interfaz `port3` (con buenas prácticas)

1. Ve a **`Network > Interfaces`** y edita **`port3`**.
2. En la sección **Network**, habilita **Security mode** y configura:

| Campo | Valor | Explicación |
| :--- | :--- | :--- |
| **Security mode** | `Captive Portal` | Activa la autenticación obligatoria en toda la interfaz `port3`. |
| **Authentication portal** | `Local` | FortiGate aloja y sirve directamente la página HTML de inicio de sesión. |
| **User access** | `Restricted to Groups` | Solo permite el paso a miembros de los grupos especificados. |
| **User groups** | `CP-group` | Grupo autorizado para pasar el portal cautivo. |
| **Exempt destinations/services** | *(Recomendado)* `DNS` | Permite resolver nombres DNS antes de autenticarse, evitando bloqueos en la redirección del portal. |
| **Exempt sources** | *(Opcional en producción)* | Aquí excluirías impresoras, teléfonos IP, cámaras o servidores (p. ej. `10.0.1.150`) que no tienen navegador para autenticarse. |
| **Redirect after Captive Portal** | `Original Request` | Redirige al usuario a la URL que intentó visitar originalmente. |

3. Haz clic en **OK** y confirma el mensaje emergente con **OK**.

> **💡 Nota técnica:** En el laboratorio, FortiGate permite DNS internamente si usas el DNS del lab, pero agregar `DNS` en *Exempt destinations/services* y servidores/IoT en *Exempt sources* es una práctica obligatoria en despliegues reales para no tumbar servicios sin navegador.

---

## Paso 2.3: Habilitar el mensaje de Disclaimer (solo por CLI en interfaces cableadas)

1. Abre la consola CLI de **Local-FortiGate** y ejecuta:
   ```text
   config firewall policy
       edit 1
           set disclaimer enable
       next
   end
   ```
   *(Verifica con `show firewall policy 1` que la política ID `1` corresponda efectivamente a `Full_Access`).*

> **💡 Nota técnica (Detalle clave de examen):**
> * En **SSIDs Wi-Fi** administrados por FortiGate (`WiFi & Switch Controller > SSID`), el *Disclaimer* se puede activar desde la GUI.
> * En **interfaces cableadas** (como `port3`), FortiOS exige habilitar el *Disclaimer* desde la **CLI** dentro de la política de firewall (`set disclaimer enable`).

---

## Paso 2.4: Autenticarse en el Portal Cautivo y aceptar el Disclaimer

1. En **Local-Client**, abre una nueva **ventana privada/incógnito** y navega a:
   ```text
   http://www.eicar.org
   ```
2. Cuando aparezca la pantalla **Authentication Required**, inicia sesión con:
   * **Username:** `student`
   * **Password:** `fortinet`
   * Haz clic en **Continue**.
3. Se abrirá la pantalla **Terms and Disclaimer Agreement**. Haz clic en **Yes, I agree**.
4. Serás redirigido a `www.eicar.org`. Abre otra pestaña y navega a `http://www.eicar.com` para generar tráfico adicional.

> **💡 Nota técnica sobre HTTPS en la vida real:** En este laboratorio usamos URLs HTTP porque el portal intercepta la petición sin fricción. En entornos reales donde casi todo el tráfico es HTTPS (con HSTS), conviene configurar un **certificado SSL firmado por una CA confiable** en `config user setting` (`set auth-cert <certificado>`) para evitar alertas de seguridad en los navegadores.

---

## Paso 2.5: Monitorear y comprender el doble registro en Firewall Users

1. En la GUI de **Local-FortiGate**, ve a **`Dashboard > Users & Devices > Firewall Users`** (pantalla completa).
2. Observarás **dos sesiones activas** para la misma IP (`10.0.1.10`):
   * **Registro 1:** User Name = `student` | User Group = `CP-group` | Method = **`Firewall`**
   * **Registro 2:** User Name = `1` *(corresponde al Policy ID 1)* | Method = **`Disclaimer`**
3. *(Verificación CLI recomendada)*: Ejecuta en consola:
   ```text
   diagnose firewall auth list
   ```
   Verás reflejado el usuario autenticado, su IP, el método, el tiempo restante de expiración y el volumen de tráfico.
4. Para finalizar, selecciona **`student`** en **Firewall Users**, haz clic en **Deauthenticate** > **OK**, y cierra el navegador en **Local-Client**.

---

## Resumen de Comandos CLI Esenciales (Hoja de Referencia)

| Objetivo | Comando CLI en FortiGate |
| :--- | :--- |
| Probar usuario contra servidor LDAP | `diagnose test authserver ldap External_Server aduser1 Training!` |
| Depurar fallos LDAP / RADIUS en vivo | `diagnose debug application fnbamd -1` + `diagnose debug enable` |
| Detener depuración | `diagnose debug disable` |
| Listar usuarios autenticados activos | `diagnose firewall auth list` |
| Desautenticar todas las sesiones activas | `diagnose firewall auth clear` |
| Revisar `auth-timeout` y certificado del portal | `show full-configuration user setting` |
| Habilitar Disclaimer en política cableada | `config firewall policy` ➔ `edit <ID>` ➔ `set disclaimer enable` |

---

## Checklist rápido antes de llevar esto a Producción
* [ ] **Cifrado obligatorio:** Usar **LDAPS (636)** o **STARTTLS** con validación de certificado CA (nunca LDAP 389 en texto plano).
* [ ] **Mínimo privilegio:** Usar una cuenta Bind dedicada de solo lectura en Active Directory / LDAP.
* [ ] **Elegir autenticación pasiva vs. activa:** Usar **FSSO** (autenticación pasiva) para PCs corporativos en dominio AD y reservar **Captive Portal** para redes Guest / BYOD.
* [ ] **Exenciones definidas:** Excluir DNS, impresoras, telefonía IP, IoT y servidores de infraestructura en el Captive Portal.
* [ ] **Certificado confiable:** Asignar un certificado válido (`auth-cert`) en `config user setting` para el portal cautivo.