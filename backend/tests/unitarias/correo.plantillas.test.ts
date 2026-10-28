import '../apoyo/configurar-entorno';

const enviarMail = jest.fn().mockResolvedValue({ messageId: 'x' });

jest.mock('nodemailer', () => ({
  __esModule: true,
  default: {
    createTransport: jest.fn(() => ({ sendMail: enviarMail }))
  }
}));

jest.mock('../../src/modulos/entregas/entrega.repositorio', () => ({
  encolarEntrega: jest.fn().mockResolvedValue(undefined)
}));

import nodemailer from 'nodemailer';
import { entorno } from '../../src/configuracion/entorno';
import {
  crearCorreoCambioContrasena,
  crearCorreoCompletarRegistro,
  crearCorreoCuentaAdministrativa,
  crearCorreoContrasenaActualizada,
  crearCorreoCuentaActivada,
  crearCorreoCuentaDesactivada,
  crearCorreoCuentaReactivada,
  crearCorreoCuentaVerificada,
  crearCorreoNuevoCorreo,
  crearCorreoRolActualizado,
  crearCorreoVerificacion
} from '../../src/modulos/correos/cuenta.plantillas';
import {
  crearCorreoIncidenciaNueva,
  crearCorreoIncidenciaResuelta,
  crearCorreoMovimiento
} from '../../src/modulos/correos/operacion.plantillas';
import { entregarCorreo, enviarCorreo } from '../../src/modulos/correos/correo.servicio';
import { encolarEntrega } from '../../src/modulos/entregas/entrega.repositorio';

const nombreMalicioso = '<script>alert(1)</script> Rojas';
const correoAna = 'ana@alumnos.ubiobio.cl';
const enlace = 'https://ubbike.example/enlaces/verificar-correo?token=abc&modo=x';
const fecha = new Date('2026-10-20T13:30:00Z');

type Correo = { asunto: string; texto: string; html: string };

const esCorreoCompleto = (correo: Correo) => {
  expect(correo.asunto.length).toBeGreaterThan(5);
  expect(correo.texto.length).toBeGreaterThan(20);
  expect(correo.html).toContain('<!doctype html>');
  expect(correo.html).toContain('Equipo UBBike');
};

