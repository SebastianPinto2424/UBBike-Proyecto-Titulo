import { prisma } from '../configuracion/prisma';
import { quitarUsuariosDemo } from '../modulos/usuarios/cuentas-demo.servicio';

quitarUsuariosDemo()
  .then((cantidad) => console.log(`[demo] Cuentas de demostración desactivadas: ${cantidad}`))
  .catch((error: Error) => {
    console.error(`[demo] ${error.message}`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
