import ExcelJS from 'exceljs';
import { ErrorHttp } from '../../comun/errores/error-http';
import { SolicitudAutenticada } from '../../comun/middlewares/autenticacion.middleware';
import { controladorAsync } from '../../comun/utilidades/controlador-async';
import type { AlcanceConsulta } from '../../comun/utilidades/esquemas-comunes';
import { RolUsuario } from '../usuarios/rol-usuario';
import {
  listarMovimientos,
  listarMovimientosParaExportar,
  opcionesHistorial,
  resumenHistorial
} from './historial.servicio';

const crearFiltrosHistorial = (req: SolicitudAutenticada, limite: number, pagina: number) => ({
  usuarioId: req.usuario!.usuarioId,
  rol: req.usuario!.rol,
  q: req.query.q?.toString(),
  periodo: req.query.periodo as 'DIA' | 'SEMANA' | 'MES' | 'ANIO' | undefined,
  desde: req.query.desde?.toString(),
  hasta: req.query.hasta?.toString(),
  tipo: req.query.tipo as 'INGRESO' | 'RETIRO' | 'TODOS' | undefined,
  estado: req.query.estado as 'CONFIRMADO' | 'DENEGADO' | 'TODOS' | undefined,
  bicicleteroId: req.query.bicicleteroId?.toString(),
  guardiaId: req.query.guardiaId?.toString(),
  origen: req.query.origen as 'QR' | 'MANUAL' | 'TODOS' | undefined,
  alcance: req.query.alcance as AlcanceConsulta | undefined,
  limite,
  pagina
});

export const listar = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const limite = req.query.limit ? parseInt(req.query.limit as string) : 100;
  const pagina = req.query.page ? parseInt(req.query.page as string) : 1;
  const resultado = await listarMovimientos(crearFiltrosHistorial(req, limite, pagina));

  return res.status(200).json(resultado);
});

export const resumen = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const datos = await resumenHistorial(crearFiltrosHistorial(req, 100000, 1));
  return res.status(200).json({ resumen: datos });
});

export const opciones = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const datos = await opcionesHistorial(req.usuario!.rol);
  return res.status(200).json(datos);
});

const rolesExportacionHistorial: string[] = [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR];

export const mimeExcel = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

const columnasHistorial: Array<{ header: string; key: string; width: number }> = [
  { header: 'ID Movimiento', key: 'id', width: 38 },
  { header: 'Tipo', key: 'tipo', width: 12 },
  { header: 'Estado', key: 'estado', width: 14 },
  { header: 'Origen', key: 'origen', width: 12 },
  { header: 'Fecha Movimiento', key: 'creadoEn', width: 20 },

  { header: 'Usuario Nombre', key: 'usuarioNombre', width: 28 },
  { header: 'Usuario Correo', key: 'usuarioCorreo', width: 34 },
  { header: 'Usuario RUT', key: 'usuarioRut', width: 16 },
  { header: 'Usuario Rol', key: 'usuarioRol', width: 16 },
  { header: 'Correo Verificado', key: 'usuarioCorreoVerificado', width: 18 },
  { header: 'Cuenta Activa', key: 'usuarioCuentaActiva', width: 15 },
  { header: 'Usuario Registrado El', key: 'usuarioCreadoEn', width: 20 },

  { header: 'Bicicleta Descripcion', key: 'bicicletaDescripcion', width: 30 },
  { header: 'Bicicleta Marca', key: 'bicicletaMarca', width: 18 },
  { header: 'Bicicleta Modelo', key: 'bicicletaModelo', width: 18 },
  { header: 'Bicicleta Color', key: 'bicicletaColor', width: 16 },
  { header: 'Bicicleta Aro', key: 'bicicletaAro', width: 12 },
  { header: 'Bicicleta N Serie', key: 'bicicletaNumeroSerie', width: 24 },
  { header: 'Bicicleta Activa', key: 'bicicletaActiva', width: 15 },
  { header: 'Bicicleta Dentro', key: 'bicicletaDentro', width: 15 },
  { header: 'Bicicleta Registrada El', key: 'bicicletaCreadoEn', width: 20 },

  { header: 'Bicicletero', key: 'bicicleteroNombre', width: 30 },
  { header: 'Bicicletero Ubicacion', key: 'bicicleteroUbicacion', width: 34 },

  { header: 'Guardia Validador', key: 'guardiaNombre', width: 28 },
  { header: 'Guardia Correo', key: 'guardiaCorreo', width: 34 },
  { header: 'Guardia RUT', key: 'guardiaRut', width: 16 },

  { header: 'Motivo Denegacion', key: 'motivoDenegacion', width: 30 },
  { header: 'Comentario Guardia', key: 'comentarioGuardia', width: 34 }
];

