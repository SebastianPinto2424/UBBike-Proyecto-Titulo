import nodemailer from 'nodemailer';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import type { ClientePrisma } from '../../configuracion/prisma';
import { encolarEntrega } from '../entregas/entrega.repositorio';
import { entorno } from '../../configuracion/entorno';

type AdjuntoCorreo = {
  filename: string;
  path: string;
  cid?: string;
};

export type DatosCorreo = {
  para: string;
  asunto: string;
  texto: string;
  html: string;
  adjuntos?: AdjuntoCorreo[];
  referencia?: string;
};

export type CorreoEncolado = Omit<DatosCorreo, 'adjuntos'> & {
  adjuntos?: Array<{ filename: string; content: string; encoding: string; cid?: string }>;
};

const CORREO_SOPORTE = 'soporte@ubbike.cl';

const escaparHtml = (valor: string): string =>
  valor
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const envolverHtml = (cuerpo: string): string => `<!doctype html>
<html lang="es">
<head><meta charset="utf-8"></head>
<body style="font-family: Arial, sans-serif; color: #172033; margin: 0; padding: 0;">
${cuerpo}
</body>
</html>`;

const fechaLegible = (fecha: Date = new Date()): string =>
  fecha.toLocaleString('es-CL', {
    dateStyle: 'long',
    timeStyle: 'short',
    timeZone: 'America/Santiago'
  });

const etiquetaRol = (rol?: string): string => {
  switch (rol) {
    case 'GUARDIA':
      return 'guardia';
    case 'FUNCIONARIO':
      return 'funcionario';
    case 'ESTUDIANTE':
      return 'estudiante';
    case 'ADMIN_CENTRAL':
      return 'administrador central';
    case 'ADMINISTRADOR':
      return 'administrador';
    default:
      return 'usuario';
  }
};

const capitalizar = (valor: string): string =>
  valor.length === 0 ? valor : valor.charAt(0).toUpperCase() + valor.slice(1);

const boton = (enlace: string, texto: string): string =>
  `<p style="margin:18px 0;"><a href="${escaparHtml(enlace)}" style="display:inline-block;background:#014898;color:#ffffff;text-decoration:none;padding:11px 22px;border-radius:8px;font-weight:bold;">${escaparHtml(texto)}</a></p>`;

const referenciaCorreo = (): string => {
  const fecha = new Date().toLocaleString('es-CL', {
    dateStyle: 'short',
    timeStyle: 'medium',
    timeZone: 'America/Santiago'
  });
  const codigo = Math.random().toString(36).slice(2, 8);
  return `Correo enviado el ${fecha} · Ref ${codigo}`;
};

const pieHtml = (opciones: { antiPhishing?: boolean } = {}): string => `
    <hr style="border:none;border-top:1px solid #e5e7eb;margin:18px 0;" />
    ${
      opciones.antiPhishing
        ? `<p style="color:#6b7280;font-size:13px;margin:4px 0;">Por seguridad, UBBike nunca te pedirá tu contraseña ni códigos por correo.</p>`
        : ''
    }
    <p style="color:#6b7280;font-size:13px;margin:4px 0;">¿Necesitas ayuda o no reconoces esta actividad? Escríbenos a <a href="mailto:${CORREO_SOPORTE}" style="color:#014898;">${CORREO_SOPORTE}</a>.</p>
    <p style="color:#172033;font-weight:bold;margin-top:10px;">Equipo UBBike</p>
    <p style="color:#9ca3af;font-size:11px;margin-top:8px;">${referenciaCorreo()}</p>`;

const pieTexto = (opciones: { antiPhishing?: boolean } = {}): string =>
  [
    '',
    opciones.antiPhishing
      ? 'Por seguridad, UBBike nunca te pedirá tu contraseña ni códigos por correo.'
      : '',
    `¿Necesitas ayuda o no reconoces esta actividad? Escríbenos a ${CORREO_SOPORTE}.`,
    'Equipo UBBike',
    referenciaCorreo()
  ]
    .filter((linea, indice) => linea !== '' || indice === 0)
    .join('\n');

const crearTransporte = () => {
  if (!entorno.correo.host) {
    return null;
  }

  const auth =
    entorno.correo.usuario && entorno.correo.contrasena
      ? {
          user: entorno.correo.usuario,
          pass: entorno.correo.contrasena
        }
      : undefined;

  return nodemailer.createTransport({
    host: entorno.correo.host,
    port: entorno.correo.puerto,
    secure: entorno.correo.seguro,
    auth,
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 30000,
    disableUrlAccess: true
  });
};

