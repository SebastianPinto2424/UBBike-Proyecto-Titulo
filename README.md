# UBBike

Aplicacion movil (Android e iOS) y API REST para registrar bicicletas, validar ingresos y retiros en bicicleteros, y mantener trazabilidad operativa para la Universidad del Bio-Bio.

## Estructura

- `backend/`: API REST con Node.js, Express, Prisma y PostgreSQL.
- `mobile/`: aplicacion Flutter para Android e iOS.
- `deploy/`: plantillas y scripts para el despliegue en el contenedor.
- `docs/`: documentacion tecnica complementaria.

Este documento cubre las formas de desplegar el proyecto: en local con Docker, en un servidor con Docker y en el contenedor institucional con pm2.

## Despliegue local con Docker

Requisitos:

- Docker Desktop o Docker Engine con Docker Compose.
- Git.
- Flutter solo si se compila la APK.

Levantar el entorno:

```bash
cp .env.example .env
docker compose up -d --build
```

Verificar:

```bash
docker compose ps
```

Accesos locales por defecto:

| Servicio | URL |
| --- | --- |
| Backend health | `http://localhost:3000/health` |
| PostgreSQL local | `127.0.0.1:5433` |

Detener:

```bash
docker compose down
```

### APK de prueba en red Wi-Fi

Para probar desde celulares reales, el PC y los celulares deben estar en la misma red Wi-Fi. Desde la raiz del proyecto:

```powershell
.\preparar-demo.ps1
```

El script detecta la IP local, actualiza `.env`, levanta Docker, verifica el backend y genera una APK release que queda en la carpeta `apks-pruebas` del Escritorio.

Antes de instalar la APK conviene comprobar desde el celular que `http://IP_DEL_PC:3000/salud` responde. Si no responde, hay que ejecutar el script una vez como administrador o habilitar el puerto TCP 3000 en el Firewall de Windows. Esta APK es solo para pruebas locales por HTTP; la APK de produccion se compila apuntando a HTTPS.

### Prueba y compilacion para iOS

Se hace en un Mac con Xcode, CocoaPods y Flutter instalados (`flutter doctor` debe mostrar Xcode sin errores). El backend puede correr en el mismo Mac con Docker Desktop:

```bash
git clone -b rama-dev-contenedor https://github.com/SebastianPinto2424/UBBike-Taller2.git ubbike
cd ubbike
cp .env.example .env
docker compose up -d --build
cd mobile
flutter pub get
```

En el simulador, `localhost` es el propio Mac, asi que basta con abrirlo y ejecutar la app:

```bash
open -a Simulator
flutter run
```

En un iPhone real:

1. En `.env` cambiar `BACKEND_BIND_ADDRESS=0.0.0.0` y `PUBLIC_API_BASE_URL=http://IP_DEL_MAC:3000`, y volver a ejecutar `docker compose up -d`. Desde Safari del iPhone, `http://IP_DEL_MAC:3000/health` debe responder.
2. Abrir `mobile/ios/Runner.xcworkspace` en Xcode y, en Runner > Signing & Capabilities, elegir el equipo (sirve un Apple ID personal). Si Xcode avisa que el identificador `cl.ubiobio.ubbike` no esta disponible, cambiarlo por uno propio.
3. Conectar el iPhone por cable, activar el Modo desarrollador (Ajustes > Privacidad y seguridad) y, con un Apple ID personal, confiar en el certificado en Ajustes > General > VPN y gestion de dispositivos.
4. Con el iPhone en la misma red Wi-Fi que el Mac, ejecutar `flutter run --release --dart-define=API_BASE_URL=http://IP_DEL_MAC:3000` y aceptar el permiso de red local que pide la app.

La primera compilacion genera el `Podfile` y ejecuta `pod install`; el proyecto ya fija iOS 15.5 como version minima, la que necesitan el escaner y Firebase.

Las notificaciones push en iOS requieren ademas una cuenta de Apple Developer Program, una llave APNs cargada en Firebase, el archivo `GoogleService-Info.plist` en `ios/Runner` (agregado desde Xcode) y las capacidades Push Notifications y Background Modes > Remote notifications. Sin eso la app funciona igual, con las actualizaciones en tiempo real dentro de la app, pero no recibe push.

Para produccion:

