# Desarrollo y API

## Arquitectura backend adoptada

El backend usa una arquitectura modular por feature, organizada en capas:

```text
src/
├── modulos/<feature>/
│   ├── <feature>.rutas.ts
│   ├── <feature>.controlador.ts
│   ├── <feature>.servicio.ts
│   ├── <feature>.repositorio.ts
│   └── <feature>.validacion.ts
├── comun/
├── configuracion/
├── tiempo-real/
└── scripts/
```

Las rutas definen los middlewares de cada endpoint, los controladores traducen la peticion HTTP, los servicios contienen la logica de negocio y los repositorios el acceso a datos. Las validaciones usan esquemas Joi sobre el cuerpo, los parametros de ruta y los filtros de consulta (`validarCuerpo`, `validarParametros` y `validarConsulta`): todo `:id` debe ser un UUID y cada filtro solo acepta los valores que conoce, asi un dato mal formado responde 400 antes de llegar a la base de datos. Los enumerados de cada modulo viven en archivos propios (`estado-*.ts`, `tipo-*.ts`), las reglas de negocio puras en `*.reglas.ts`, las conversiones a respuesta en `*.mapeador.ts` y las paginas HTML del modulo `enlaces` en `enlace.vistas.ts`, con su logo y su script en `publico/` (el script se sirve con version por contenido desde `enlace.recursos.ts` para que el navegador no use una copia vieja). `comun/` reune middlewares, errores y utilidades compartidas; `configuracion/` el entorno, Prisma, Redis, Firebase y los datos iniciales; `tiempo-real/` el servidor Socket.IO, y `scripts/` los comandos de mantenimiento como `quitar-demo`.

Antes de las rutas, `restringirOrigen` (`comun/middlewares/origen.middleware.ts`) rechaza con 403 las peticiones de navegador cuyo `Origin` no sea el dominio publico del backend (`ENLACES_BASE_URL`), el mismo host de la peticion o uno de `CORS_ORIGINS`, que por defecto esta vacio. Las paginas de `/enlaces/` quedan exentas, porque el navegador envia su formulario con `Origin: null` (`Referrer-Policy: no-referrer`); las protege el token del correo. El servidor Socket.IO aplica la misma regla con `allowRequest`. Las apps no envian `Origin`, asi que no se ven afectadas; la proteccion de los datos sigue siendo el token JWT de cada ruta.

La regla principal es que los servicios contienen la logica de negocio y delegan el acceso a datos en repositorios. Los repositorios son la capa que conoce Prisma, incluidas las transacciones. Fuera de ellos solo usan Prisma el punto de entrada (conectar y desconectar), el chequeo de salud y la carga de datos iniciales. Esta es una version ligera de Clean Architecture: separa HTTP, negocio y persistencia sin introducir una estructura DDD mas pesada que la escala actual del proyecto.

Cuando una feature crece, su logica se reparte en servicios por tema dentro del mismo modulo, sin crear modulos nuevos:

- `autenticacion/`: `autenticacion.servicio.ts` (inicio y cierre de sesion), `registro.servicio.ts` (registro, verificacion y registro completado), `contrasena.servicio.ts` (recuperacion y cambio de contrasena) y `enlace-cuenta.servicio.ts` (revision de los enlaces de los correos).
- `usuarios/`: `usuario.servicio.ts` (listar, crear y desactivar cuentas), `invitacion.servicio.ts` (reenvio de correos de acceso y verificacion) y `permisos.servicio.ts` (cambios de nombre, correo, rol y estado de la cuenta).
- `acceso/operaciones/`: `acceso.servicio.ts` (flujo QR), `gestion-manual.servicio.ts` (ingreso y retiro sin QR) y `registro-movimiento.servicio.ts` (registro y aviso del movimiento, compartido por ambos flujos).
- `acceso/solicitudes/` e `incidencias/`: el servicio principal crea y lista; `seguimiento-solicitud.servicio.ts` y `seguimiento-incidencia.servicio.ts` atienden los cambios de estado y recordatorios, con sus reglas y mapeadores aparte.
- `correos/`: `correo.servicio.ts` (envio y entrega), `correo.formato.ts` (cabecera, boton y pie comunes), `cuenta.plantillas.ts` y `operacion.plantillas.ts`.

`tests/unitarias/arquitectura.test.ts` verifica en cada ejecucion que solo los repositorios y la infraestructura usen Prisma, que los controladores no accedan a datos, que no haya dependencias circulares, que cada modulo con controlador exponga sus rutas, que ningun archivo supere las 500 lineas y que las reglas y los mapeadores no dependan de servicios ni repositorios.