export const verificarConfiguracionCorreo = async (): Promise<boolean> => {
  const transporte = crearTransporte();

  if (!transporte) {
    return false;
  }

  await transporte.verify();
  return true;
};

export const enviarCorreo = async (datos: DatosCorreo, db?: ClientePrisma): Promise<void> => {
  const adjuntos = datos.adjuntos
    ? await Promise.all(
        datos.adjuntos.map(async (adjunto) => ({
          filename: adjunto.filename,
          cid: adjunto.cid,
          content: (await readFile(adjunto.path)).toString('base64'),
          encoding: 'base64'
        }))
      )
    : undefined;
  await encolarEntrega('CORREO', { ...datos, adjuntos }, db);
};

export const entregarCorreo = async (datos: CorreoEncolado, entregaId: string): Promise<void> => {
  const transporte = crearTransporte();

  if (!transporte) {
    if (entorno.ambiente === 'production') {
      throw new Error('SMTP_HOST debe estar configurado para enviar correos en produccion');
    }

    console.log('[correo-desarrollo]', {
      entregaId,
      aviso: 'SMTP no configurado; entrega simulada sin registrar enlaces ni datos personales'
    });
    return;
  }

  await transporte.sendMail({
    messageId: `<${entregaId}@ubbike.local>`,
    from: entorno.correo.remitente,
    to: datos.para,
    subject: datos.asunto,
    text: datos.texto,
    html: datos.html,
    attachments: datos.adjuntos,
    headers: { 'X-Entity-Ref-ID': datos.referencia ?? randomUUID() }
  });
};

export const crearCorreoVerificacion = (nombre: string, enlace: string) => ({
  asunto: 'Confirma tu correo para activar tu cuenta UBBike',
  texto: `Hola ${nombre}: confirma que este correo es tuyo para activar tu cuenta UBBike.
Abre este enlace (vence en 24 horas): ${enlace}
Si no creaste esta cuenta, ignora este mensaje: nadie podrá activarla sin este paso.
${pieTexto()}`,
  html: envolverHtml(`
    <h2 style="color: #014898;">Confirma tu correo</h2>
    <p>Hola ${escaparHtml(nombre)},</p>
    <p>Recibimos el registro de esta cuenta. Confirma que este correo es tuyo para activarla.</p>
    ${boton(enlace, 'Confirmar mi correo')}
    <p>El enlace vence en <strong>24 horas</strong>. Si no creaste esta cuenta, ignóralo: nadie podrá activarla sin este paso.</p>
    ${pieHtml()}
  `)
});

export const crearCorreoCompletarRegistro = (correoUsuario: string, enlace: string) => ({
  asunto: 'Activa tu cuenta UBBike para gestionar tu bicicleta',
  texto: `Hola: un guardia registró un movimiento de tu bicicleta el ${fechaLegible()}, pero esta cuenta (${correoUsuario}) aún no está activa.
Actívala para ver tu historial y generar tus códigos QR (enlace vence en 24 horas): ${enlace}
Si no reconoces este movimiento, escríbenos a ${CORREO_SOPORTE}.
${pieTexto()}`,
  html: envolverHtml(`
    <h2 style="color: #014898;">Activa tu cuenta UBBike</h2>
    <p>Hola,</p>
    <p>Un guardia registró un movimiento de tu bicicleta el <strong>${escaparHtml(fechaLegible())}</strong>, pero esta cuenta aún no está activa.</p>
    <p>Actívala para ver tu historial y generar tus códigos QR.</p>
    ${boton(enlace, 'Activar mi cuenta')}
    <p>El enlace vence en <strong>24 horas</strong>. Si no reconoces este movimiento, contáctanos.</p>
    ${pieHtml()}
  `)
});

export const crearCorreoCuentaVerificada = (nombre: string) => {
  const fecha = fechaLegible();
  return {
    asunto: 'Tu cuenta UBBike ya está activa',
    texto: `Hola ${nombre}: confirmamos tu correo y activamos tu cuenta el ${fecha}. Ya puedes iniciar sesión y registrar tus bicicletas.
Si no fuiste tú, escríbenos a ${CORREO_SOPORTE}.
${pieTexto()}`,
    html: envolverHtml(`
    <h2 style="color: #014898;">Tu cuenta ya está activa</h2>
    <p>Hola ${escaparHtml(nombre)},</p>
    <p>Confirmamos tu correo y activamos tu cuenta el <strong>${escaparHtml(fecha)}</strong>. Ya puedes iniciar sesión y registrar tus bicicletas.</p>
    ${pieHtml()}
  `)
  };
};

