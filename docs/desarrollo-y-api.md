# Desarrollo y API

## Arquitectura backend adoptada

El backend usa una arquitectura modular por feature, organizada en capas:

```text
src/
├── modulos/<feature>/
│   ├── feature.rutas.ts
│   ├── feature.controlador.ts
│   ├── feature.servicio.ts
│   ├── feature.repositorio.ts
│   ├── feature.validacion.ts
│   └── feature.tipos.ts
├── comun/
└── configuracion/
```

La regla principal es que los servicios contienen la logica de negocio y delegan el acceso a datos en repositorios. Los repositorios son la capa que conoce Prisma. Esta es una version ligera de Clean Architecture: separa HTTP, negocio y persistencia sin introducir una estructura DDD mas pesada que la escala actual del proyecto.

## Flujo funcional del MVP

1. El usuario solicita registro con correo institucional.
2. El sistema asigna rol automaticamente segun dominio de correo:
   - `@alumnos.ubiobio.cl`: estudiante.
   - `@ubiobio.cl`: funcionario.
3. El usuario verifica su correo mediante enlace seguro.
4. El usuario inicia sesion y registra una o mas bicicletas.
5. El usuario selecciona una bicicleta activa.
6. Para ingreso, selecciona bicicletero y genera QR temporal.
7. Para retiro, genera QR asociado al bicicletero donde la bicicleta se encuentra registrada.
8. El guardia selecciona en su perfil el bicicletero que gestiona durante su turno.
9. El guardia valida QR solo si corresponde a su bicicletero activo.
10. El guardia confirma o deniega ingreso/retiro.
11. Si el QR no puede usarse, el guardia registra acceso manual con correo institucional o RUT.
12. Usuarios pueden solicitar apoyo si no ven al guardia o requieren servicio.
13. Guardia y central reciben alertas y notificaciones dentro de la aplicacion.
14. Central y administrador revisan historial, dashboard, solicitudes y operaciones por guardia.
15. Administrador puede gestionar usuarios, roles, estado de cuenta y verificacion de correo.

## Endpoints principales

Autenticacion:

```text
POST /autenticacion/registro
POST /autenticacion/login
GET  /autenticacion/perfil
GET  /autenticacion/verificar-correo
POST /autenticacion/verificar-correo
POST /autenticacion/completar-registro
POST /autenticacion/solicitar-cambio-contrasena
POST /autenticacion/cambiar-contrasena
POST /autenticacion/cambiar-contrasena-sesion
POST /autenticacion/refresh
POST /autenticacion/logout
```

`cambiar-contrasena-sesion` revoca todas las sesiones del usuario (sube `versionSesion`
e invalida los refresh tokens), por lo que tras usarlo hay que iniciar sesion de nuevo.

Bicicletas:

```text
GET    /bicicletas
GET    /bicicletas/activa
POST   /bicicletas
PATCH  /bicicletas/:id
DELETE /bicicletas/:id
PATCH  /bicicletas/:id/activar
PATCH  /bicicletas/:id/desactivar
```

No se puede eliminar una bicicleta que este registrada dentro de un bicicletero:
primero hay que registrar su retiro.

Bicicleteros (crear, editar y eliminar solo ADMINISTRADOR):

```text
GET    /bicicleteros
POST   /bicicleteros
PATCH  /bicicleteros/:id
DELETE /bicicleteros/:id
```

Eliminar un bicicletero lo desactiva, y falla si todavia tiene bicicletas dentro.

QR y accesos:

```text
POST /qr/generar
POST /qr/validar
POST /accesos/qr/confirmar
POST /accesos/qr/denegar
POST /accesos/manual
```

Guardias y solicitudes:

```text
GET    /guardias/me/bicicletero
PATCH  /guardias/me/bicicletero
DELETE /guardias/me/bicicletero
GET    /solicitudes-guardia
POST   /solicitudes-guardia
POST   /solicitudes-guardia/:id/notificar-guardia
PATCH  /solicitudes-guardia/:id/estado
```

Incidencias:

```text
GET   /incidencias
POST  /incidencias
POST  /incidencias/:id/recordar
PATCH /incidencias/:id/estado
```

`recordar` solo lo puede usar quien reporto la incidencia, con una espera de
5 minutos entre recordatorios. Al crear o recordar se notifica a ADMIN_CENTRAL y
ADMINISTRADOR (nunca al guardia ni a quien ejecuta la accion), y se envia correo
de respaldo. Cerrar una incidencia exige una respuesta, que se envia al reportante.

Historial y reportes:

```text
GET /historial
GET /historial/resumen
GET /historial/opciones
GET /historial/exportar-excel
```

