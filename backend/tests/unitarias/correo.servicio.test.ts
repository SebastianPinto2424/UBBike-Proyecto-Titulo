import '../apoyo/configurar-entorno';

import { crearCorreoCuentaAdministrativa } from '../../src/modulos/correos/cuenta.plantillas';
import { crearCorreoMovimiento } from '../../src/modulos/correos/operacion.plantillas';

describe('crearCorreoCuentaAdministrativa', () => {
  it('incluye siempre el boton y el enlace para crear la contrasena', () => {
    const enlace = 'https://ubbike.example/cambiar-contrasena?token=token-seguro&modo=activacion';
    const correo = crearCorreoCuentaAdministrativa('Guardia Prueba', enlace, 24, 'GUARDIA');

    expect(correo.asunto).toBe('Activa tu cuenta de guardia en UBBike');
    expect(correo.texto).toContain(enlace);
    expect(correo.html).toContain(
      'href="https://ubbike.example/cambiar-contrasena?token=token-seguro&amp;modo=activacion"'
    );
    expect(correo.html).toContain('Crear mi contraseña');
    expect(correo.html).toContain('vence en 24 horas');
  });

  it('presenta la activación sin confundirla con un cambio de contraseña', () => {
    const correo = crearCorreoCuentaAdministrativa(
      'Guardia Prueba',
      'https://ubbike.example/enlace',
      24,
      'GUARDIA'
    );

    for (const contenido of [correo.texto, correo.html]) {
      expect(contenido).toContain('administración de UBBike creó tu cuenta de');
      expect(contenido).toMatch(
        /guardia(<\/strong>)? el \d{1,2} de \w+ de \d{4} a las \d{2}:\d{2}\./
      );
      expect(contenido).not.toMatch(/\.\./);
      expect(contenido).toContain('crea la contraseña con la que ingresarás a la app');
      expect(contenido).toContain('¿Has olvidado tu contraseña?');
      expect(contenido).not.toMatch(/[«»]/);
      expect(contenido).not.toContain('primer ingreso');
      expect(contenido).not.toContain('nunca te enviamos una');
    }
    expect(correo.html).toContain('nunca te pedirá tu contraseña');
  });

  it('usa el rol de la cuenta en el asunto', () => {
    expect(
      crearCorreoCuentaAdministrativa(
        'Ana Rojas',
        'https://ubbike.example/enlace',
        24,
        'ADMINISTRADOR'
      ).asunto
    ).toBe('Activa tu cuenta de administrador en UBBike');
  });
});

describe('crearCorreoMovimiento', () => {
  it('mantiene todos los campos y no agrega fecha ni hora al asunto', () => {
    const correo = crearCorreoMovimiento({
      nombre: 'Estudiante UBB',
      tipo: 'RETIRO',
      estado: 'CONFIRMADO',
      origen: 'QR',
      bicicleta: 'Bici de prueba',
      marca: null,
      modelo: '',
      color: null,
      aro: undefined,
      numeroSerie: null,
      bicicletero: 'Bicicletero FACE',
      guardia: 'Guardia Demo',
      fecha: new Date('2026-07-07T12:00:00.000Z'),
      fotoCid: 'foto-bicicleta-movimiento@ubbike'
    });

    expect(correo.asunto).toBe('Retiro confirmado: Bici de prueba en UBBike');
    expect(correo.asunto).not.toMatch(/\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}:\d{2}/);
    expect(correo.html).toContain('<strong>Operación:</strong> Retiro');
    expect(correo.html).toContain('<strong>Resultado:</strong> confirmado');
    expect(correo.html).toContain('<strong>Origen:</strong> por código QR');
    expect(correo.html).toContain('<strong>Bicicletero:</strong> Bicicletero FACE');
    expect(correo.html).toContain('<strong>Guardia:</strong> Guardia Demo');
    expect(correo.html).toContain('<strong>Descripción:</strong> Bici de prueba');
    expect(correo.texto).toContain('Marca: No informado');
    expect(correo.texto).toContain('Modelo: No informado');
    expect(correo.texto).toContain('Color: No informado');
    expect(correo.texto).toContain('Aro: No informado');
    expect(correo.texto).toContain('serie: No informado');
    expect(correo.html).toContain('cid:foto-bicicleta-movimiento@ubbike');
  });
});