export const crearCorreoCuentaAdministrativa = (
  nombre: string,
  enlace: string,
  horasExpiracion: number,
  rol?: string
) => {
  const rolTexto = etiquetaRol(rol);
  const fecha = fechaLegible();
  return {
    asunto: `Te damos la bienvenida a UBBike — activa tu cuenta de ${rolTexto}`,
    texto: `Hola ${nombre}: administración creó una cuenta de ${rolTexto} para ti el ${fecha}.
Crea tu propia contraseña (nunca te enviamos una). Es tu primer ingreso, no un cambio de contraseña.
Enlace de un solo uso, vence en ${horasExpiracion} horas: ${enlace}
${pieTexto({ antiPhishing: true })}`,
    html: envolverHtml(`
    <h2 style="color: #014898;">Te damos la bienvenida a UBBike</h2>
    <p>Hola ${escaparHtml(nombre)},</p>
    <p>Administración creó una cuenta de <strong>${escaparHtml(rolTexto)}</strong> para ti el <strong>${escaparHtml(fecha)}</strong>.</p>
    <p>Para empezar, <strong>crea tu propia contraseña</strong> (nunca te enviamos una). Es tu primer ingreso, no un cambio de contraseña.</p>
    ${boton(enlace, 'Crear mi contraseña')}
    <p>El enlace es de <strong>un solo uso</strong> y vence en ${horasExpiracion} horas.</p>
    ${pieHtml({ antiPhishing: true })}
  `)
  };
};

export const crearCorreoCuentaDesactivada = (nombre: string) => {
  const fecha = fechaLegible();
  return {
    asunto: 'Alerta de seguridad: tu cuenta UBBike fue desactivada',
    texto: `Hola ${nombre}: tu cuenta UBBike fue desactivada el ${fecha}. No podrás iniciar sesión mientras siga así.
Si no esperabas esto, escríbenos de inmediato a ${CORREO_SOPORTE}.
${pieTexto()}`,
    html: envolverHtml(`
    <h2 style="color: #014898;">Tu cuenta fue desactivada</h2>
    <p>Hola ${escaparHtml(nombre)},</p>
    <p>Tu cuenta UBBike fue desactivada el <strong>${escaparHtml(fecha)}</strong>. No podrás iniciar sesión mientras siga así.</p>
    <p>Si no esperabas esto, contáctanos de inmediato.</p>
    ${pieHtml()}
  `)
  };
};

export const crearCorreoCuentaReactivada = (nombre: string) => {
  const fecha = fechaLegible();
  return {
    asunto: 'Tu cuenta UBBike fue reactivada',
    texto: `Hola ${nombre}: administración reactivó tu cuenta el ${fecha}. Ya puedes iniciar sesión con tu contraseña habitual.
Si no reconoces esta acción, escríbenos a ${CORREO_SOPORTE}.
${pieTexto()}`,
    html: envolverHtml(`
    <h2 style="color: #014898;">Tu cuenta fue reactivada</h2>
    <p>Hola ${escaparHtml(nombre)},</p>
    <p>Administración reactivó tu cuenta el <strong>${escaparHtml(fecha)}</strong>. Ya puedes iniciar sesión con tu contraseña habitual.</p>
    <p>Si no reconoces esta acción, contáctanos.</p>
    ${pieHtml()}
  `)
  };
};

export const crearCorreoRolActualizado = (
  nombre: string,
  rolAnterior: string,
  rolNuevo: string
) => {
  const fecha = fechaLegible();
  const antes = capitalizar(etiquetaRol(rolAnterior));
  const ahora = capitalizar(etiquetaRol(rolNuevo));
  return {
    asunto: `Alerta de seguridad: tu rol en UBBike cambió a ${ahora}`,
    texto: `Hola ${nombre}: administración cambió tu rol el ${fecha}.
Antes: ${antes} — Ahora: ${ahora}.
Esto modifica tus permisos dentro de la app. Si no reconoces este cambio, escríbenos de inmediato a ${CORREO_SOPORTE}.
${pieTexto()}`,
    html: envolverHtml(`
    <h2 style="color: #014898;">Tu rol cambió</h2>
    <p>Hola ${escaparHtml(nombre)},</p>
    <p>Administración cambió tu rol el <strong>${escaparHtml(fecha)}</strong>.</p>
    <ul>
      <li><strong>Antes:</strong> ${escaparHtml(antes)}</li>
      <li><strong>Ahora:</strong> ${escaparHtml(ahora)}</li>
    </ul>
    <p>Esto modifica tus permisos dentro de la app. Si no reconoces este cambio, contáctanos de inmediato.</p>
    ${pieHtml()}
  `)
  };
};

