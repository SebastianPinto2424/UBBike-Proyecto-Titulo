import { escaparHtml } from '../../comun/utilidades/html';

export const CORREO_SOPORTE = 'soporte@ubbike.cl';

const vistaPreviaHtml = (texto: string): string =>
  `<div style="display:none;max-height:0;overflow:hidden;opacity:0;mso-hide:all;">${escaparHtml(texto)}</div>`;

export const envolverHtml = (cuerpo: string, vistaPrevia?: string): string => `<!doctype html>
<html lang="es">
<head><meta charset="utf-8"></head>
<body style="font-family: Arial, sans-serif; color: #172033; margin: 0; padding: 0;">
${vistaPrevia ? vistaPreviaHtml(vistaPrevia) : ''}<div style="max-width:560px;margin:0 auto;padding:20px 16px;">
<p style="margin:0 0 4px;font-size:22px;font-weight:900;color:#014898;">UBBike</p>
${cuerpo}
</div>
</body>
</html>`;

export const primerNombre = (nombre: string): string => nombre.trim().split(/\s+/)[0] ?? '';

export const saludoTexto = (nombre?: string): string => {
  const primero = nombre ? primerNombre(nombre) : '';
  return primero ? `Hola, ${primero}:` : 'Hola:';
};

export const saludoHtml = (nombre?: string): string => `<p>${escaparHtml(saludoTexto(nombre))}</p>`;

export const enlaceRespaldo = (enlace: string): string =>
  `<p style="color:#6b7280;font-size:13px;margin:12px 0;">¿El botón no funciona? Copia y pega este enlace en el navegador:<br><a href="${escaparHtml(enlace)}" style="color:#014898;word-break:break-all;">${escaparHtml(enlace)}</a></p>`;

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

export const boton = (enlace: string, texto: string): string =>
  `<p style="margin:18px 0;"><a href="${escaparHtml(enlace)}" style="display:inline-block;background:#014898;color:#ffffff;text-decoration:none;padding:11px 22px;border-radius:8px;font-weight:bold;">${escaparHtml(texto)}</a></p>`;

const referenciaCorreo = (): string => {
  const fecha = new Date().toLocaleString('es-CL', {
    dateStyle: 'short',
    timeStyle: 'medium',
    hourCycle: 'h23',
    timeZone: 'America/Santiago'
  });
  const codigo = Math.random().toString(36).slice(2, 8);
  return `Correo enviado el ${fecha} · Ref ${codigo}`;
};

export const pieHtml = (opciones: { antiPhishing?: boolean } = {}): string => `
    <hr style="border:none;border-top:1px solid #e5e7eb;margin:18px 0;" />
    ${
      opciones.antiPhishing
        ? `<p style="color:#6b7280;font-size:13px;margin:4px 0;">Por seguridad, UBBike nunca te pedirá tu contraseña ni códigos por correo.</p>`
        : ''
    }
    <p style="color:#6b7280;font-size:13px;margin:4px 0;">¿Necesitas ayuda o no reconoces esta actividad? Escríbenos a <a href="mailto:${CORREO_SOPORTE}" style="color:#014898;">${CORREO_SOPORTE}</a>.</p>
    <p style="color:#172033;font-weight:bold;margin-top:10px;">Equipo UBBike</p>
    <p style="color:#9ca3af;font-size:11px;margin-top:8px;">${referenciaCorreo()}</p>`;

export const pieTexto = (opciones: { antiPhishing?: boolean } = {}): string =>
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
