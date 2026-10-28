import bcrypt from 'bcryptjs';
import { prisma } from './prisma';
import { crearNotificacion } from '../modulos/notificaciones/notificacion.servicio';
import { TipoNotificacion } from '../modulos/notificaciones/tipo-notificacion';
import { RolUsuario } from '../modulos/usuarios/rol-usuario';

const contrasenaDemo = 'UBBike2026*';

const usuariosDemo = [
  {
    nombre: 'Estudiante UBB',
    correo: 'estudiante@alumnos.ubiobio.cl',
    rut: '20.111.111-1',
    rol: RolUsuario.ESTUDIANTE
  },
  {
    nombre: 'Funcionario UBB',
    correo: 'funcionario@ubiobio.cl',
    rut: '16.222.222-2',
    rol: RolUsuario.FUNCIONARIO
  },
  {
    nombre: 'Guardia Bicicletero',
    correo: 'guardia@ubiobio.cl',
    rut: '13.333.333-3',
    rol: RolUsuario.GUARDIA
  },
  {
    nombre: 'Admin Central Seguridad',
    correo: 'admin.central@ubiobio.cl',
    rut: '12.444.444-4',
    rol: RolUsuario.ADMIN_CENTRAL
  },
  {
    nombre: 'Administrador UBBike',
    correo: 'administrador@ubiobio.cl',
    rut: '11.555.555-5',
    rol: RolUsuario.ADMINISTRADOR
  }
];

export const correosUsuariosDemo = usuariosDemo.map((usuario) => usuario.correo);

const bicicleterosBase = [
  {
    nombre: 'Bicicletero cercano al Centro de Idiomas',
    ubicacion: 'Sector Centro de Idiomas',
    nombresAnteriores: ['Bicicletero Central'],
    capacidad: 104,
    latitud: -36.82141385290648,
    longitud: -73.01254820745834
  },
  {
    nombre: 'Bicicletero cercano a la FACE',
    ubicacion: 'Sector FACE',
    nombresAnteriores: ['Bicicletero Biblioteca'],
    capacidad: 120,
    latitud: -36.822041412853984,
    longitud: -73.01066005340653
  }
];

export const cargarDatosIniciales = async (): Promise<void> => {
  const contrasenaHash = await bcrypt.hash(contrasenaDemo, 12);

  const centralAnterior = await prisma.usuario.findUnique({
    where: {
      correo: 'central.seguridad@ubiobio.cl'
    }
  });
  const centralActual = await prisma.usuario.findUnique({
    where: {
      correo: 'admin.central@ubiobio.cl'
    }
  });

  if (centralAnterior && !centralActual) {
    await prisma.usuario.update({
      where: {
        id: centralAnterior.id
      },
      data: {
        nombre: 'Admin Central Seguridad',
        correo: 'admin.central@ubiobio.cl',
        rol: RolUsuario.ADMIN_CENTRAL,
        cuentaActiva: true,
        correoVerificado: true,
        tokenVerificacionCorreoExpiraEn: null
      }
    });
  }

  for (const usuarioDemo of usuariosDemo) {
    const existente = await prisma.usuario.findUnique({
      where: {
        correo: usuarioDemo.correo
      }
    });

    if (existente) {
      await prisma.usuario.update({
        where: {
          id: existente.id
        },
        data: {
          nombre: usuarioDemo.nombre,
          rut: usuarioDemo.rut,
          rol: usuarioDemo.rol,
          cuentaActiva: true,
          correoVerificado: true,
          tokenVerificacionCorreo: null,
          tokenVerificacionCorreoExpiraEn: null
        }
      });
      continue;
    }

    const guardado = await prisma.usuario.create({
      data: {
        ...usuarioDemo,
        contrasenaHash,
        cuentaActiva: true,
        correoVerificado: true
      }
    });

    await crearNotificacion({
      usuarioId: guardado.id,
      titulo: 'Bienvenido a UBBike',
      mensaje: 'Tu cuenta está lista para usar UBBike.',
      tipo: TipoNotificacion.SISTEMA
    });
  }

  for (const bicicleteroBase of bicicleterosBase) {
    let existente = await prisma.bicicletero.findUnique({
      where: {
        nombre: bicicleteroBase.nombre
      }
    });

    for (const nombreAnterior of bicicleteroBase.nombresAnteriores) {
      if (existente) {
        break;
      }
      existente = await prisma.bicicletero.findUnique({ where: { nombre: nombreAnterior } });
    }

    const datosBicicletero = {
      nombre: bicicleteroBase.nombre,
      ubicacion: bicicleteroBase.ubicacion,
      latitud: bicicleteroBase.latitud,
      longitud: bicicleteroBase.longitud,
      capacidad: bicicleteroBase.capacidad,
      activo: true
    };

    if (!existente) {
      await prisma.bicicletero.create({
        data: datosBicicletero
      });
    } else {
      await prisma.bicicletero.update({
        where: {
          id: existente.id
        },
        data: datosBicicletero
      });
    }
  }

  for (const bicicleteroBase of bicicleterosBase) {
    for (const nombreAnterior of bicicleteroBase.nombresAnteriores) {
      const anterior = await prisma.bicicletero.findUnique({ where: { nombre: nombreAnterior } });

      if (anterior) {
        await prisma.bicicletero.update({
          where: {
            id: anterior.id
          },
          data: {
            activo: false
          }
        });
      }
    }
  }
};