export const crearCorreoCambioContrasena = (nombre: string, enlace: string) => {
  const fecha = fechaLegible();
  return {
    asunto: 'Restablece tu contraseña de UBBike',
    texto: `Hola ${nombre}: recibimos una solicitud para restablecer la contraseña de esta cuenta el ${fecha}.
Si fuiste tú, crea una nueva (enlace de un solo uso, vence en 30 minutos): ${enlace}
Este enlace reemplaza cualquier enlace de restablecimiento enviado antes.
Si no lo solicitaste, ignora este correo: tu contraseña no ha cambiado.
${pieTexto({ antiPhishing: true })}`,
    html: envolverHtml(`
    <h2 style="color: #014898;">Restablece tu contraseña</h2>
    <p>Hola ${escaparHtml(nombre)},</p>
    <p>Recibimos una solicitud para restablecer la contraseña de esta cuenta el <strong>${escaparHtml(fecha)}</strong>.</p>
    ${boton(enlace, 'Restablecer contraseña')}
    <p>El enlace es de <strong>un solo uso</strong> y vence en <strong>30 minutos</strong>. Reemplaza cualquier enlace de restablecimiento enviado antes, así que usa siempre el correo más reciente.</p>
    <p>Si no lo solicitaste, ignora este correo: <strong>tu contraseña no ha cambiado</strong>.</p>
    ${pieHtml({ antiPhishing: true })}
  `)
  };
};

export const crearCorreoContrasenaActualizada = (nombre: string) => {
  const fecha = fechaLegible();
  return {
    asunto: 'Alerta de seguridad: tu contraseña de UBBike fue cambiada',
    texto: `Hola ${nombre}: tu contraseña UBBike se cambió correctamente el ${fecha}.
¿No fuiste tú? Tu cuenta podría estar en riesgo: restablece tu contraseña de inmediato y escríbenos a ${CORREO_SOPORTE}.
${pieTexto({ antiPhishing: true })}`,
    html: envolverHtml(`
    <h2 style="color: #014898;">Tu contraseña fue cambiada</h2>
    <p>Hola ${escaparHtml(nombre)},</p>
    <p>Tu contraseña UBBike se cambió correctamente el <strong>${escaparHtml(fecha)}</strong>.</p>
    <p><strong>¿No fuiste tú?</strong> Tu cuenta podría estar en riesgo. Restablece tu contraseña de inmediato y escríbenos a
       <a href="mailto:${CORREO_SOPORTE}" style="color:#014898;">${CORREO_SOPORTE}</a>.</p>
    ${pieHtml({ antiPhishing: true })}
  `)
  };
};

export const crearCorreoCuentaActivada = (nombre: string, rol?: string) => {
  const rolTexto = etiquetaRol(rol);
  const fecha = fechaLegible();
  return {
    asunto: `Tu cuenta de ${rolTexto} en UBBike quedó activa`,
    texto: `Hola ${nombre}: creaste tu contraseña y tu cuenta de ${rolTexto} quedó activa el ${fecha}.
Ya puedes iniciar sesión en la app UBBike con tu correo institucional.
Si no fuiste tú quien activó esta cuenta, escríbenos a ${CORREO_SOPORTE}.
${pieTexto({ antiPhishing: true })}`,
    html: envolverHtml(`
    <h2 style="color: #014898;">¡Cuenta activada!</h2>
    <p>Hola ${escaparHtml(nombre)},</p>
    <p>Creaste tu contraseña y tu cuenta de <strong>${escaparHtml(rolTexto)}</strong> quedó activa el <strong>${escaparHtml(fecha)}</strong>.</p>
    <p>Ya puedes iniciar sesión en la app UBBike con tu correo institucional.</p>
    <p>Si no fuiste tú quien activó esta cuenta, escríbenos a
       <a href="mailto:${CORREO_SOPORTE}" style="color:#014898;">${CORREO_SOPORTE}</a>.</p>
    ${pieHtml({ antiPhishing: true })}
  `)
  };
};