const siNo = (valor: boolean) => (valor ? 'Si' : 'No');

export const exportarExcel = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  if (!rolesExportacionHistorial.includes(req.usuario!.rol)) {
    throw new ErrorHttp(403, 'Solo administracion puede exportar el historial');
  }

  const movimientos = await listarMovimientosParaExportar(crearFiltrosHistorial(req, 100000, 1));

  const libro = new ExcelJS.Workbook();
  libro.creator = 'UBBike';
  libro.created = new Date();

  const hoja = libro.addWorksheet('Movimientos', {
    views: [{ state: 'frozen', ySplit: 1 }]
  });
  hoja.columns = columnasHistorial;

  const encabezado = hoja.getRow(1);
  encabezado.font = { bold: true, color: { argb: 'FFFFFFFF' } };
  encabezado.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF014898' } };

  for (const movimiento of movimientos) {
    hoja.addRow({
      id: movimiento.id,
      tipo: movimiento.tipo,
      estado: movimiento.estado,
      origen: movimiento.origen,
      creadoEn: movimiento.creadoEn,

      usuarioNombre: movimiento.usuario.nombre,
      usuarioCorreo: movimiento.usuario.correo,
      usuarioRut: movimiento.usuario.rut || '-',
      usuarioRol: movimiento.usuario.rol,
      usuarioCorreoVerificado: siNo(movimiento.usuario.correoVerificado),
      usuarioCuentaActiva: siNo(movimiento.usuario.cuentaActiva),
      usuarioCreadoEn: movimiento.usuario.creadoEn,

      bicicletaDescripcion: movimiento.bicicleta.descripcion,
      bicicletaMarca: movimiento.bicicleta.marca || '-',
      bicicletaModelo: movimiento.bicicleta.modelo || '-',
      bicicletaColor: movimiento.bicicleta.color || '-',
      bicicletaAro: movimiento.bicicleta.aro || '-',
      bicicletaNumeroSerie: movimiento.bicicleta.numeroSerie || '-',
      bicicletaActiva: siNo(movimiento.bicicleta.activa),
      bicicletaDentro: siNo(movimiento.bicicleta.dentroBicicletero),
      bicicletaCreadoEn: movimiento.bicicleta.creadoEn,

      bicicleteroNombre: movimiento.bicicletero?.nombre || '-',
      bicicleteroUbicacion: movimiento.bicicletero?.ubicacion || '-',

      guardiaNombre: movimiento.validadoPorGuardia?.nombre || '-',
      guardiaCorreo: movimiento.validadoPorGuardia?.correo || '-',
      guardiaRut: movimiento.validadoPorGuardia?.rut || '-',

      motivoDenegacion: movimiento.motivoDenegacion || '-',
      comentarioGuardia: movimiento.comentarioGuardia || '-'
    });
  }

  for (const columna of ['creadoEn', 'usuarioCreadoEn', 'bicicletaCreadoEn']) {
    hoja.getColumn(columna).numFmt = 'dd-mm-yyyy hh:mm';
  }
  hoja.autoFilter = {
    from: { row: 1, column: 1 },
    to: { row: 1, column: columnasHistorial.length }
  };

  const contenido = await libro.xlsx.writeBuffer();

  res.header('Content-Type', mimeExcel);
  res.attachment('historial-movimientos-ubbike.xlsx');
  return res.send(Buffer.from(contenido));
});
