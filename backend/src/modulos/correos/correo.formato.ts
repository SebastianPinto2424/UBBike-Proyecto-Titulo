import { escaparHtml } from '../../comun/utilidades/html';
import { entorno } from '../../configuracion/entorno';

export const CORREO_SOPORTE = entorno.correo.soporte;

const vistaPreviaHtml = (texto: string): string =>
  `<div style="display:none;max-height:0;overflow:hidden;opacity:0;mso-hide:all;">${escaparHtml(texto)}</div>`;

export const envolverHtml = (cuerpo: string, vistaPrevia?: string): string => `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="x-apple-disable-message-reformatting">
</head>
<body style="margin:0;padding:0;background:#ffffff;">
${vistaPrevia ? vistaPreviaHtml(vistaPrevia) : ''}<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
<tr>
<td align="center" style="padding:20px 16px;">
<!--[if mso]><table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0"><tr><td><![endif]-->
<div style="max-width:600px;margin:0 auto;text-align:left;font-family:Arial,sans-serif;font-size:15px;line-height:1.5;color:#172033;">
<p style="margin:0 0 4px;font-size:22px;font-weight:900;color:#014898;">UBBike</p>
${cuerpo}
</div>
<!--[if mso]></td></tr></table><![endif]-->
</td>
</tr>
</table>
</body>
</html>`;

export const primerNombre = (nombre: string): string => nombre.trim().split(/\s+/)[0] ?? '';

export const saludoTexto = (nombre?: string): string => {
  const primero = nombre ? primerNombre(nombre) : '';
  return primero ? `Hola, ${primero}:` : 'Hola:';
};

export const saludoHtml = (nombre?: string): string => `<p>${escaparHtml(saludoTexto(nombre))}</p>`;

export const fechaLegible = (fecha: Date = new Date()): string =>
  fecha.toLocaleString('es-CL', {
    dateStyle: 'long',
    timeStyle: 'short',
    hourCycle: 'h23',
    timeZone: 'America/Santiago'
  });

export const etiquetaRol = (rol?: string): string => {
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

export const capitalizar = (valor: string): string =>
  valor.length === 0 ? valor : valor.charAt(0).toUpperCase() + valor.slice(1);

export const usaBicicleta = (rol?: string): boolean =>
  !rol || rol === 'ESTUDIANTE' || rol === 'FUNCIONARIO';

export const propositoCuenta = (rol?: string): string => {
  switch (rol) {
    case 'GUARDIA':
      return 'validar los códigos QR y registrar los ingresos y retiros de bicicletas';
    case 'ADMIN_CENTRAL':
      return 'supervisar los bicicleteros y atender las solicitudes y las incidencias';
    case 'ADMINISTRADOR':
      return 'administrar las cuentas, los bicicleteros y la operación de UBBike';
    default:
      return 'dejar y retirar tu bicicleta en los bicicleteros de la universidad';
  }
};

export const boton = (enlace: string, texto: string): string =>
  `<table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin:20px 0;"><tr><td bgcolor="#014898" style="border-radius:8px;"><a href="${escaparHtml(enlace)}" style="display:inline-block;padding:12px 24px;font-family:Arial,sans-serif;font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none;border-radius:8px;">${escaparHtml(texto)}</a></td></tr></table>`;

const avisoSeguridad = 'Por seguridad, UBBike nunca te pedirá tu contraseña ni códigos por correo.';

const motivoCorreo =
  'Recibiste este correo porque esta dirección está asociada a una cuenta de UBBike.';

export const pieHtml = (opciones: { antiPhishing?: boolean } = {}): string => `
    <p style="margin:22px 0 0;">Saludos cordiales,<br /><strong>Equipo UBBike</strong></p>
    <hr style="border:none;border-top:1px solid #e5e7eb;margin:22px 0 14px;" />
    ${
      opciones.antiPhishing
        ? `<p style="color:#6b7280;font-size:13px;margin:4px 0;">${avisoSeguridad}</p>`
        : ''
    }
    <p style="color:#6b7280;font-size:13px;margin:4px 0;">¿Necesitas ayuda o no reconoces esta actividad? Escríbenos a <a href="mailto:${escaparHtml(CORREO_SOPORTE)}" style="color:#014898;">${escaparHtml(CORREO_SOPORTE)}</a>.</p>
    <p style="color:#6b7280;font-size:13px;margin:4px 0;">${motivoCorreo}</p>`;

export const pieTexto = (opciones: { antiPhishing?: boolean } = {}): string =>
  [
    '',
    'Saludos cordiales,',
    'Equipo UBBike',
    '',
    ...(opciones.antiPhishing ? [avisoSeguridad] : []),
    `¿Necesitas ayuda o no reconoces esta actividad? Escríbenos a ${CORREO_SOPORTE}.`,
    motivoCorreo
  ].join('\n');