describe('plantillas de correo', () => {
  it.each<[string, () => Correo]>([
    ['verificación', () => crearCorreoVerificacion(nombreMalicioso, correoAna, enlace, fecha)],
    ['nuevo correo', () => crearCorreoNuevoCorreo(nombreMalicioso, correoAna, enlace, fecha)],
    ['completar registro', () => crearCorreoCompletarRegistro('ana@alumnos.ubiobio.cl', enlace)],
    ['cambio de contraseña', () => crearCorreoCambioContrasena(nombreMalicioso, enlace)],
    [
      'cuenta creada por administración',
      () => crearCorreoCuentaAdministrativa(nombreMalicioso, enlace, 24, 'GUARDIA')
    ]
  ])('el correo de %s lleva el enlace en texto, en botón y de respaldo', (_caso, crear) => {
    const correo = crear();

    esCorreoCompleto(correo);
    expect(correo.texto).toContain(enlace);
    expect(correo.html.split(enlace.replace(/&/g, '&amp;')).length - 1).toBe(3);
    expect(correo.html).toContain(
      '¿El botón no funciona? Copia y pega este enlace en el navegador'
    );
    expect(correo.html).toContain('display:none');
  });

  it.each<[string, () => Correo]>([
    ['verificación', () => crearCorreoVerificacion(nombreMalicioso, correoAna, enlace, fecha)],
    ['cuenta verificada', () => crearCorreoCuentaVerificada(nombreMalicioso)],
    ['cuenta desactivada', () => crearCorreoCuentaDesactivada(nombreMalicioso)],
    ['cuenta reactivada', () => crearCorreoCuentaReactivada(nombreMalicioso)],
    ['contraseña actualizada', () => crearCorreoContrasenaActualizada(nombreMalicioso)],
    ['cuenta activada', () => crearCorreoCuentaActivada(nombreMalicioso, 'GUARDIA')],
    [
      'rol actualizado',
      () => crearCorreoRolActualizado(nombreMalicioso, 'ESTUDIANTE', 'ADMIN_CENTRAL')
    ]
  ])('el correo de %s escapa el nombre en el HTML', (_caso, crear) => {
    const correo = crear();

    esCorreoCompleto(correo);
    expect(correo.html).not.toContain('<script>');
    expect(correo.html).toContain('&lt;script&gt;');
  });

  it('saluda con el primer nombre como indica la RAE', () => {
    const correo = crearCorreoVerificacion('Ana María Rojas Soto', correoAna, enlace, fecha);

    expect(correo.texto.startsWith('Hola, Ana:\n\n')).toBe(true);
    expect(correo.html).toContain('<p>Hola, Ana:</p>');
    expect(crearCorreoCompletarRegistro(correoAna, enlace).texto.startsWith('Hola:')).toBe(true);
  });

  it('la confirmación del registro muestra el correo, cuándo vence y qué sigue', () => {
    const correo = crearCorreoVerificacion('Ana Rojas', correoAna, enlace, fecha);

    expect(correo.asunto).toBe('Confirma tu correo para activar UBBike');
    expect(correo.html).toContain(`<strong>${correoAna}</strong>`);
    expect(correo.html).toContain('20 de octubre de 2026');
    expect(correo.texto).toContain('Gracias por registrarte en UBBike');
    expect(correo.texto).toContain('Después podrás iniciar sesión en la app');
    expect(correo.texto).toContain('Si no creaste esta cuenta, ignora este correo');
    expect(correo.html).toContain('Un paso más para usar UBBike');
  });

  it('el cambio de correo no agradece un registro', () => {
    const correo = crearCorreoNuevoCorreo('Ana Rojas', correoAna, enlace, fecha);

    expect(correo.asunto).toBe('Confirma tu nuevo correo en UBBike');
    expect(correo.texto).not.toContain('Gracias por registrarte');
    expect(correo.texto).toContain('Si no reconoces este cambio');
  });

  it('la bienvenida explica los primeros pasos en la app', () => {
    const correo = crearCorreoCuentaVerificada('Ana Rojas');

    expect(correo.html).toContain('<ol');
    expect(correo.html).toContain('<strong>Bicicletas</strong>');
    expect(correo.html).toContain('<strong>Generar QR</strong>');
    expect(correo.texto).toContain('3. En QR, toca Generar QR');
  });

  it('la cuenta activada de un guardia no exige correo institucional', () => {
    const correo = crearCorreoCuentaActivada('Pedro Soto', 'GUARDIA');

    expect(correo.texto).toContain('con este correo y la contraseña que creaste');
    expect(correo.texto).not.toContain('institucional');
  });

  it('ningún correo usa comillas angulares', () => {
    const correos = [
      crearCorreoVerificacion('Ana', correoAna, enlace, fecha),
      crearCorreoNuevoCorreo('Ana', correoAna, enlace, fecha),
      crearCorreoCompletarRegistro(correoAna, enlace),
      crearCorreoCambioContrasena('Ana', enlace),
      crearCorreoCuentaAdministrativa('Ana', enlace, 24, 'GUARDIA'),
      crearCorreoCuentaVerificada('Ana'),
      crearCorreoCuentaActivada('Ana', 'GUARDIA')
    ];

    for (const correo of correos) {
      expect(`${correo.asunto}${correo.texto}${correo.html}`).not.toMatch(/[«»]/);
    }
  });

  it('el cambio de rol nombra ambos roles', () => {
    const correo = crearCorreoRolActualizado('Ana', 'ESTUDIANTE', 'GUARDIA');

    expect(correo.texto).toContain('Estudiante');
    expect(correo.texto).toContain('Guardia');
  });

  it('la cuenta activada adapta el texto al rol', () => {
    expect(crearCorreoCuentaActivada('Ana', 'ADMINISTRADOR').texto).toContain('administrador');
    expect(crearCorreoCuentaActivada('Ana').texto).toContain('usuario');
  });

  it('el correo de movimiento denegado incluye el motivo escapado', () => {
    const correo = crearCorreoMovimiento({
      nombre: 'Ana',
      tipo: 'RETIRO',
      estado: 'DENEGADO',
      origen: 'MANUAL',
      bicicleta: 'Urbana azul',
      bicicletero: 'Biblioteca Central',
      guardia: 'Pedro Soto',
      fecha,
      motivoDenegacion: 'Datos <b>distintos</b>'
    });

    esCorreoCompleto(correo);
    expect(correo.texto).toContain('Datos <b>distintos</b>');
    expect(correo.html).toContain('Datos &lt;b&gt;distintos&lt;/b&gt;');
  });

  it('los avisos de incidencia distinguen el recordatorio', () => {
    const datos = {
      nombreDestinatario: 'Central',
      tipo: 'Daño de infraestructura',
      bicicletero: 'Biblioteca Central',
      descripcion: 'Soporte <suelto>',
      reportadaPor: 'Ana Rojas',
      fecha
    };

    const nueva = crearCorreoIncidenciaNueva(datos);
    const recordatorio = crearCorreoIncidenciaNueva({ ...datos, recordatorio: true });

    esCorreoCompleto(nueva);
    expect(nueva.asunto).not.toBe(recordatorio.asunto);
    expect(nueva.html).toContain('Soporte &lt;suelto&gt;');
  });

  it('la incidencia resuelta incluye la respuesta de gestión', () => {
    const correo = crearCorreoIncidenciaResuelta({
      nombre: 'Ana',
      tipo: 'Daño de infraestructura',
      bicicletero: 'Biblioteca Central',
      estado: 'resuelta',
      respuesta: 'Se reparó el soporte',
      fecha
    });

    esCorreoCompleto(correo);
    expect(correo.texto).toContain('Se reparó el soporte');
  });
});