## Arquitectura de la app

La app Flutter tambien se organiza por feature, con tres capas por feature:

```text
lib/
├── app/
├── core/
├── shared/
└── features/<feature>/
    ├── data/
    ├── application/
    └── presentation/
```

`data` contiene la API y el repositorio de la feature, `application` los view models con Riverpod y `presentation` las pantallas y widgets. `core` reune la configuracion, la sesion, el cliente HTTP, el tema y los servicios base; `shared` los modelos, widgets y utilidades comunes, y `app` el arranque y la navegacion por rol.

`test/arquitectura_test.dart` verifica estas reglas en cada ejecucion de las pruebas:

- `core` no depende de `shared`, de las features ni de `app`.
- `shared` no depende de las features ni de `app`.
- Dentro de una feature, `presentation` puede usar `application` y `data`, y `application` solo `data`.
- Una feature solo usa la capa `data` de otra, y no hay dependencias circulares entre features.
- Las vistas leen datos a traves de la capa de aplicacion, nunca de un repositorio.
- Ningun archivo de `lib` supera las 500 lineas.

Convenciones de interfaz:

- En cada par de botones, la accion que cancela o vuelve atras va a la izquierda y la accion principal a la derecha, como indican Material Design (Android) y las Human Interface Guidelines (iOS). Si no caben en una fila, se apilan con la accion principal arriba.
- "Cancelar" y toda accion que niega o rechaza (Rechazar, Descartar, Cancelar solicitud) usan rojo; las acciones que confirman usan azul. En los dialogos destructivos (Eliminar, Liberar, Trasladar, Rechazar QR, Cerrar sin resolver) el rojo pasa a la accion, que no se puede deshacer, y "Cancelar" queda azul como salida segura.
- Cada campo de contrasena tiene su propio boton para mostrarla u ocultarla.
- Los mensajes de error nunca muestran detalles tecnicos: sin conexion, `ClienteApi` responde "No pudimos conectar con el servidor..." y ante un error 5xx o una respuesta que no es JSON, "El servidor no responde en este momento...".
- Los campos de texto libre (motivos, comentarios, descripciones, nombre y referencia del bicicletero) activan la revision ortografica del teclado del sistema con `revisionOrtografica()`, que subraya las palabras mal escritas y ofrece sugerencias. Los campos de correo, RUT, contrasenas, marcas, modelos y numeros de serie no la usan para no marcar como error nombres propios ni codigos.
- Las validaciones de cada formulario usan los mismos limites que el esquema Joi del endpoint correspondiente.

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
14. Central y administrador revisan historial, tablero, solicitudes y operaciones por guardia.
15. Administrador puede gestionar usuarios, roles, estado de cuenta y verificacion de correo.
16. Separacion de funciones: nadie valida, rechaza ni registra a mano movimientos de su propia bicicleta, ni siquiera el administrador. El servidor lo controla con `impedirAutovalidacion` (`acceso.reglas.ts`) al escanear el QR, al confirmarlo o denegarlo y en la busqueda y el registro manual, y responde 403.

## Endpoints principales

Autenticacion:

```text
POST /autenticacion/registro
POST /autenticacion/login
GET  /autenticacion/perfil
GET  /autenticacion/verificar-correo
POST /autenticacion/verificar-correo
POST /autenticacion/reenviar-verificacion
POST /autenticacion/completar-registro
POST /autenticacion/solicitar-cambio-contrasena
POST /autenticacion/cambiar-contrasena
POST /autenticacion/cambiar-contrasena-sesion
POST /autenticacion/refresh
POST /autenticacion/logout
```

`cambiar-contrasena-sesion` revoca todas las sesiones del usuario (sube `versionSesion`
e invalida los refresh tokens), por lo que tras usarlo hay que iniciar sesion de nuevo.

`login` revisa la contrasena antes de informar el estado de la cuenta: con una contrasena
incorrecta responde siempre `401 Credenciales invalidas`, aunque la cuenta este
desactivada o sin confirmar, para no revelar que correos estan registrados (OWASP). Con la
contrasena correcta, una cuenta sin confirmar recibe `403` con
`codigo: "CORREO_NO_VERIFICADO"` y la app ofrece reenviar el enlace.

