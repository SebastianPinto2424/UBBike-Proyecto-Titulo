import type { Express } from 'express';
import { rutasAsignacionGuardia } from './acceso/asignaciones/asignacion-guardia.rutas';
import { rutasAcceso } from './acceso/operaciones/acceso.rutas';
import { rutasSolicitudesGuardia } from './acceso/solicitudes/solicitud-guardia.rutas';
import { rutasAutenticacion } from './autenticacion/autenticacion.rutas';
import { rutasBicicletas } from './bicicletas/bicicleta.rutas';
import { rutasBicicleteros } from './bicicleteros/bicicletero.rutas';
import { rutasEnlaces } from './enlaces/enlace.rutas';
import { rutasHistorial } from './historial/historial.rutas';
import { rutasIncidencias } from './incidencias/incidencia.rutas';
import { rutasNotificaciones } from './notificaciones/notificacion.rutas';
import { rutasQr } from './qr/qr.rutas';
import { rutasUsuarios } from './usuarios/usuario.rutas';

export const registrarRutasModulos = (aplicacion: Express): void => {
  aplicacion.use('/autenticacion', rutasAutenticacion);
  aplicacion.use('/auth', rutasAutenticacion);
  aplicacion.use('/bicicletas', rutasBicicletas);
  aplicacion.use('/bicicleteros', rutasBicicleteros);
  aplicacion.use('/historial', rutasHistorial);
  aplicacion.use('/notificaciones', rutasNotificaciones);
  aplicacion.use('/qr', rutasQr);
  aplicacion.use('/accesos', rutasAcceso);
  aplicacion.use('/guardias', rutasAsignacionGuardia);
  aplicacion.use('/solicitudes-guardia', rutasSolicitudesGuardia);
  aplicacion.use('/incidencias', rutasIncidencias);
  aplicacion.use('/usuarios', rutasUsuarios);
  aplicacion.use('/enlaces', rutasEnlaces);
};
