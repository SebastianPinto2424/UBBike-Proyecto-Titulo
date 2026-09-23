import { prisma } from '../../configuracion/prisma';
import { entregarCorreo, type CorreoEncolado } from '../correos/correo.servicio';
import { enviarPushAUsuario } from '../notificaciones/push.servicio';

const MAX_INTENTOS = 12;
export const procesarEntregas = async () => {
  const ahora = new Date();
  const pendientes = await prisma.entregaPendiente.findMany({
    where: { entregadaEn: null, agotada: false, disponibleEn: { lte: ahora } },
    orderBy: { disponibleEn: 'asc' },
    take: 20
  });
  for (const entrega of pendientes) {
    const intento = entrega.intentos + 1;
    const reserva = await prisma.entregaPendiente.updateMany({
      where: {
        id: entrega.id,
        intentos: entrega.intentos,
        entregadaEn: null,
        agotada: false,
        disponibleEn: { lte: ahora }
      },
      data: { intentos: intento, disponibleEn: new Date(Date.now() + 10 * 60000) }
    });
    if (reserva.count !== 1) continue;
    try {
      if (Date.now() - entrega.creadaEn.getTime() > 24 * 3600000)
        throw new Error('Entrega vencida');
      if (entrega.tipo === 'CORREO') {
        await entregarCorreo(entrega.datos as unknown as CorreoEncolado, entrega.id);
      } else if (entrega.tipo === 'PUSH') {
        const datos = entrega.datos as unknown as {
          usuarioId: string;
          push: Parameters<typeof enviarPushAUsuario>[1];
        };
        const usuario = await prisma.usuario.findUnique({ where: { id: datos.usuarioId } });
        if (usuario?.cuentaActiva && !usuario.eliminadoEn)
          await enviarPushAUsuario(datos.usuarioId, datos.push);
      } else throw new Error('Tipo de entrega desconocido');
      await prisma.entregaPendiente.updateMany({
        where: { id: entrega.id, intentos: intento },
        data: { entregadaEn: new Date(), datos: {} }
      });
    } catch {
      const agotada =
        intento >= MAX_INTENTOS || Date.now() - entrega.creadaEn.getTime() > 24 * 3600000;
      await prisma.entregaPendiente.updateMany({
        where: { id: entrega.id, intentos: intento },
        data: {
          agotada,
          disponibleEn: new Date(Date.now() + Math.min(3600000, 10000 * 2 ** intento)),
          ...(agotada ? { datos: {} } : {})
        }
      });
      console.error('[entregas]', { id: entrega.id, tipo: entrega.tipo, intento, agotada });
    }
  }
};

let despertar: (() => void) | null = null;

export const solicitarEntregaInmediata = () => {
  despertar?.();
};

export const iniciarEntregas = () => {
  let detenido = false;
  let corriendo = false;
  let pendiente = false;
  let timer: ReturnType<typeof setTimeout>;
  let tarea: Promise<void> = Promise.resolve();

  const ejecutar = () => {
    if (detenido) return;
    if (corriendo) {
      pendiente = true;
      return;
    }

    corriendo = true;
    clearTimeout(timer);
    tarea = procesarEntregas()
      .catch(() => console.error('[entregas] No se pudo consultar la cola'))
      .finally(() => {
        corriendo = false;
        if (detenido) return;
        if (pendiente) {
          pendiente = false;
          ejecutar();
        } else {
          timer = setTimeout(ejecutar, 5000);
        }
      });
  };

  despertar = ejecutar;
  ejecutar();

  return async () => {
    detenido = true;
    despertar = null;
    clearTimeout(timer);
    await tarea;
  };
};
