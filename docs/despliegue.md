# Despliegue de UBBike en producción

Guía para dejar el backend de UBBike funcionando en un servidor con Docker, publicado en un subdominio de Cloudflare, y para compilar las APK que se conectan a ese subdominio.

## Cómo queda funcionando

```
App Android / iOS ──HTTPS──> https://SUBDOMINIO (Cloudflare) ──túnel──> backend:3000 (Docker)
                                                                           ├── PostgreSQL (contenedor)
                                                                           └── Redis (contenedor)
```

- Cloudflare entrega el HTTPS con un certificado válido. Cualquier persona con la APK instalada se conecta desde cualquier red.
- El backend, PostgreSQL y Redis corren en contenedores. Ninguno queda expuesto a internet: solo Cloudflare llega al backend.
- Por el mismo subdominio pasan la API REST, el tiempo real (WebSocket), las fotos y las páginas de los enlaces que llegan por correo.

## Requisitos

| Qué | Para qué |
| --- | --- |
| Servidor Linux con Docker Engine y Docker Compose v2 (2 GB de RAM y 10 GB de disco como mínimo) | Correr el backend, PostgreSQL y Redis |
| Un subdominio administrado en Cloudflare, por ejemplo `ubbike.dominio.cl` | Publicar el backend con HTTPS |
| Una cuenta de correo con acceso SMTP | Enviar la confirmación de correo, la recuperación de contraseña y los avisos |
| Un proyecto de Firebase | Notificaciones push en Android (opcional: sin Firebase la app funciona igual, sin push) |
| Flutter 3.41 o más nuevo, Android SDK y JDK 17 (solo en el equipo que compila la APK) | Generar la APK |

## 1. Bajar el proyecto

```bash
git clone https://github.com/SebastianPinto2424/UBBike-Taller2.git ubbike
cd ubbike
cp .env.example .env
```

## 2. Configurar `.env`

| Variable | Valor en producción |
| --- | --- |
| `PUBLIC_API_BASE_URL` | `https://SUBDOMINIO`. Arma los enlaces de los correos |
| `POSTGRES_PASSWORD` | Clave propia, por ejemplo la salida de `openssl rand -base64 24` |
| `JWT_SECRET` | Clave propia de al menos 32 caracteres, por ejemplo `openssl rand -hex 32` |
| `SEED_DEMO_DATA` | `false`. Con `true` se crean las cuentas de demostración, cuyas contraseñas están en el repositorio público |
| `ADMIN_INICIAL_CORREO` y `ADMIN_INICIAL_NOMBRE` | El administrador real. Se crea al primer arranque y recibe un correo para definir su contraseña |
| `TRUST_PROXY` | `1` con Cloudflare Tunnel (opciones A y B del paso 3), `2` con DNS proxiado más Apache o Nginx (opción C) |
| `CORS_ORIGINS` | Vacío. Ver la sección de seguridad |
| `COMPOSE_PROFILES` y `CLOUDFLARE_TUNNEL_TOKEN` | Solo en la opción A del paso 3 |
| `BACKEND_BIND_ADDRESS` | `127.0.0.1`, para que el backend no quede expuesto directamente |
| `SMTP_*` y `MAIL_FROM` | Ver el paso 5 |
| `CORREO_SOPORTE` | Buzón real de soporte que alguien revise. Aparece en el pie de todos los correos y recibe las respuestas. Si se deja vacío, se usa `SMTP_USER` |
| `FIREBASE_CREDENTIALS_BASE64` | Ver el paso 4 |
| `SWAGGER_ENABLED` | `false` |

Con `SEED_DEMO_DATA=false` y `NODE_ENV=production`, que ya define el compose, el backend no arranca si `JWT_SECRET` o `POSTGRES_PASSWORD` siguen con los valores de ejemplo.

## 3. Publicar el subdominio con Cloudflare

### Opción A, recomendada: túnel de Cloudflare dentro del compose

No requiere abrir puertos en el servidor ni instalar certificados.

1. En Cloudflare entra a **Zero Trust → Networks → Tunnels → Create a tunnel**, elige **Cloudflared** y ponle un nombre, por ejemplo `ubbike`.
2. En la pantalla de instalación copia el **token**: el texto largo que aparece después de `--token` en el comando de Docker.
3. En **Public Hostname** agrega el subdominio. En el servicio elige **Type: HTTP** y **URL: `backend:3000`**.
4. En `.env` deja `COMPOSE_PROFILES=cloudflare`, `CLOUDFLARE_TUNNEL_TOKEN=<token>` y `TRUST_PROXY=1`.

