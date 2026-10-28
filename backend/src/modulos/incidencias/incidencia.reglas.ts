import { RolUsuario } from '../usuarios/rol-usuario';
import { EstadoIncidencia } from './estado-incidencia';
import type { IncidenciaCompleta } from './incidencia.repositorio';

export const rolesCentral: string[] = [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR];
export const estadosCerradosIncidencia: EstadoIncidencia[] = [
  EstadoIncidencia.RESUELTA,
  EstadoIncidencia.DESCARTADA
];
const segundosEsperaRecordatorioIncidencia = 300;

export const calcularSegundosParaRecordatorioIncidencia = (incidencia: IncidenciaCompleta) => {
  if (estadosCerradosIncidencia.includes(incidencia.estado)) {
    return null;
  }

  const base = incidencia.ultimoRecordatorioEn ?? incidencia.creadaEn;
  const transcurridos = Math.floor((Date.now() - base.getTime()) / 1000);
  return Math.max(segundosEsperaRecordatorioIncidencia - transcurridos, 0);
};