type DatosCorreoMovimiento = {
  nombre: string;
  tipo: string;
  estado: string;
  origen: string;
  bicicleta: string;
  marca?: string | null;
  modelo?: string | null;
  color?: string | null;
  aro?: string | null;
  numeroSerie?: string | null;
  bicicletero: string;
  guardia: string;
  fecha: Date;
  motivoDenegacion?: string | null;
  comentarioGuardia?: string | null;
  fotoCid?: string | null;
};

const etiquetaMovimiento = (tipo: string) => (tipo === 'INGRESO' ? 'Ingreso' : 'Retiro');

const etiquetaEstadoMovimiento = (estado: string) =>
  estado === 'CONFIRMADO' ? 'confirmado' : 'denegado';

const etiquetaOrigenMovimiento = (origen: string) =>
  origen === 'MANUAL' ? 'manual' : 'por código QR';

export const crearCorreoMovimiento = (datos: DatosCorreoMovimiento) => {
  const tipo = etiquetaMovimiento(datos.tipo);
  const estado = etiquetaEstadoMovimiento(datos.estado);
  const origen = etiquetaOrigenMovimiento(datos.origen);
  const fecha = datos.fecha.toLocaleString('es-CL', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'America/Santiago'
  });
  const motivo = datos.motivoDenegacion ? `Motivo de denegación: ${datos.motivoDenegacion}` : '';
  const comentario = datos.comentarioGuardia
    ? `Comentario del guardia: ${datos.comentarioGuardia}`
    : '';

  const valorDetalle = (valor?: string | null) => {
    const texto = valor?.trim();
    return texto && texto.length > 0 ? texto : 'No informado';
  };

  const detalleBicicleta: Array<[string, string | null | undefined]> = [
    ['Descripción', datos.bicicleta],
    ['Marca', datos.marca],
    ['Modelo', datos.modelo],
    ['Color', datos.color],
    ['Aro', datos.aro],
    ['Número de serie', datos.numeroSerie]
  ];
  const textoBicicleta = detalleBicicleta
    .map(([etiqueta, valor]) => `  - ${etiqueta}: ${valorDetalle(valor)}`)
    .join('\n');
  const htmlBicicleta = detalleBicicleta
    .map(
      ([etiqueta, valor]) =>
        `<li><strong>${etiqueta}:</strong> ${escaparHtml(valorDetalle(valor))}</li>`
    )
    .join('');
  const htmlFoto = datos.fotoCid
    ? `<p style="margin-top:8px;"><strong>Foto de la bicicleta:</strong></p>
       <img src="cid:${datos.fotoCid}" alt="Foto de la bicicleta"
            style="max-width:320px; width:100%; border-radius:8px; border:1px solid #e5e7eb;" />`
    : '';

  return {
    asunto: `${tipo} ${estado}: ${datos.bicicleta} en UBBike`,
    texto: [
      `Hola ${datos.nombre}.`,
      `Registramos un ${tipo.toLowerCase()} ${origen} ${estado} el ${fecha}.`,
      `Bicicletero: ${datos.bicicletero}.`,
      `Guardia: ${datos.guardia}.`,
      'Datos de tu bicicleta:',
      textoBicicleta,
      datos.fotoCid ? '(La foto de la bicicleta se adjunta en este correo.)' : '',
      motivo,
      comentario,
      pieTexto()
    ]
      .filter(Boolean)
      .join('\n'),
    html: envolverHtml(`
      <h2 style="color: #014898;">${tipo} ${origen} ${estado}</h2>
      <p>Hola ${escaparHtml(datos.nombre)},</p>
      <p>Registramos un <strong>${escaparHtml(tipo.toLowerCase())}</strong> ${origen} de tu bicicleta el <strong>${escaparHtml(fecha)}</strong>.</p>
      <ul>
        <li><strong>Operación:</strong> ${tipo}</li>
        <li><strong>Resultado:</strong> ${estado}</li>
        <li><strong>Origen:</strong> ${origen}</li>
        <li><strong>Bicicletero:</strong> ${escaparHtml(datos.bicicletero)}</li>
        <li><strong>Guardia:</strong> ${escaparHtml(datos.guardia)}</li>
        ${
          datos.motivoDenegacion
            ? `<li><strong>Motivo:</strong> ${escaparHtml(datos.motivoDenegacion)}</li>`
            : ''
        }
        ${
          datos.comentarioGuardia
            ? `<li><strong>Comentario del guardia:</strong> ${escaparHtml(datos.comentarioGuardia)}</li>`
            : ''
        }
      </ul>
      <h3 style="color: #014898; margin-bottom:4px;">Datos de tu bicicleta</h3>
      <p style="color:#6b7280;font-size:13px;margin:0 0 6px;">Verifica que corresponde a tu bicicleta:</p>
      <ul>${htmlBicicleta}</ul>
      ${htmlFoto}
      ${pieHtml()}
    `)
  };
};