El servicio `cloudflared` del compose se levanta junto al backend y mantiene el túnel abierto.

### Opción B: el servidor ya tiene `cloudflared` instalado

Esto aplica si el servidor ya publica otros sitios con un túnel propio.

1. En ese túnel agrega el **Public Hostname** con **URL: `http://localhost:3000`**.
2. En `.env` deja `BACKEND_PORT=3000`, `BACKEND_BIND_ADDRESS=127.0.0.1`, `TRUST_PROXY=1` y `COMPOSE_PROFILES` vacío.

### Opción C: registro DNS proxiado y servidor web propio

Solo aplica si el servidor tiene IP pública con los puertos 80 y 443 abiertos.

1. Crea un registro `A` del subdominio hacia la IP del servidor, con el proxy de Cloudflare activado (nube naranja).
2. Configura Apache con la plantilla `deploy/apache/ubbike-https.conf.example`. En Cloudflare usa el modo SSL **Full (strict)**, con un certificado de origen de Cloudflare o de Let's Encrypt.
3. En `.env` deja `TRUST_PROXY=2`.

### Ajustes de Cloudflare para cualquier opción

- **WebSockets** activado (Network → WebSockets). Viene activado por defecto y el tiempo real de la app lo necesita.
- **No** activar *Bot Fight Mode* ni *Under Attack Mode* para este subdominio. Esos modos le muestran desafíos de navegador a la app, y la app no puede resolverlos.
- El backend mantiene abiertas las conexiones inactivas 95 segundos, más que los 90 segundos que las reutiliza el túnel. Así Cloudflare nunca envía una petición por una conexión que el backend ya cerró, lo que daría errores 502 intermitentes.

## 4. Firebase: notificaciones push

**En el servidor:**

1. En la consola de Firebase entra a **Configuración del proyecto → Cuentas de servicio → Generar nueva clave privada** y descarga el archivo JSON.
2. Convierte el archivo a base64 y pon el resultado en `FIREBASE_CREDENTIALS_BASE64`:

   ```bash
   base64 -w0 firebase-admin.json
   ```

   En PowerShell:

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("firebase-admin.json"))
   ```

3. Borra el JSON del servidor después de copiarlo. Al arrancar, el log del backend muestra `[firebase] Admin SDK inicializado: push habilitado`.

**Para compilar la APK:**

- En **Configuración del proyecto → General**, la app Android `cl.ubiobio.ubbike` entrega el archivo `google-services.json`. Va en `mobile/android/app/` y debe ser del mismo proyecto de Firebase que la credencial del servidor.

**iOS:** el push necesita una cuenta de Apple Developer pagada, una llave APNs cargada en Firebase y `GoogleService-Info.plist` en `mobile/ios/Runner`. Sin eso la app iOS funciona igual, con el tiempo real dentro de la app y sin notificaciones push.

Los archivos de Firebase no se suben al repositorio: están en `.gitignore`.

## 5. Correo (SMTP)

Sin correo nadie puede confirmar su cuenta ni recuperar su contraseña, así que este paso es obligatorio en producción.

**Con Gmail:**

1. Usa una cuenta dedicada, por ejemplo `ubbike.notificaciones@gmail.com`.
2. Activa la verificación en dos pasos.
3. En **Cuenta de Google → Seguridad → Contraseñas de aplicaciones**, crea una contraseña de aplicación (16 caracteres).
4. Configura `.env`:

   ```env
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   SMTP_SECURE=false
   SMTP_USER=ubbike.notificaciones@gmail.com
   SMTP_PASSWORD=<contraseña de aplicación, sin espacios>
   MAIL_FROM=UBBike <ubbike.notificaciones@gmail.com>
   ```

   `MAIL_FROM` debe ser la misma cuenta. Gmail reemplaza otro remitente, y un remitente que no coincide termina en spam.

**Con el SMTP de la institución:** usa el host, el puerto y las credenciales que entregue el área de informática. Usa `SMTP_SECURE=true` solo si el puerto es 465.

Los correos se envían desde una cola con reintentos: si el SMTP falla un momento, se reenvían solos.

Todos los correos siguen la práctica habitual de los correos transaccionales:
- un solo botón y, en los de seguridad, el aviso de que UBBike nunca pide contraseñas;
- en el pie, el correo de soporte (`CORREO_SOPORTE`) y el motivo por el que se recibe el correo;
- si la persona responde, la respuesta llega al correo de soporte;
- no llevan enlace de desuscripción, porque no son correos de marketing.

## 6. Levantar

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f backend
```