`reenviar-verificacion` responde siempre el mismo mensaje, exista o no la cuenta. Solo envia
un enlace nuevo (24 horas) a cuentas activas pendientes de confirmar que se registraron
solas, espera 60 segundos entre envios y limita los intentos por origen.

Cada cuenta mantiene una sola sesion activa: `login` sube `versionSesion`, revoca los
refresh tokens anteriores, olvida los dispositivos push registrados y cierra en tiempo
real la sesion abierta en cualquier otro dispositivo.

Cuando administracion elimina o desactiva una cuenta, o le cambia el rol o el correo, el
backend sube `versionSesion` y envia por tiempo real el evento `sesion` con su motivo
(`CUENTA_ELIMINADA`, `CUENTA_DESACTIVADA` o `CUENTA_ACTUALIZADA`). Lo mismo ocurre al
cambiar la contrasena con el enlace del correo (`CONTRASENA_ACTUALIZADA`), en todos los
dispositivos de esa cuenta. La app cierra la sesion al instante y muestra el motivo en un
aviso temporal de la pantalla de ingreso. Si la app estaba cerrada, la sesion se rechaza en
la siguiente peticion.

Enlaces de los correos:

```text
GET  /enlaces/verificar-correo?token=...
POST /enlaces/verificar-correo
GET  /enlaces/cambiar-contrasena?token=...
POST /enlaces/cambiar-contrasena
GET  /enlaces/completar-registro?token=...
POST /enlaces/completar-registro
POST /enlaces/reenviar-verificacion
GET  /enlaces/resultado/:resultado
GET  /enlaces/recursos/ubbike-logo.png
GET  /enlaces/recursos/formulario-enlace.js
```

Los correos de verificacion, recuperacion y activacion apuntan a estas paginas, armadas
con `ENLACES_BASE_URL`. Siguen el estandar para apps sin dominio verificado: la accion
se completa en una pagina web servida por el backend, que funciona desde el computador
o el celular, y despues se vuelve a la app. El `GET` revisa el token sin consumirlo y
muestra el formulario; el `POST` ejecuta la accion. Asi los analizadores de enlaces de
los correos no pueden consumir el token. Si el token esta vencido o ya se uso, la pagina
explica como pedir uno nuevo; si es un enlace de confirmacion vencido, ofrece el boton
"Enviarme un enlace nuevo", que envia otro al mismo correo (`POST /enlaces/reenviar-verificacion`)
y lleva a `/enlaces/resultado/enlace-reenviado`. La pagina de contrasena distingue la activacion de una
cuenta creada por administracion (la cuenta aun debe cambiar su contrasena) de una
recuperacion, con titulos, botones y mensaje final distintos. Tras el `POST` exitoso
responde `303` hacia `/enlaces/resultado/:resultado` (`correo-verificado`,
`registro-completado`, `cuenta-activada` o `contrasena-actualizada`), cuyo boton abre la
app con `ubbike://abrir`, sin token ni avisos.

Los correos con boton siguen el estandar de los correos transaccionales: saludo con el
primer nombre (`Hola, Ana:`, como indica la RAE), texto de vista previa oculto, un solo
boton, vencimiento del enlace, enlace de respaldo para copiar y pegar y aviso si no fue la
persona. Las opciones de la app se nombran en negrita, sin comillas.

Los formularios se comportan como las pantallas de la app: etiquetas flotantes, la ayuda
aparece al tocar el campo y los errores al enviar, con los mismos mensajes. La contrasena
se escribe dos veces (`Contrasena` y `Confirmar contrasena`) y debe coincidir; cada campo
tiene su propio boton para mostrarla u ocultarla. No muestran el correo; lo dejan en
un campo oculto `autocomplete="username"` para que el gestor de contrasenas asocie la
clave a la cuenta. Las reglas salen de `reglasFormulario` (`enlace.validacion.ts`), que
arma tanto los esquemas Joi del servidor como los atributos `data-*` que lee
`publico/formulario-enlace.js` en el navegador; una prueba compara ambos resultados. Sin
JavaScript el servidor valida igual y vuelve a mostrar el formulario con los errores.

Estas paginas usan su propia politica de seguridad de contenido: solo estilos en linea,
el logo y el script propios y formularios hacia el mismo sitio. No guardan cache, limitan
los intentos por origen y escapan todo dato mostrado.

