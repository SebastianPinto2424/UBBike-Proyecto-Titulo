# Modelo Relacional UBBike

Este documento resume el MR del sistema. La fuente técnica del esquema está en
`backend/prisma/schema.prisma`, con migraciones versionadas en
`backend/prisma/migrations`.

## Diagrama ER

```mermaid
erDiagram
  USUARIOS ||--o{ BICICLETAS : registra
  USUARIOS ||--o{ MOVIMIENTOS : realiza
  USUARIOS ||--o{ MOVIMIENTOS : valida_como_guardia
  USUARIOS ||--o{ ASIGNACIONES_GUARDIAS : tiene
  USUARIOS ||--o{ SOLICITUDES_GUARDIA : solicita
  USUARIOS ||--o{ SOLICITUDES_GUARDIA : atiende
  USUARIOS ||--o{ CODIGOS_QR_TEMPORALES : escanea_como_guardia
  USUARIOS ||--o{ NOTIFICACIONES : recibe
  USUARIOS ||--o{ INCIDENCIAS : reporta
  USUARIOS ||--o{ INCIDENCIAS : gestiona
  USUARIOS ||--o{ AUDITORIA_EVENTOS : ejecuta

  BICICLETAS ||--o{ MOVIMIENTOS : genera
  BICICLETAS ||--o{ CODIGOS_QR_TEMPORALES : usa
  BICICLETAS ||--o{ INCIDENCIAS : asociada

  BICICLETEROS ||--o{ MOVIMIENTOS : registra
  BICICLETEROS ||--o{ CODIGOS_QR_TEMPORALES : destino
  BICICLETEROS ||--o{ ASIGNACIONES_GUARDIAS : asigna
  BICICLETEROS ||--o{ SOLICITUDES_GUARDIA : recibe
  BICICLETEROS ||--o{ INCIDENCIAS : contiene

  USUARIOS {
    uuid id PK
    varchar nombre
    varchar correo UK
    varchar rut UK
    enum rol
    varchar contrasena_hash
    boolean correo_verificado
    boolean registro_parcial
    boolean cuenta_activa
    integer version_sesion
    varchar token_verificacion_correo
    timestamptz token_verificacion_correo_expira_en
    varchar token_cambio_contrasena
    timestamptz token_cambio_contrasena_expira_en
    timestamptz creado_en
    timestamptz actualizado_en
  }

  BICICLETAS {
    uuid id PK
    uuid usuario_id FK
    uuid bicicletero_actual_id FK
    varchar descripcion
    varchar marca
    varchar modelo
    varchar color
    varchar aro
    varchar numero_serie
    text foto_url
    varchar foto_nombre_archivo
    varchar foto_mime_type
    integer foto_tamano_bytes
    timestamptz foto_actualizada_en
    boolean activa
    boolean dentro_bicicletero
    timestamptz creado_en
    timestamptz actualizado_en
    timestamptz eliminado_en
  }

  BICICLETEROS {
    uuid id PK
    varchar nombre UK
    varchar ubicacion
    float latitud
    float longitud
    integer capacidad
    boolean activo
    timestamptz creado_en
    timestamptz actualizado_en
  }

  ASIGNACIONES_GUARDIAS {
    uuid id PK
    uuid guardia_id FK
    uuid bicicletero_id FK
    timestamptz inicia_en
    timestamptz termina_en
    boolean activa
    timestamptz creada_en
    timestamptz actualizada_en
  }

  SOLICITUDES_GUARDIA {
    uuid id PK
    uuid solicitada_por_usuario_id FK
    uuid bicicletero_id FK
    uuid guardia_asignado_id FK
    enum tipo
    enum estado
    text mensaje
    timestamptz notificada_guardia_en
    timestamptz ultima_notificacion_usuario_en
    integer notificaciones_guardia
    timestamptz respondida_por_guardia_en
    timestamptz en_camino_en
    timestamptz resuelta_en
    timestamptz creada_en
    timestamptz actualizada_en
  }

  MOVIMIENTOS {
    uuid id PK
    uuid bicicleta_id FK
    uuid usuario_id FK
    uuid bicicletero_id FK
    uuid validado_por_guardia_id FK
    enum tipo
    enum estado
    text motivo_denegacion
    text comentario_guardia
    enum origen
    timestamptz creado_en
  }

  CODIGOS_QR_TEMPORALES {
    uuid id PK
    varchar token UK
    uuid usuario_id FK
    uuid bicicleta_id FK
    uuid bicicletero_id FK
    uuid escaneado_por_guardia_id FK
    enum tipo
    timestamptz expira_en
    boolean usado
    timestamptz escaneado_en
    timestamptz creado_en
  }

  NOTIFICACIONES {
    uuid id PK
    uuid usuario_id FK
    varchar titulo
    text mensaje
    enum tipo
    boolean leida
    jsonb datos
    timestamptz creada_en
  }

  INCIDENCIAS {
    uuid id PK
    uuid reportada_por_usuario_id FK
    uuid bicicletero_id FK
    uuid bicicleta_id FK
    uuid gestionada_por_usuario_id FK
    enum tipo
    text descripcion
    enum estado
    text respuesta
    timestamptz resuelta_en
    timestamptz creada_en
    timestamptz actualizada_en
  }

  AUDITORIA_EVENTOS {
    uuid id PK
    uuid actor_usuario_id FK
    varchar accion
    varchar entidad
    varchar entidad_id
    varchar ip
    text user_agent
    jsonb datos
    timestamptz creado_en
  }

  ENTREGAS_PENDIENTES {
    uuid id PK
    varchar tipo
    jsonb datos
    integer intentos
    timestamptz disponible_en
    timestamptz creada_en
    timestamptz entregada_en
    boolean agotada
  }
```