En el primer arranque el backend aplica las migraciones de la base de datos, crea el administrador inicial y le envía el correo para definir su contraseña.

**Verificación:** abre `https://SUBDOMINIO/health` desde un celular con datos móviles. Debe responder `"status":"ok"`, con `baseDatos` y `redis` en `true`.

## 7. Compilar la APK

Se hace en el equipo de desarrollo, no en el servidor.

1. Pon `google-services.json` en `mobile/android/app/` (paso 4).
2. **Firma propia (recomendado).** Así cualquier equipo puede compilar actualizaciones que se instalen encima de la versión anterior.
   1. Genera la llave una sola vez y guárdala respaldada fuera del repositorio:

      ```bash
      keytool -genkey -v -keystore ubbike-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ubbike
      ```

   2. Crea `mobile/android/key.properties`:

      ```properties
      storeFile=/ruta/completa/ubbike-release.jks
      storePassword=<clave del almacén>
      keyAlias=ubbike
      keyPassword=<clave de la llave>
      ```

   Sin `key.properties`, la APK se firma con la llave de depuración del equipo que compila.
3. Compila apuntando al subdominio:

   ```bash
   ./compilar-apk.sh https://SUBDOMINIO
   ```

   En Windows:

   ```powershell
   .\compilar-apk.ps1 -Url https://SUBDOMINIO
   ```

   El script revisa que el backend responda, compila la versión release y deja la APK en `apks/`. Esa carpeta está ignorada por git.
4. Comparte la APK. Al instalarla, Android pide permitir la instalación de apps desconocidas.

La dirección del backend queda dentro de la APK. Si cambia el subdominio, hay que volver a compilar.

## 8. Operación

| Tarea | Comando |
| --- | --- |
| Ver el estado | `docker compose ps` |
| Ver los logs | `docker compose logs -f backend` |
| Actualizar a una versión nueva | `git pull && docker compose up -d --build` |
| Respaldar la base de datos | `docker compose exec -T db pg_dump -U ubbike ubbike > respaldo-$(date +%F).sql` |
| Restaurar la base de datos | `docker compose exec -T db psql -U ubbike -d ubbike < respaldo.sql` |
| Respaldar las fotos | `docker run --rm -v ubbike_taller_uploads_data:/datos -v "$PWD":/respaldo alpine tar czf /respaldo/fotos-$(date +%F).tgz -C /datos .` |
| Detener | `docker compose down` (los datos quedan en los volúmenes) |

Los datos viven en tres volúmenes de Docker:
- `ubbike_taller_postgres_data`: la base de datos;
- `ubbike_taller_uploads_data`: las fotos;
- `ubbike_taller_redis_data`: las sesiones y los límites de intentos.

Gracias a ese último, las sesiones se conservan al reiniciar.

Si alguna vez se activaron las cuentas de demostración, se quitan siguiendo "Cuentas de demostración y paso a producción" en el `README.md`.

## Seguridad

- **Puertos:** PostgreSQL, Redis y el backend escuchan solo en `127.0.0.1`. Al exterior solo sale el túnel de Cloudflare.
- **CORS:**
  - La API y el tiempo real rechazan con `403 Origen no permitido` las peticiones de navegador que vienen de otro sitio web. Solo aceptan el propio subdominio.
  - Las páginas de los enlaces de correo (`/enlaces/`) quedan fuera de ese filtro, porque al enviar su formulario el navegador manda `Origin: null`. Las protegen el token de un solo uso del correo, el límite de intentos y su propia CSP.
  - Las apps no envían cabecera `Origin`, porque CORS es una regla de los navegadores, así que no se ven afectadas.
  - `CORS_ORIGINS` queda vacío. Solo se agregan orígenes si algún día existe un frontend web, separados por comas.
- **Autenticación:** CORS no reemplaza la autenticación. Cada ruta protegida exige un token JWT de corta duración, con refresh token rotativo y una sola sesión por cuenta. El inicio de sesión, el registro y los enlaces tienen límite de intentos por IP, por eso `TRUST_PROXY` debe coincidir con el proxy usado.
- **Secretos:** `.env`, la credencial de Firebase, `google-services.json`, las llaves de firma y las APK nunca se suben al repositorio.