describe('envío de correos', () => {
  const hostOriginal = entorno.correo.host;
  const ambienteOriginal = entorno.ambiente;

  afterEach(() => {
    entorno.correo.host = hostOriginal;
    entorno.ambiente = ambienteOriginal;
  });

  it('enviar deja el correo en la cola de entregas', async () => {
    await enviarCorreo({ para: 'ana@alumnos.ubiobio.cl', asunto: 'a', texto: 't', html: 'h' });

    expect(encolarEntrega).toHaveBeenCalledWith(
      'CORREO',
      expect.objectContaining({ para: 'ana@alumnos.ubiobio.cl', adjuntos: undefined }),
      undefined
    );
  });

  it('sin SMTP en desarrollo simula la entrega sin enviar', async () => {
    entorno.correo.host = undefined;
    const log = jest.spyOn(console, 'log').mockImplementation(() => undefined);

    await entregarCorreo({ para: 'a@b.cl', asunto: 'a', texto: 't', html: 'h' }, 'e1');

    expect(nodemailer.createTransport).not.toHaveBeenCalled();
    expect(log).toHaveBeenCalled();
    log.mockRestore();
  });

  it('sin SMTP en producción falla para reintentar', async () => {
    entorno.correo.host = undefined;
    entorno.ambiente = 'production';

    await expect(
      entregarCorreo({ para: 'a@b.cl', asunto: 'a', texto: 't', html: 'h' }, 'e1')
    ).rejects.toThrow('SMTP_HOST');
  });

  it('con SMTP envía con el remitente y una referencia', async () => {
    entorno.correo.host = 'smtp.example.com';

    await entregarCorreo(
      { para: 'ana@alumnos.ubiobio.cl', asunto: 'Asunto', texto: 't', html: 'h', referencia: 'r1' },
      'e1'
    );

    expect(enviarMail).toHaveBeenCalledWith(
      expect.objectContaining({
        messageId: '<e1@ubbike.local>',
        from: entorno.correo.remitente,
        to: 'ana@alumnos.ubiobio.cl',
        subject: 'Asunto',
        headers: { 'X-Entity-Ref-ID': 'r1' }
      })
    );
  });
});