```bash
flutter build ios --release --dart-define=API_BASE_URL=https://DOMINIO
```

### Prueba con el dominio gratis de ngrok

ngrok publica con HTTPS el backend que corre en Docker en este PC, en un dominio fijo. Asi el iPhone o cualquier celular se conecta desde cualquier red, iOS no exige excepciones de seguridad y no hay que recompilar la app cuando cambia la IP del PC.

En el PC donde corre Docker:

1. Crear una cuenta en ngrok.com, instalar el agente desde `https://ngrok.com/download` y registrar el token del panel con `ngrok config add-authtoken TOKEN`.
2. En el panel de ngrok, en Domains, copiar el dominio gratis asignado (`NOMBRE.ngrok-free.dev`; las cuentas antiguas usan `.ngrok-free.app`).
3. En `.env` dejar `PUBLIC_API_BASE_URL=https://NOMBRE.ngrok-free.dev` y `TRUST_PROXY=1`, y aplicar con `docker compose up -d`. Asi los enlaces de los correos usan el dominio y el limite de intentos ve la IP real de cada persona.
4. Abrir el tunel hacia el puerto del backend (`BACKEND_PORT`, 3000 en `.env.example`) y dejarlo abierto mientras se prueba:

   ```bash
   ngrok http --url=https://NOMBRE.ngrok-free.dev 3000
   ```

   Desde el navegador del celular, `https://NOMBRE.ngrok-free.dev/health` debe responder.

En el Mac solo se compila la app, con el iPhone conectado y firmado como se explica arriba:

```bash
cd mobile
flutter pub get
flutter run --release --dart-define=API_BASE_URL=https://NOMBRE.ngrok-free.dev
```

La APK de Android usa el mismo dominio:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://NOMBRE.ngrok-free.dev
```

Limites del plan gratis: la app no ve ningun aviso de ngrok, pero un enlace de correo abierto en el navegador muestra una vez la advertencia de ngrok; se pasa con "Visit Site" y no vuelve a aparecer en 7 dias en ese celular. El plan incluye 20.000 peticiones y 1 GB al mes, suficiente para pruebas; conviene cerrar el tunel (Ctrl+C) al terminar.

## Despliegue en un servidor con Docker

En un servidor con Docker y Docker Compose:

```bash
git clone -b rama-dev-contenedor https://github.com/SebastianPinto2424/UBBike-Taller2.git ubbike
cd ubbike
cp .env.example .env
```

Editar `.env` con los valores del servidor:

| Variable | Valor |
| --- | --- |
| `PUBLIC_API_BASE_URL` | `https://DOMINIO`; tambien arma los enlaces de los correos |
| `POSTGRES_PASSWORD` | Clave unica de al menos 16 caracteres |
| `JWT_SECRET` | Cadena aleatoria de al menos 32 caracteres |
| `TRUST_PROXY` | `1` cuando la app queda detras de un proxy (Apache, Nginx o ngrok); es la cantidad de proxies de confianza |
| `SMTP_USER` y `SMTP_PASSWORD` | Cuenta de correo para los avisos |
| `FIREBASE_CREDENTIALS_BASE64` | Credencial de Firebase en base64, para las notificaciones push |
| `ADMIN_INICIAL_CORREO` y `ADMIN_INICIAL_NOMBRE` | Administrador real (correo `@ubiobio.cl`) que se crea al iniciar, si aun no existe |

La credencial de Firebase se convierte a base64 con `base64 -w0 firebase-admin.json` en Linux o con `[Convert]::ToBase64String([IO.File]::ReadAllBytes("firebase-admin.json"))` en PowerShell.

Levantar:

```bash
docker compose up -d --build
```

Los contenedores escuchan solo en `127.0.0.1`. El servidor web publica el dominio enviando todo el trafico, incluido `/socket.io`, a `127.0.0.1:3000`; la plantilla `deploy/apache/ubbike-https.conf.example` sirve de base. La APK se compila apuntando al mismo dominio:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://DOMINIO
```

## Enlaces de los correos

Los correos de verificacion, recuperacion de contrasena y activacion de cuenta apuntan a `https://DOMINIO/enlaces/...`. Esas paginas las sirve el backend con la paleta de la app y funcionan desde el computador o el celular: ahi la persona confirma su correo o crea su contrasena. Los formularios validan igual que la app (mismos mensajes, ayuda al tocar cada campo y un boton por campo para ver la contrasena) y piden la contrasena dos veces para confirmar que coincida. Al terminar, la pagina muestra el mensaje que corresponde (correo confirmado, cuenta activada o contrasena actualizada) y un boton que abre la app. Si el enlace para confirmar el correo vencio, la pagina ofrece enviar uno nuevo; tambien se puede pedir desde la app al registrarse o al intentar iniciar sesion. El token del correo nunca pasa por la app.