La app no procesa enlaces: el esquema `ubbike://` solo la abre o la trae al frente tal
como estaba. El manejo de rutas propio de Flutter queda desactivado
(`flutter_deeplinking_enabled` en Android y `FlutterDeepLinkingEnabled` en iOS) para que
abrirla desde el enlace no apile pantallas.

Si `ADMIN_INICIAL_CORREO` esta definido y no existe una cuenta con ese correo, al
iniciar el backend crea ese administrador y le envia el correo para definir su
contrasena. Asi el sistema puede partir sin las cuentas demo. Una cuenta eliminada
con ese correo no se vuelve a crear.

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

Bicicleteros (crear, editar y eliminar solo ADMINISTRADOR; asignar y liberar al guardia, central y ADMINISTRADOR):

```text
GET    /bicicleteros
POST   /bicicleteros
PATCH  /bicicleteros/:id
DELETE /bicicleteros/:id
POST   /bicicleteros/:id/guardia
DELETE /bicicleteros/:id/guardia
```

Eliminar un bicicletero lo desactiva, y falla si todavia tiene bicicletas dentro. Para
guardias, central y administracion el listado incluye `guardiaActivo` (quien gestiona
cada bicicletero, en una sola consulta); al resto no se le muestra.

QR y accesos:

```text
POST /qr/generar
GET  /qr/:id/estado
POST /qr/validar
POST /qr/liberar
POST /accesos/qr/confirmar
POST /accesos/qr/denegar
POST /accesos/manual
```

`liberar` lo usa el guardia al escanear nuevamente: suelta el QR escaneado para que
vuelva a quedar disponible. `estado` solo lo consulta el dueño del QR y permite a la
app recuperar el resultado (escaneado, confirmado, denegado o liberado) si se perdio
el evento en tiempo real. El resultado de un movimiento por QR o manual se informa
al usuario por correo.

Guardias y solicitudes:

```text
GET    /guardias
GET    /guardias/me/bicicletero
PATCH  /guardias/me/bicicletero
DELETE /guardias/me/bicicletero
GET    /solicitudes-guardia
POST   /solicitudes-guardia
POST   /solicitudes-guardia/:id/notificar-guardia
POST   /solicitudes-guardia/:id/cancelar
PATCH  /solicitudes-guardia/:id/estado
```

Cada bicicletero tiene a lo mas un guardia activo y cada guardia gestiona a lo mas un
bicicletero: el servicio responde `409` indicando quien lo gestiona, y dos indices
unicos parciales lo garantizan en la base aunque lleguen peticiones simultaneas. Un
guardia deja de gestionar su bicicletero cuando lo libera, cuando cierra sesion, cuando
administracion desactiva su cuenta o le cambia el rol, y cuando central o administracion
lo liberan desde la seccion Guardias de la app (pestana "En turno").

Desde esa misma pestana, central y administracion asignan un guardia con un formulario
que reutiliza el selector desplegable del perfil del guardia
(`shared/widgets/selector_desplegable.dart`): el selector de bicicleteros solo ofrece los
que no tienen guardia y se recarga con cada evento `BICICLETEROS` o `USUARIO`, asi que si
otro guardia toma el elegido se quita y se avisa. El evento `USUARIO` llega a central y a
administracion, tambien cuando un guardia activa su cuenta, y la pestana usa ademas el
refresco de respaldo (`AutoRefrescoMixin`) por si se pierde un evento durante una
reconexion. `GET /guardias` lista los guardias habilitados (cuenta
activa y contrasena ya definida) con el bicicletero que gestiona cada uno, y
`POST /bicicleteros/:id/guardia` recibe `{ guardiaId }`. Si el guardia ya gestionaba otro bicicletero se traslada, y las
solicitudes que no alcanzo a responder en el anterior vuelven a pendientes. El guardia
recibe un push tanto al ser asignado como al ser liberado por central.

Las solicitudes pertenecen al bicicletero, no a una persona, y ninguna se pierde: si
nadie lo gestiona quedan pendientes y visibles para central; cuando un guardia toma el
bicicletero recibe en la misma transaccion todas las que nadie atendia (un solo aviso
resumido para el y uno para cada solicitante); cuando un guardia lo deja, las que no
alcanzo a responder vuelven a pendientes y se avisa a central y a los solicitantes. Las
que ya marco "en camino" siguen con el hasta cerrarlas. Cada traspaso queda en
auditoria (`SOLICITUDES_GUARDIA_TRASPASADAS` y `SOLICITUDES_GUARDIA_DEVUELTAS`).

