import {
  paginaError,
  paginaFormulario,
  paginaResultado
} from '../../src/modulos/enlaces/enlace.vistas';
import {
  esquemaFormularioRegistro,
  reglasFormulario
} from '../../src/modulos/enlaces/enlace.validacion';

const { validarValor } = require('../../publico/formulario-enlace.js') as {
  validarValor: (valor: string, reglas: Record<string, string>, referencia?: string) => string;
};

const token = 'c'.repeat(64);
const clave = 'Bicicleta#2026ubb';
const enlace = (activacion = false) => ({
  valido: true as const,
  correo: 'ana@alumnos.ubiobio.cl',
  activacion
});

const decodificar = (texto: string) =>
  texto
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&');

const reglasEnPagina = (html: string, campo: string): Record<string, string> => {
  const entrada = html.match(new RegExp(`<input id="campo-${campo}"[^>]*>`));
  if (!entrada) {
    throw new Error(`La página no tiene el campo ${campo}`);
  }
  return Object.fromEntries(
    [...entrada[0].matchAll(/data-([a-z-]+)(?:="([^"]*)")?/g)].map(([, clave, valor]) => [
      clave.replace(/-([a-z])/g, (_, letra: string) => letra.toUpperCase()),
      decodificar(valor ?? '')
    ])
  );
};

const mensajeServidor = (
  campo: 'nombre' | 'contrasena' | 'confirmacion',
  valor: string,
  contrasena = clave
) => {
  const cuerpo = {
    nombre: 'Ana María Rojas Soto',
    contrasena,
    confirmacion: contrasena,
    [campo]: valor
  };
  const { error } = esquemaFormularioRegistro.validate(cuerpo, { abortEarly: false });
  return error?.details.find((detalle) => detalle.path[0] === campo)?.message ?? '';
};

const registro = paginaFormulario('completar-registro', token, enlace());

describe('validación en el navegador', () => {
  it.each([
    '',
    '   ',
    'Ana',
    'Ana María Rojas Soto',
    '  Ana   María  Rojas Soto  ',
    'Ana\tMaría\nRojas Soto',
    "José-Luis O'Higgins Riquelme Soto",
    'Ana María Rojas Soto Pérez',
    'Ana Mar1a Rojas Soto',
    'a'.repeat(121),
    'Ana '.repeat(30)
  ])('el nombre %p recibe el mismo mensaje que en el servidor', (nombre) => {
    expect(validarValor(nombre, reglasEnPagina(registro, 'nombre'))).toBe(
      mensajeServidor('nombre', nombre)
    );
  });

  it.each([
    '',
    ' ',
    '            ',
    'corta',
    clave,
    'sinmayuscula#2026',
    'SINMINUSCULA#2026',
    'SinNumero#Clave',
    'SinSimbolo2026ab',
    'Ñandú#2026Clave',
    'Clave Con Espacio 1',
    `Aa1#${'x'.repeat(68)}`,
    `Aa1#${'x'.repeat(69)}`
  ])('la contraseña %p recibe el mismo mensaje que en el servidor', (contrasena) => {
    expect(validarValor(contrasena, reglasEnPagina(registro, 'contrasena'))).toBe(
      mensajeServidor('contrasena', contrasena)
    );
  });

  it.each([
    [clave, clave],
    [clave, ''],
    ['', ''],
    ['', 'algo'],
    [clave, 'Bicicleta#2026ubx'],
    [clave, `${clave} `]
  ])(
    'la confirmación %p / %p recibe el mismo mensaje que en el servidor',
    (contrasena, confirmacion) => {
      expect(validarValor(confirmacion, reglasEnPagina(registro, 'confirmacion'), contrasena)).toBe(
        mensajeServidor('confirmacion', confirmacion, contrasena)
      );
    }
  );

  it('usa los mensajes de la pantalla de registro de la app', () => {
    expect(validarValor('', reglasEnPagina(registro, 'contrasena'))).toBe(
      'La contraseña es obligatoria.'
    );
    expect(validarValor('corta', reglasEnPagina(registro, 'contrasena'))).toBe(
      'Mínimo 12 caracteres con mayúscula, minúscula, número y símbolo.'
    );
    expect(validarValor('Ana', reglasEnPagina(registro, 'nombre'))).toBe(
      'Ingresa dos nombres y dos apellidos (Nombre Nombre Apellido Apellido).'
    );
    expect(validarValor('otra', reglasEnPagina(registro, 'confirmacion'), clave)).toBe(
      'Las contraseñas no coinciden.'
    );
  });
});