La exportacion esta restringida a ADMIN_CENTRAL y ADMINISTRADOR, y respeta los
mismos filtros de la consulta (`q`, `periodo`, `desde`, `hasta`, `tipo`, `estado`,
`bicicleteroId`, `guardiaId`, `origen`).

Devuelve un `.xlsx` real generado con ExcelJS
(`application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`), con
encabezado fijo, autofiltro y la fecha como celda de tipo fecha. El tipo
declarado coincide con el contenido, asi que Excel lo abre sin la advertencia de
formato y Sheets o LibreOffice lo leen igual. El PDF se genera en el cliente.

El `override` de `uuid` se mantiene en la linea `11.x` a proposito: ExcelJS lo
carga con `require('uuid')` y las versiones 13+ son solo ESM, lo que rompe la
carga en cualquier Node sin soporte de `require(esm)`.

Usuarios y notificaciones:

```text
GET    /usuarios
POST   /usuarios
PATCH  /usuarios/:id/permisos
POST   /usuarios/:id/reenviar-acceso
POST   /usuarios/:id/reenviar-verificacion
DELETE /usuarios/:id
GET    /notificaciones
PATCH  /notificaciones/leidas
PATCH  /notificaciones/:id/leida
POST   /notificaciones/dispositivos
DELETE /notificaciones/dispositivos
```

Alias mantenidos por compatibilidad:

```text
GET  /health
POST /auth/register
POST /auth/login
GET  /auth/me
```

## Arranque sin Docker completo

Primero se levantan los servicios base:

```bash
docker compose up -d db redis mailpit
```

Backend:

```bash
cd backend
npm install
npm run migrate
npm run dev
```

Si la base ya tenia tablas antes de Prisma y aparece `P3005`, se aplica el baseline sin borrar datos:

```powershell
docker compose stop backend
Get-Content -Raw backend\prisma\migrations\20260515123000_init\migration.sql | docker compose exec -T db psql -v ON_ERROR_STOP=1 -U ubbike -d ubbike
docker compose run --rm --no-deps backend npx prisma migrate resolve --applied 20260515123000_init
docker compose up -d
```

Flutter:

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Para emulador Android, Flutter usa por defecto `http://10.0.2.2:3000` cuando no se entrega `API_BASE_URL`. Para web/escritorio usa `http://localhost:3000`. En dispositivo fisico se debe indicar la IP real del backend:

```bash
flutter run --dart-define=API_BASE_URL=http://IP_DEL_PC:3000
```

Build web local:

```bash
cd mobile
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:3000
```

## Validaciones recomendadas

Backend:

```bash
cd backend
npm run generate
npx prisma validate
npm run typecheck
npm run build
npm test
```

`npm test` corre las pruebas unitarias y de rutas con dependencias simuladas.
`npm run test:coverage` mide y exige el mínimo definido en `jest.config.ts`.

Las pruebas reales requieren PostgreSQL y Redis **exclusivos para pruebas**.
La base ya debe existir y llamarse `ubbike_e2e` o `ubbike_e2e_<sufijo>`.
No se reutilizan variables ni contenedores de desarrollo. El helper aplica
migraciones y vacía únicamente esa base, con autorización explícita:

```bash
cd backend
TEST_DATABASE_URL='postgresql://usuario:clave@127.0.0.1:15439/ubbike_e2e_local' \
TEST_REDIS_URL='redis://127.0.0.1:56389' ALLOW_TEST_DATABASE_RESET=1 npm run test:e2e
```

Verifican lo que las pruebas con mocks no pueden garantizar: que una transaccion
fallida no deje escrituras a medias, que las restricciones de unicidad se
apliquen de verdad y que la ocupacion se calcule sobre las filas reales.

Frontend:

```bash
cd mobile
flutter analyze
flutter test
```

Docker Compose:

```bash
docker compose config --quiet
```

## Modelo relacional

El modelo relacional se documenta en `docs/modelo-relacional.md`.

El backend considera:

- Usuarios con roles `ESTUDIANTE`, `FUNCIONARIO`, `GUARDIA`, `ADMIN_CENTRAL` y `ADMINISTRADOR`.
- Bicicleteros activos con capacidad y ocupacion.
- Bicicletas asociadas a usuarios.
- QR temporales asociados a usuario, bicicleta, tipo de movimiento y bicicletero.
- Asignaciones activas de guardia a bicicletero.
- Movimientos de ingreso/retiro con estado confirmado o denegado.
- Solicitudes de guardia.
- Notificaciones por usuario.
- Auditoria de acciones relevantes.

Los nombres de modelos, modulos y funciones del backend se mantienen en espanol cuando no chocan con convenciones propias de Node, Express o Prisma.