Quien puede cerrar una solicitud depende del rol, y el servidor lo valida
(`solicitud-guardia.reglas.ts`) aunque la app ya oculte los botones:

- Solo el guardia marca "en camino" y "resuelta", porque es quien atendio en terreno.
- Quien la pidio puede cancelarla con `POST /solicitudes-guardia/:id/cancelar` y un
  motivo obligatorio (3 a 200 caracteres); el guardia asignado recibe el aviso con el
  motivo y, si iba en camino, un push para no ir. En la app el formulario es una hoja
  inferior igual a la de "Solicitar atencion", con motivos frecuentes y "Otro motivo".
  La abre la pantalla (no la tarjeta) para que una recarga de la lista no la descarte, y
  sigue la solicitud en vivo: si el guardia va en camino o la solicitud se cierra
  mientras esta abierta, lo muestra y ya no deja cancelarla.
- Central y administracion pueden reenviar el aviso al guardia o cerrarla sin resolver
  con un motivo obligatorio, que tambien se avisa al guardia asignado. No pueden
  marcarla resuelta.

Cada solicitud cerrada guarda quien la cerro (`cerrada_por_usuario_id`) y el motivo
(`motivo_cierre`). La API entrega ademas `cerradaPor` (`SOLICITANTE`, `GUARDIA` o
`CENTRAL`) para que la app muestre "Cancelada por el solicitante" o "Cerrada por
central".

La app recibe estos cambios por Socket.IO (`core/servicios/tiempo_real_servicio.dart`).
El socket reintenta sin limite (espera de 1 a 5 s); si el servidor lo corta o lo
rechaza, por ejemplo al vencer el token de 2 h, la app renueva la sesion y se vuelve a
conectar, y un vigilante cada 15 s reconecta un socket que quedo detenido. Ademas, cada
pantalla con datos en vivo (incluidos el inicio y el selector del guardia y "Solicitar
atencion") usa `AutoRefrescoMixin`, que recarga cada 30 s (10 s sin socket) por si se
pierde un evento, y si una recarga falla conserva los datos que ya mostraba.

Incidencias:

```text
GET   /incidencias
POST  /incidencias
POST  /incidencias/:id/recordar
PATCH /incidencias/:id/estado
```

`POST /incidencias` acepta hasta 3 fotos de evidencia (JPG, PNG o WEBP).
`recordar` solo lo puede usar quien reporto la incidencia, con una espera de
5 minutos entre recordatorios. Al crear o recordar se notifica a ADMIN_CENTRAL y
ADMINISTRADOR (nunca al guardia ni a quien ejecuta la accion), y se envia correo
de respaldo. Al crear, quien reporta solo recibe el registro en sus notificaciones,
sin push. Cerrar una incidencia exige una respuesta, que se envia al reportante.

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

Cuando administracion crea o edita una cuenta, el correo debe corresponder al rol:
estudiante solo `@alumnos.ubiobio.cl`; funcionario, central y administrador solo
`@ubiobio.cl`; guardia cualquier correo valido, porque puede pertenecer a una empresa
externa. La regla se valida en el backend (`usuario.reglas.ts`) y en el formulario de la
app, y al editar solo se aplica si cambia el correo o el rol.

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
docker compose up -d db redis
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

Para emulador Android, Flutter usa por defecto `http://10.0.2.2:3000` cuando no se entrega `API_BASE_URL`. En el simulador de iOS usa `http://localhost:3000`. En dispositivo fisico se debe indicar la IP real del backend:

```bash
flutter run --dart-define=API_BASE_URL=http://IP_DEL_PC:3000
```

Builds de la app:

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://DOMINIO
flutter build ios --release --dart-define=API_BASE_URL=https://DOMINIO
```

El build de iOS requiere macOS con Xcode.

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
`npm run generate` regenera el cliente de Prisma y `docs/modelo-relacional.dbml`, y
corrige las reglas de borrado de las tablas con dos relaciones hacia `usuarios`.
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
apliquen de verdad, que la ocupacion se calcule sobre las filas reales y que
los botones de los enlaces de correo funcionen de punta a punta tal como los
envia el navegador del celular.

App movil:

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
- Incidencias con hasta 3 fotos de evidencia.
- Notificaciones por usuario y dispositivos registrados para push.
- Entregas pendientes de correo y push.
- Auditoria de acciones relevantes.

Los nombres de modelos, modulos y funciones del backend se mantienen en espanol cuando no chocan con convenciones propias de Node, Express o Prisma.
