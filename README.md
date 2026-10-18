# UBBike

Aplicacion web/mobile y API REST para registrar bicicletas, validar ingresos y retiros en bicicleteros, y mantener trazabilidad operativa para la Universidad del Bio-Bio.

## Estructura

- `backend/`: API REST con Node.js, Express, Prisma y PostgreSQL.
- `mobile/`: aplicacion Flutter para Web y Android.
- `deploy/`: plantillas y scripts para el despliegue en el contenedor.
- `docs/`: documentacion tecnica complementaria.

Este documento cubre las dos formas de desplegar el proyecto: en local con Docker y en el contenedor institucional con pm2.

## Despliegue local con Docker

Requisitos:

- Docker Desktop o Docker Engine con Docker Compose.
- Git.
- Flutter solo si se compila la APK.

Levantar el entorno:

```bash
docker compose up -d --build
```

Verificar:

```bash
docker compose ps
```

Accesos locales por defecto:

| Servicio | URL |
| --- | --- |
| Web Flutter | `http://localhost:8082` |
| Backend health | `http://localhost:3001/health` |
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

El script detecta la IP local, actualiza `.env`, levanta Docker, verifica el backend y genera una APK debug que queda en la carpeta `apks-pruebas` del Escritorio.

Antes de instalar la APK conviene comprobar desde el celular que `http://IP_DEL_PC:3000/salud` responde. Si no responde, hay que ejecutar el script una vez como administrador o habilitar el puerto TCP 3000 en el Firewall de Windows. Esta APK es solo para pruebas locales por HTTP; la APK de produccion se compila en release apuntando a HTTPS.

## Despliegue en el contenedor institucional (pm2)

En produccion el proyecto corre sin Docker, con este stack:

- Apache como servidor HTTPS y proxy reverso.
- Node.js 20 para el backend, mantenido activo con pm2.
- PostgreSQL institucional externo.
- Redis local para los refresh tokens y el limite de intentos.
- Flutter Web compilado como archivos estaticos.

El codigo vive en `/opt/ubbike`. Las plantillas incluidas en el repo son:

| Archivo | Uso |
| --- | --- |
| `backend/.env.production.example` | Variables requeridas por el backend en produccion. |
| `deploy/apache/ubbike-https.conf.example` | VirtualHost Apache con HTTPS, Flutter Web y proxy al backend. |
| `deploy/systemd/ubbike-backend.service.example` | Alternativa a pm2 con systemd, si se prefiere. |

### Variables de entorno

Crear en el servidor `/opt/ubbike/backend/.env` usando `backend/.env.production.example` como base y completando los valores reales:

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
FRONTEND_URL=https://DOMINIO_O_IP_PUBLICA
CORS_ORIGINS=https://DOMINIO_O_IP_PUBLICA
SEED_DEMO_DATA=false
SWAGGER_ENABLED=false
UPLOADS_DIR=/opt/ubbike/uploads
UPLOADS_PUBLIC_PATH=/uploads
REQUIRE_REDIS_RATE_LIMIT=true
REDIS_URL=redis://127.0.0.1:6379
```

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

### Compilacion de Flutter Web

Desde el servidor, si Flutter esta instalado:

```bash
cd /opt/ubbike/mobile
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=https://DOMINIO_O_IP_PUBLICA
sudo rsync -a --delete build/web/ /var/www/ubbike/
```

Si Flutter no esta instalado en el servidor, se compila en local y se sube `mobile/build/web/` a `/var/www/ubbike/`.

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

El certificado autofirmado cifra y autentica la conexion para la APK, pero los navegadores mostraran una advertencia. Para Flutter Web sin advertencias se requiere un certificado publico emitido para un dominio institucional (Certbot/Let's Encrypt).

### Verificacion en produccion

```bash
curl -I https://DOMINIO_O_IP_PUBLICA
curl https://DOMINIO_O_IP_PUBLICA/salud
redis-cli ping
pm2 status
pm2 logs ubbike-backend
```

## Notas de seguridad

- `JWT_SECRET` debe tener al menos 32 caracteres y ser unico.
- `SEED_DEMO_DATA=false` en produccion.
- PostgreSQL no debe exponerse publicamente desde el servidor de la app.
- Redis debe quedar escuchando solo en `127.0.0.1`.
- No publicar `.env`, certificados, llaves privadas, APKs ni credenciales de Firebase.
- Usar HTTPS para web, API, WebSocket y APK.

## Documentacion adicional

- `docs/desarrollo-y-api.md`
- `docs/modelo-relacional.md`