export const crearCorreoMovimientoManual = crearCorreoMovimiento;

type DatosCorreoIncidenciaNueva = {
  nombreDestinatario: string;
  tipo: string;
  bicicletero: string;
  descripcion: string;
  reportadaPor: string;
  fecha: Date;
  recordatorio?: boolean;
};

export const crearCorreoIncidenciaNueva = (datos: DatosCorreoIncidenciaNueva) => {
  const fecha = datos.fecha.toLocaleString('es-CL', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'America/Santiago'
  });
  const titulo = datos.recordatorio
    ? 'Recordatorio: incidencia sin atender'
    : 'Nueva incidencia reportada';
  const intro = datos.recordatorio
    ? 'Este reporte operativo sigue pendiente de revisión.'
    : 'Hay un reporte operativo pendiente de revisión.';

  return {
    asunto: `${datos.recordatorio ? 'Recordatorio: incidencia' : 'Nueva incidencia'} en ${datos.bicicletero} · UBBike`,
    texto: `Hola ${datos.nombreDestinatario}: ${intro}
Tipo: ${datos.tipo}.
Bicicletero: ${datos.bicicletero}.
Reportada por: ${datos.reportadaPor}.
Fecha: ${fecha}.
Descripción: ${datos.descripcion}
${pieTexto()}`,
    html: envolverHtml(`
      <h2 style="color: #014898;">${titulo}</h2>
      <p>Hola ${escaparHtml(datos.nombreDestinatario)},</p>
      <p>${intro}</p>
      <ul>
        <li><strong>Tipo:</strong> ${escaparHtml(datos.tipo)}</li>
        <li><strong>Bicicletero:</strong> ${escaparHtml(datos.bicicletero)}</li>
        <li><strong>Reportada por:</strong> ${escaparHtml(datos.reportadaPor)}</li>
        <li><strong>Fecha:</strong> ${escaparHtml(fecha)}</li>
      </ul>
      <p><strong>Descripción:</strong> ${escaparHtml(datos.descripcion)}</p>
      ${pieHtml()}
    `)
  };
};

type DatosCorreoIncidenciaResuelta = {
  nombre: string;
  tipo: string;
  bicicletero: string;
  estado: string;
  respuesta: string;
  fecha: Date;
};

export const crearCorreoIncidenciaResuelta = (datos: DatosCorreoIncidenciaResuelta) => {
  const fecha = datos.fecha.toLocaleString('es-CL', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'America/Santiago'
  });

  return {
    asunto: `Tu incidencia en ${datos.bicicletero} quedó ${datos.estado.toLowerCase()} · UBBike`,
    texto: `Hola ${datos.nombre}: tu reporte en ${datos.bicicletero} quedó ${datos.estado.toLowerCase()} el ${fecha}.
Tipo: ${datos.tipo}.
Respuesta: ${datos.respuesta}
${pieTexto()}`,
    html: envolverHtml(`
      <h2 style="color: #014898;">Tu incidencia quedó ${escaparHtml(datos.estado.toLowerCase())}</h2>
      <p>Hola ${escaparHtml(datos.nombre)},</p>
      <p>Tu reporte en <strong>${escaparHtml(datos.bicicletero)}</strong> quedó <strong>${escaparHtml(datos.estado.toLowerCase())}</strong> el <strong>${escaparHtml(fecha)}</strong>.</p>
      <ul>
        <li><strong>Tipo:</strong> ${escaparHtml(datos.tipo)}</li>
      </ul>
      <p><strong>Respuesta:</strong> ${escaparHtml(datos.respuesta)}</p>
      ${pieHtml()}
    `)
  };
};
