import { aplicacion } from './aplicacion';
import { cargarDatosIniciales } from './configuracion/datos-iniciales';
import { entorno } from './configuracion/entorno';
import { prisma } from './configuracion/prisma';
import { inicializarTiempoReal } from './tiempo-real/tiempo-real';
import { iniciarEntregas } from './modulos/entregas/entrega.worker';
import { cerrarRedis } from './configuracion/redis';

const iniciarServidor = async (): Promise<void> => {
  try {
    await prisma.$connect();
    if (entorno.datosDemo.habilitados) {
      await cargarDatosIniciales();
    }

    const servidor = aplicacion.listen(entorno.puerto, () => {
      console.log(`UBBike backend escuchando en puerto ${entorno.puerto}`);
    });

    const tiempoReal = inicializarTiempoReal(servidor);
    const detenerEntregas = iniciarEntregas();
    let cerrando = false;

    const cerrar = async () => {
      if (cerrando) return;
      cerrando = true;
      const limite = setTimeout(() => process.exit(1), 45000);
      limite.unref();
      await new Promise<void>((resolve) => tiempoReal.close(() => resolve()));
      await detenerEntregas();
      await cerrarRedis();
      await prisma.$disconnect();
      clearTimeout(limite);
      process.exit(0);
    };

    process.on('SIGINT', cerrar);
    process.on('SIGTERM', cerrar);
  } catch (error) {
    console.error('No se pudo iniciar el backend de UBBike', error);
    process.exit(1);
  }
};

void iniciarServidor();
