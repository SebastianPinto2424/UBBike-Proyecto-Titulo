import { escaparHtml } from '../../comun/utilidades/html';
import { envolverHtml, pieHtml, pieTexto, saludoHtml, saludoTexto } from './correo.formato';

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
    hourCycle: 'h23',
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
      `${saludoTexto(datos.nombre)}\n`,
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
      ${saludoHtml(datos.nombre)}
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
    hourCycle: 'h23',
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
    texto: `${saludoTexto(datos.nombreDestinatario)}

${intro}
Tipo: ${datos.tipo}.
Bicicletero: ${datos.bicicletero}.
Reportada por: ${datos.reportadaPor}.
Fecha: ${fecha}.
Descripción: ${datos.descripcion}
${pieTexto()}`,
    html: envolverHtml(`
      <h2 style="color: #014898;">${titulo}</h2>
      ${saludoHtml(datos.nombreDestinatario)}
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
    hourCycle: 'h23',
    timeZone: 'America/Santiago'
  });

  return {
    asunto: `Tu incidencia en ${datos.bicicletero} quedó ${datos.estado.toLowerCase()} · UBBike`,
    texto: `${saludoTexto(datos.nombre)}

Tu reporte en ${datos.bicicletero} quedó ${datos.estado.toLowerCase()} el ${fecha}.
Tipo: ${datos.tipo}.
Respuesta: ${datos.respuesta}
${pieTexto()}`,
    html: envolverHtml(`
      <h2 style="color: #014898;">Tu incidencia quedó ${escaparHtml(datos.estado.toLowerCase())}</h2>
      ${saludoHtml(datos.nombre)}
      <p>Tu reporte en <strong>${escaparHtml(datos.bicicletero)}</strong> quedó <strong>${escaparHtml(datos.estado.toLowerCase())}</strong> el <strong>${escaparHtml(fecha)}</strong>.</p>
      <ul>
        <li><strong>Tipo:</strong> ${escaparHtml(datos.tipo)}</li>
      </ul>
      <p><strong>Respuesta:</strong> ${escaparHtml(datos.respuesta)}</p>
      ${pieHtml()}
    `)
  };
};