## Cuentas de demostracion y paso a produccion

Con `SEED_DEMO_DATA=true` el backend crea al iniciar las cuentas de demostracion (estudiante, funcionario, guardia, central y administrador) para probar todos los roles. Para dejar el sistema solo con registro normal:

1. En `.env` dejar `SEED_DEMO_DATA=false`, completar `ADMIN_INICIAL_CORREO` y `ADMIN_INICIAL_NOMBRE` con el administrador real, y usar `POSTGRES_PASSWORD` y `JWT_SECRET` propios. Con los datos demo apagados, el backend no arranca si esas claves siguen siendo las de ejemplo.
2. Recrear el backend con `docker compose up -d backend`. Al iniciar crea al administrador real y le envia el correo para definir su contrasena.
3. Una vez que el administrador real definio su contrasena, desactivar las cuentas demo:

```bash
docker compose exec backend npm run quitar-demo
```

El comando cierra las sesiones de las cuentas demo y las deja eliminadas. No hace nada si `SEED_DEMO_DATA` sigue activo o si no hay otro administrador activo y verificado.

Si la base de datos ya se habia creado con la clave de ejemplo, primero hay que cambiarla dentro de PostgreSQL con `docker compose exec db psql -U ubbike -d ubbike -c "ALTER USER ubbike PASSWORD 'CLAVE_NUEVA'"` y despues poner la misma en `POSTGRES_PASSWORD`.

## Despliegue en el contenedor institucional (pm2)

En produccion el proyecto corre sin Docker, con este stack:

- Apache como servidor HTTPS y proxy reverso.
- Node.js 20 para el backend, mantenido activo con pm2.
- PostgreSQL institucional externo.
- Redis local para los refresh tokens y el limite de intentos.

El codigo vive en `/opt/ubbike`. Las plantillas incluidas en el repo son:

| Archivo | Uso |
| --- | --- |
| `deploy/apache/ubbike-https.conf.example` | VirtualHost Apache con HTTPS y proxy al backend. |
| `deploy/systemd/ubbike-backend.service.example` | Alternativa a pm2 con systemd, si se prefiere. |

### Variables de entorno

Crear en el servidor `/opt/ubbike/backend/.env` con estas variables, completando los valores reales:

```env
NODE_ENV=production
PORT=3000
TRUST_PROXY=loopback
DB_HOST=<HOST_DB_INSTITUCIONAL>
DB_PORT=5432
DB_USER=<USUARIO_DB>
DB_PASSWORD=<PASSWORD_DB>
DB_NAME=<NOMBRE_DB>
JWT_SECRET=<SECRETO_LARGO_MINIMO_32_CARACTERES>
JWT_EXPIRES_IN=2h
JWT_ISSUER=ubbike-api
JWT_AUDIENCE=ubbike-app
REFRESH_TOKEN_EXPIRES_DAYS=30
ENLACES_BASE_URL=https://DOMINIO_O_IP_PUBLICA
SEED_DEMO_DATA=false
ADMIN_INICIAL_CORREO=<CORREO_ADMINISTRADOR>
ADMIN_INICIAL_NOMBRE=<NOMBRE_ADMINISTRADOR>
SWAGGER_ENABLED=false
QR_DURATION_SECONDS=15
UPLOADS_DIR=/opt/ubbike/uploads
UPLOADS_PUBLIC_PATH=/uploads
REQUIRE_REDIS_RATE_LIMIT=true
REDIS_URL=redis://127.0.0.1:6379
SMTP_HOST=<SMTP_HOST>
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=<SMTP_USER>
SMTP_PASSWORD=<SMTP_PASSWORD>
MAIL_FROM="UBBike <no-reply@ubiobio.cl>"
FIREBASE_CREDENTIALS_PATH=
FIREBASE_CREDENTIALS_BASE64=
```

