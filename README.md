# UBBike

Aplicacion movil (Android e iOS) y API REST para registrar bicicletas, validar ingresos y retiros en bicicleteros, y mantener trazabilidad operativa para la Universidad del Bio-Bio.

## Estructura

- `backend/`: API REST con Node.js, Express, Prisma y PostgreSQL.
- `mobile/`: aplicacion Flutter para Android e iOS.
- `deploy/`: plantilla de Apache para publicar el backend con un servidor web propio.
- `compilar-apk.ps1` y `compilar-apk.sh`: compilan la APK apuntando al dominio de produccion.
- `docs/`: documentacion tecnica complementaria.

Este documento cubre el uso local con Docker y las pruebas en celulares. El despliegue en produccion esta en [`docs/despliegue.md`](docs/despliegue.md).

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

### Pruebas locales en red Wi-Fi

Para probar desde celulares reales, el PC y los celulares deben estar en la misma red Wi-Fi. Desde la raiz del proyecto:

```powershell
.\preparar-pruebas-locales.ps1
```

El script detecta la IP local, actualiza `.env`, levanta Docker, verifica el backend y genera una APK release que queda en la carpeta `apks-pruebas` del Escritorio.

Antes de instalar la APK conviene comprobar desde el celular que `http://IP_DEL_PC:3000/salud` responde. Si no responde, hay que ejecutar el script una vez como administrador o habilitar el puerto TCP 3000 en el Firewall de Windows. Esta APK es solo para pruebas locales por HTTP; la APK de produccion se compila apuntando a HTTPS.

### Prueba y compilacion para iOS

Se hace en un Mac con Xcode, CocoaPods y Flutter instalados (`flutter doctor` debe mostrar Xcode sin errores). El backend puede correr en el mismo Mac con Docker Desktop:

```bash
git clone https://github.com/SebastianPinto2424/UBBike-Taller2.git ubbike
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

## Despliegue en produccion

La guia completa esta en [`docs/despliegue.md`](docs/despliegue.md): servidor con Docker, subdominio de Cloudflare (tunel incluido en el compose), variables de `.env`, Firebase, correo, respaldos y compilacion de la APK. En resumen:

```bash
git clone https://github.com/SebastianPinto2424/UBBike-Taller2.git ubbike
cd ubbike
cp .env.example .env
docker compose up -d --build
```

Con el `.env` completo (`PUBLIC_API_BASE_URL=https://SUBDOMINIO`, claves propias, `SEED_DEMO_DATA=false`, administrador inicial, SMTP, Firebase y `COMPOSE_PROFILES=cloudflare` con el token del tunel), la APK se compila apuntando al mismo subdominio:

```bash
./compilar-apk.sh https://SUBDOMINIO
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

## Notas de seguridad

- `JWT_SECRET` y `POSTGRES_PASSWORD` deben ser propios; con los datos demo apagados el backend no arranca con los de ejemplo.
- `SEED_DEMO_DATA=false` en produccion, con las cuentas demo quitadas mediante `npm run quitar-demo`.
- PostgreSQL, Redis y el backend escuchan solo en `127.0.0.1`; al exterior se publica unicamente el subdominio por Cloudflare.
- La API y el tiempo real rechazan con `403` las peticiones de navegador de otros sitios; la app no envia `Origin` y no se ve afectada. `CORS_ORIGINS` solo se completa si existe un frontend web.
- No publicar `.env`, llaves de firma, APKs ni credenciales de Firebase (`google-services.json`, `GoogleService-Info.plist`, cuenta de servicio).
- Usar HTTPS para la API, el WebSocket, los enlaces de correo y la APK.

## Corrector ortografico

Los campos de texto libre de la app (incidencias, motivos y notas) marcan las palabras mal escritas y, al tocarlas, ofrecen sugerencias.
- Si el telefono tiene un corrector compatible (Gboard con el corrector del sistema activado, o iPhone), se usa ese.
- Si no, la app usa su propio diccionario de espanol en `mobile/assets/ortografia/`.

La lista `palabras_es.txt` se deriva de [FrequencyWords](https://github.com/hermitdave/FrequencyWords), de Hermit Dave, generada a partir de OpenSubtitles 2018, y se distribuye bajo [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Se dejaron solo palabras y se quitaron abreviaturas y formas sin tilde que casi siempre son errores. La app registra esta licencia junto a las demas licencias de terceros. `palabras_ubbike.txt` agrega palabras propias de UBBike.

## Documentacion adicional

- `docs/despliegue.md`
- `docs/desarrollo-y-api.md`
- `docs/modelo-relacional.md`
