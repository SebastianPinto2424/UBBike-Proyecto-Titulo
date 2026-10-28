import { EstadoIncidencia } from './estado-incidencia';
import type { IncidenciaCompleta } from './incidencia.repositorio';
import { TipoIncidencia } from './tipo-incidencia';
import { calcularSegundosParaRecordatorioIncidencia } from './incidencia.reglas';

export const etiquetaEstadoIncidencia = (estado: EstadoIncidencia) => {
  switch (estado) {
    case EstadoIncidencia.PENDIENTE:
      return 'pendiente';
    case EstadoIncidencia.EN_REVISION:
      return 'en revisión';
    case EstadoIncidencia.RESUELTA:
      return 'resuelta';
    case EstadoIncidencia.DESCARTADA:
      return 'descartada';
    default:
      return estado;
  }
};

export const etiquetaTipoIncidencia = (tipo: TipoIncidencia) => {
  switch (tipo) {
    case TipoIncidencia.PROBLEMA_QR:
      return 'Problema con QR';
    case TipoIncidencia.DANO_BICICLETA:
      return 'Daño de bicicleta';
    case TipoIncidencia.DANO_INFRAESTRUCTURA:
      return 'Daño de infraestructura';
    case TipoIncidencia.PROBLEMA_MOVIMIENTO:
      return 'Problema de movimiento';
    case TipoIncidencia.USUARIO_DATOS:
      return 'Datos de usuario';
    default:
      return 'Otro';
  }
};

type ContextoIncidencia = {
  usuarioId: string;
  rol: string;
};

const mapearUsuarioIncidencia = (
  usuario: IncidenciaCompleta['reportadaPorUsuario'] | IncidenciaCompleta['gestionadaPorUsuario']
) => {
  if (!usuario) {
    return null;
  }

  return {
    id: usuario.id,
    nombre: usuario.nombre,
    correo: usuario.correo,
    rut: usuario.rut,
    rol: usuario.rol
  };
};

export const mapearIncidencia = (incidencia: IncidenciaCompleta, contexto: ContextoIncidencia) => {
  const esReportante = incidencia.reportadaPorUsuarioId === contexto.usuarioId;
  const segundosParaRecordar = esReportante
    ? calcularSegundosParaRecordatorioIncidencia(incidencia)
    : null;

  return {
    id: incidencia.id,
    tipo: incidencia.tipo,
    descripcion: incidencia.descripcion,
    estado: incidencia.estado,
    respuesta: incidencia.respuesta,
    creadaEn: incidencia.creadaEn,
    actualizadaEn: incidencia.actualizadaEn,
    resueltaEn: incidencia.resueltaEn,
    ultimoRecordatorioEn: incidencia.ultimoRecordatorioEn,
    recordatorios: incidencia.recordatorios,
    puedeRecordar: esReportante && segundosParaRecordar === 0,
    segundosParaRecordar,
    reportadaPorUsuario: mapearUsuarioIncidencia(incidencia.reportadaPorUsuario),
    gestionadaPorUsuario: mapearUsuarioIncidencia(incidencia.gestionadaPorUsuario),
    fotos: incidencia.fotos.map((foto) => ({
      id: foto.id,
      url: foto.fotoUrl,
      mimeType: foto.mimeType,
      tamanoBytes: foto.tamanoBytes
    })),
    bicicletero: {
      id: incidencia.bicicletero.id,
      nombre: incidencia.bicicletero.nombre,
      ubicacion: incidencia.bicicletero.ubicacion
    },
    bicicleta: incidencia.bicicleta
      ? {
          id: incidencia.bicicleta.id,
          descripcion: incidencia.bicicleta.descripcion,
          marca: incidencia.bicicleta.marca,
          modelo: incidencia.bicicleta.modelo,
          color: incidencia.bicicleta.color,
          aro: incidencia.bicicleta.aro,
          numeroSerie: incidencia.bicicleta.numeroSerie,
          fotoUrl: incidencia.bicicleta.fotoUrl,
          activa: incidencia.bicicleta.activa,
          dentroBicicletero: incidencia.bicicleta.dentroBicicletero
        }
      : null
  };
};