Si en este servidor se habilitan las cuentas demo con `SEED_DEMO_DATA=true`, se quitan despues con `npm run quitar-demo` desde `/opt/ubbike/backend`, siguiendo los mismos pasos de la seccion de paso a produccion.

### Redis

El backend no arranca en produccion sin Redis. Se instala en el mismo servidor y queda escuchando solo en localhost:

```bash
sudo apt install -y redis-server
sudo service redis-server start
redis-cli ping
```

`redis-cli ping` debe responder `PONG`. Como el contenedor no tiene systemd, si se reinicia hay que volver a ejecutar `sudo service redis-server start` antes de `pm2 restart ubbike-backend`.

### Compilacion del backend

Desde el servidor:

```bash
cd /opt/ubbike/backend
npm ci
npm run build
npm run migrate
```

### Backend con pm2

Levantar el backend y dejarlo persistente ante reinicios:

```bash
cd /opt/ubbike/backend
pm2 start dist/servidor.js --name ubbike-backend
pm2 save
pm2 startup
```

Operacion diaria:

```bash
pm2 status
pm2 logs ubbike-backend
pm2 restart ubbike-backend
```

Tras actualizar el codigo (`git pull`), repetir la compilacion del backend y luego `pm2 restart ubbike-backend`.

### Apache

Habilitar modulos:

```bash
sudo a2enmod ssl headers rewrite proxy proxy_http proxy_wstunnel
```

Copiar la plantilla y reemplazar `DOMINIO_O_IP_PUBLICA` por el origen HTTPS real:

```bash
sudo cp /opt/ubbike/deploy/apache/ubbike-https.conf.example /etc/apache2/sites-available/ubbike.conf
sudo nano /etc/apache2/sites-available/ubbike.conf
```

Activar:

```bash
sudo a2ensite ubbike.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
```

### HTTPS del contenedor institucional

El contenedor expone el puerto `443` mediante un puerto publico asignado por la institucion. Mientras no exista un dominio o certificado institucional, se usa un certificado autofirmado fijado en la APK (certificate pinning):

```bash
cd /opt/ubbike
PUBLIC_HOST=<IP_DEL_CONTENEDOR> PUBLIC_HTTPS_PORT=<PUERTO_HTTPS_PUBLICO> \
  bash deploy/configurar-https-contenedor.sh
```

El script configura Apache, genera la clave privada solo en el servidor y deja el certificado publico en `/etc/ssl/ubbike/ubbike.crt`. La clave `/etc/ssl/ubbike/ubbike.key` nunca debe salir del servidor.

Desde un PC conectado a la VPN, copiar exclusivamente el certificado publico al proyecto:

```bash
scp -P <PUERTO_SSH> <USUARIO>@<IP_DEL_CONTENEDOR>:/etc/ssl/ubbike/ubbike.crt mobile/assets/certs/ubbike.crt
```

Compilar la APK apuntando al origen HTTPS:

```bash
cd mobile
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://<IP_DEL_CONTENEDOR>:<PUERTO_HTTPS_PUBLICO>
```

El certificado autofirmado sirve para la APK, pero la pagina de los enlaces de correo se abre en el navegador del celular y mostrara una advertencia. Para evitarla se requiere un dominio institucional con certificado publico (Certbot/Let's Encrypt).

### Verificacion en produccion

```bash
curl https://DOMINIO_O_IP_PUBLICA/salud
redis-cli ping
pm2 status
pm2 logs ubbike-backend
```

## Notas de seguridad

- `JWT_SECRET` debe tener al menos 32 caracteres y ser unico.
- `SEED_DEMO_DATA=false` en produccion, con las cuentas demo quitadas mediante `npm run quitar-demo`.
- PostgreSQL no debe exponerse publicamente desde el servidor de la app.
- Redis debe quedar escuchando solo en `127.0.0.1`.
- No publicar `.env`, certificados, llaves privadas, APKs ni credenciales de Firebase.
- Usar HTTPS para la API, el WebSocket, los enlaces de correo y la APK.

## Documentacion adicional

- `docs/desarrollo-y-api.md`
- `docs/modelo-relacional.md`