describe('formularios de los enlaces', () => {
  it.each([
    ['completar-registro', false],
    ['cambiar-contrasena', true],
    ['cambiar-contrasena', false]
  ] as const)(
    '%s no muestra el correo, solo lo deja para el gestor de contraseñas',
    (accion, activacion) => {
      const html = paginaFormulario(accion, token, enlace(activacion));

      expect(html).not.toContain('>Correo</label>');
      expect(html).toContain(
        '<input type="email" autocomplete="username" value="ana@alumnos.ubiobio.cl" hidden>'
      );
    }
  );

  it('la contraseña tiene la ayuda de la app y el botón para verla', () => {
    const html = paginaFormulario('cambiar-contrasena', token, enlace(false));

    expect(html).toContain('<label for="campo-contrasena">Nueva contraseña</label>');
    expect(html).toContain(`>${reglasFormulario.contrasena.ayuda}</p>`);
    expect(html).toContain('aria-label="Mostrar contraseña"');
    expect(html.match(/autocomplete="new-password"/g)).toHaveLength(2);
  });

  it('pide la contraseña dos veces y cada campo tiene su propio botón para verla', () => {
    const html = paginaFormulario('cambiar-contrasena', token, enlace(false));

    expect(html).toContain('<label for="campo-confirmacion">Confirmar nueva contraseña</label>');
    expect(html).toContain('data-igual-a="campo-contrasena"');
    expect(html.match(/data-alternar/g)).toHaveLength(2);
    expect(html).toContain('aria-controls="campo-contrasena"');
    expect(html).toContain('aria-controls="campo-confirmacion"');
  });

  it('al activar la cuenta las etiquetas son las de crear contraseña', () => {
    const html = paginaFormulario('cambiar-contrasena', token, enlace(true));

    expect(html).toContain('<label for="campo-contrasena">Contraseña</label>');
    expect(html).toContain('<label for="campo-confirmacion">Confirmar contraseña</label>');
    expect(html).toContain('<span class="texto">Activar mi cuenta</span>');
  });

  it('sin errores deja el mensaje de error oculto', () => {
    expect(registro).toContain('<p class="error" id="campo-nombre-error" role="alert" hidden></p>');
    expect(registro).not.toContain('aria-invalid');
  });

  it('muestra los errores del servidor en su campo y conserva el nombre escrito', () => {
    const html = paginaFormulario(
      'completar-registro',
      token,
      enlace(),
      { nombre: reglasFormulario.nombre.mensajes.formato },
      '<b>"Ana"</b>'
    );

    expect(html).toContain('<div class="grupo invalido">');
    expect(html).toContain('aria-invalid="true"');
    expect(html).toContain(
      `<p class="error" id="campo-nombre-error" role="alert">${reglasFormulario.nombre.mensajes.formato}</p>`
    );
    expect(html).toContain('value="&lt;b&gt;&quot;Ana&quot;&lt;/b&gt;"');
  });

  it('el resultado abre la app sin avisos ni scripts', () => {
    const html = paginaResultado('contrasena-actualizada');

    expect(html).toContain('<a class="boton" href="ubbike://abrir">Ingresar a UBBike</a>');
    expect(html).not.toContain('<script');
  });
});

describe('confirmación del correo', () => {
  it('la página explica qué hace el botón y muestra el correo', () => {
    const html = paginaFormulario('verificar-correo', token, enlace(false));

    expect(html).toContain(
      'Toca el botón para confirmar que <strong>ana@<wbr>alumnos.ubiobio.cl</strong> es tu correo'
    );
    expect(html).toContain('Confirmar mi correo');
  });

  it('un correo largo se parte tras la arroba y no se sale de la tarjeta en el celular', () => {
    const html = paginaFormulario('verificar-correo', token, {
      ...enlace(false),
      correo: 'catalina.fernandez2024@alumnos.ubiobio.cl'
    });

    expect(html).toContain('<strong>catalina.fernandez2024@<wbr>alumnos.ubiobio.cl</strong>');
    expect(html).toMatch(/main\{[^}]*overflow-wrap:anywhere/);
    expect(html).toMatch(/<footer>¿Necesitas ayuda\? Escríbenos a [^<]*@<wbr>/);
  });

  it('al confirmar indica el siguiente paso y ofrece abrir la app', () => {
    const html = paginaResultado('correo-verificado');

    expect(html).toContain('<h1>Correo confirmado</h1>');
    expect(html).toContain('Abre la app e inicia sesión');
    expect(html).toContain('Ingresar a UBBike');
    expect(html).toContain('¿Estás en el computador?');
  });

  it('un enlace vencido ofrece enviar uno nuevo con el mismo token', () => {
    const html = paginaError('Enlace vencido', 'Por seguridad el enlace dura 24 horas.', token);

    expect(html).toContain('<form method="post" action="/enlaces/reenviar-verificacion"');
    expect(html).toContain(`<input type="hidden" name="token" value="${token}">`);
    expect(html).toContain('Enviarme un enlace nuevo');
    expect(html).toContain('<script src="/enlaces/recursos/formulario-enlace.js');
  });

  it('los demás errores no ofrecen reenviar', () => {
    const html = paginaError('Enlace no válido', 'Este enlace ya se usó.');

    expect(html).not.toContain('<form');
    expect(html).not.toContain('<script');
    expect(html).toContain('class="icono peligro"');
    expect(html).not.toContain('class="icono error"');
  });

  it('tras pedir otro enlace pide revisar el correo sin abrir la app', () => {
    const html = paginaResultado('enlace-reenviado');

    expect(html).toContain('<h1>Revisa tu correo</h1>');
    expect(html).toContain('revisa la carpeta de spam');
    expect(html).toContain('class="icono info"');
    expect(html).not.toContain('Ingresar a UBBike');
  });
});