## Reglas Principales

- Un usuario puede tener muchas bicicletas, pero solo una debe estar activa. La
  base de datos refuerza esta regla con un índice único parcial sobre
  `usuario_id` cuando `activa = true` y `eliminado_en IS NULL`.
- Cada QR temporal pertenece a un usuario, una bicicleta y opcionalmente a un
  bicicletero. Cuando el guardia lo escanea, se registra
  `escaneado_por_guardia_id` y `escaneado_en`.
- Cada movimiento guarda usuario, bicicleta, bicicletero y guardia que valida.
  El tipo usa `INGRESO` o `RETIRO`, y el origen usa `QR` o `MANUAL`.
- El estado real de una bicicleta se guarda en `dentro_bicicletero` y
  `bicicletero_actual_id`.
- Un bicicletero puede tener `latitud`/`longitud` opcionales. Cuando están
  cargadas, la app usa la ubicación GPS del usuario para sugerir el
  bicicletero más cercano dentro de un radio configurable.
- La foto de una bicicleta se modela como atributo de `bicicletas`, porque el
  sistema requiere una sola foto principal por bicicleta. El archivo se guarda
  fuera de la base de datos y en la tabla se persisten URL y metadatos.
- Un retiro solo puede registrarse en el mismo bicicletero donde la bicicleta
  ingresó: `bicicletero_actual_id` debe coincidir con el bicicletero de la
  operación, tanto por QR como en gestión manual.
- Una bicicleta no puede eliminarse mientras `dentro_bicicletero` sea verdadero,
  y un bicicletero no puede desactivarse mientras tenga bicicletas dentro. Así
  la ocupación calculada nunca se desvía de la realidad física.
- Las solicitudes de guardia registran quién pidió ayuda, en qué bicicletero,
  qué guardia fue asignado, cuántas veces se notificó, cuándo respondió el
  guardia y cuándo quedó en camino o resuelta. Si central cierra una solicitud
  sin que el guardia responda, el motivo queda en `nota_cierre_central`.
- Las incidencias registran problemas operativos del bicicletero, bicicleta, QR,
  movimientos o datos de usuario. Cualquier actor autenticado puede reportar.
  Los guardias pueden ver las incidencias asociadas a su bicicletero asignado,
  pero el cambio formal de estado queda reservado a administración/central.
  Para cerrar una incidencia como `RESUELTA` o `DESCARTADA`, se debe registrar
  una respuesta de gestión, que se notifica y envía por correo al reportante.
- Quien reporta una incidencia puede insistir con un recordatorio hacia
  administración. `ultimo_recordatorio_en` y `recordatorios` sostienen esa
  función: guardan cuándo se envió el último aviso y cuántos van, con una espera
  mínima de 5 minutos entre uno y otro.
- Los eventos críticos quedan registrados en `auditoria_eventos` para
  trazabilidad operativa y revisión posterior.
- `entregas_pendientes` conserva los trabajos de correo y push hasta que un
  worker los procesa. Los avisos de incidencias y movimientos se encolan en la
  misma transacción del negocio. La entrega admite reintentos y posibles
  duplicados; no garantiza exactamente un envío. El contenido se borra al
  completar o agotar los intentos, y los metadatos permanecen para seguimiento.

## Enumeraciones

- `RolUsuario`: `ESTUDIANTE`, `FUNCIONARIO`, `GUARDIA`, `ADMIN_CENTRAL`,
  `ADMINISTRADOR`.
- `TipoMovimiento`: `INGRESO`, `RETIRO`.
- `TipoCodigoQrTemporal`: `INGRESO`, `RETIRO`.
- `TipoOrigenMovimiento`: `QR`, `MANUAL`.
- `EstadoMovimiento`: `CONFIRMADO`, `DENEGADO`.
- `TipoSolicitudGuardia`: `GUARDIA_AUSENTE`, `REQUIERE_SERVICIO`.
- `EstadoSolicitudGuardia`: `PENDIENTE`, `NOTIFICADA`, `EN_CAMINO`,
  `RESUELTA`, `CANCELADA`.
- `TipoIncidencia`: `PROBLEMA_QR`, `DANO_BICICLETA`, `DANO_INFRAESTRUCTURA`,
  `PROBLEMA_MOVIMIENTO`, `USUARIO_DATOS`, `OTRO`.
- `EstadoIncidencia`: `PENDIENTE`, `EN_REVISION`, `RESUELTA`, `DESCARTADA`.
- `TipoNotificacion`: `SISTEMA`, `CUENTA`, `SEGURIDAD`, `SOLICITUD_GUARDIA`,
  `MOVIMIENTO`, `INCIDENCIA`.

## Generación Automática Del Diagrama

El archivo `docs/modelo-relacional.dbml` se genera automáticamente desde
`backend/prisma/schema.prisma` mediante `prisma-dbml-generator`. Este archivo no
debe editarse manualmente, porque representa el modelo actual definido en
Prisma.

Para regenerar el diagrama:

```bash
cd backend
npm run generate
```

Luego se puede abrir `docs/modelo-relacional.dbml` con una extensión DBML en VS
Code o pegar su contenido en `https://dbdiagram.io/` para exportarlo como imagen
o PDF e incluirlo en el informe.
