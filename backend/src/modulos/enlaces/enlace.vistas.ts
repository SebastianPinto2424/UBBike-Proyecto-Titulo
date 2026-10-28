import { escaparHtml } from '../../comun/utilidades/html';
import { scriptFormulario } from './enlace.recursos';
import type { AccionEnlace, ResultadoEnlace } from './enlace.servicio';
import { reglaConfirmacion, reglasFormulario, type ReglaCampo } from './enlace.validacion';
import type { EnlaceValido, ErroresFormulario } from './formulario-enlace.servicio';

type Icono = 'correo' | 'candado' | 'persona' | 'listo' | 'alerta';

const trazosIcono: Record<Icono, string> = {
  correo:
    'M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4-8 5-8-5V6l8 5 8-5v2z',
  candado:
    'M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z',
  persona:
    'M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z',
  listo:
    'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z',
  alerta:
    'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z'
};

const trazosCampo = {
  persona:
    'M12 5.9c1.16 0 2.1.94 2.1 2.1s-.94 2.1-2.1 2.1S9.9 9.16 9.9 8s.94-2.1 2.1-2.1m0 9c2.97 0 6.1 1.46 6.1 2.1v1.1H5.9V17c0-.64 3.13-2.1 6.1-2.1M12 4C9.79 4 8 5.79 8 8s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4zm0 9c-2.67 0-8 1.34-8 4v3h16v-3c0-2.66-5.33-4-8-4z',
  candado:
    'M12 17c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm6-9h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zM8.9 6c0-1.71 1.39-3.1 3.1-3.1s3.1 1.39 3.1 3.1v2H8.9V6zM18 20H6V10h12v10z',
  ver: 'M12 6c3.79 0 7.17 2.13 8.82 5.5C19.17 14.87 15.79 17 12 17s-7.17-2.13-8.82-5.5C4.83 8.13 8.21 6 12 6m0-2C7 4 2.73 7.11 1 11.5 2.73 15.89 7 19 12 19s9.27-3.11 11-7.5C21.27 7.11 17 4 12 4zm0 5c1.38 0 2.5 1.12 2.5 2.5S13.38 14 12 14s-2.5-1.12-2.5-2.5S10.62 9 12 9m0-2c-2.48 0-4.5 2.02-4.5 4.5S9.52 16 12 16s4.5-2.02 4.5-4.5S14.48 7 12 7z',
  ocultar:
    'M12 6c3.79 0 7.17 2.13 8.82 5.5-.59 1.22-1.42 2.27-2.41 3.12l1.41 1.41c1.39-1.23 2.49-2.77 3.18-4.53C21.27 7.11 17 4 12 4c-1.27 0-2.49.2-3.64.57l1.65 1.65C10.66 6.09 11.32 6 12 6zm-1.07 1.14L13 9.21c.57.25 1.03.71 1.28 1.28l2.07 2.07c.08-.34.14-.7.14-1.07C16.5 9.01 14.48 7 12 7c-.37 0-.72.05-1.07.14zM2.01 3.87l2.68 2.68C3.06 7.83 1.77 9.53 1 11.5 2.73 15.89 7 19 12 19c1.52 0 2.98-.29 4.32-.82l3.42 3.42 1.41-1.41L3.42 2.45 2.01 3.87zm7.5 7.5 2.61 2.61c-.04.01-.08.02-.12.02-1.38 0-2.5-1.12-2.5-2.5 0-.05.01-.08.01-.13zm-3.4-3.4 1.75 1.75c-.23.55-.36 1.15-.36 1.78 0 2.48 2.02 4.5 4.5 4.5.63 0 1.23-.13 1.77-.36l.98.98c-.88.24-1.8.38-2.75.38-3.79 0-7.17-2.13-8.82-5.5.7-1.43 1.72-2.61 2.93-3.53z'
};

const tonoIcono: Record<Icono, 'info' | 'exito' | 'peligro'> = {
  correo: 'info',
  candado: 'info',
  persona: 'info',
  listo: 'exito',
  alerta: 'peligro'
};

const abrirApp = 'ubbike://abrir';

const estilos = `
*{box-sizing:border-box}
[hidden]{display:none!important}
body{margin:0;min-height:100vh;background:#F3F7FB;color:#0B2F4A;font-family:Roboto,"Segoe UI",system-ui,-apple-system,sans-serif;-webkit-text-size-adjust:100%}
main{max-width:460px;margin:0 auto;padding:32px 20px 24px}
.marca{text-align:center;margin-bottom:22px}
.marca img{display:block;height:68px;width:auto;margin:0 auto}
.tarjeta{background:#FFFFFF;border:1px solid #D7E4EF;border-radius:8px;box-shadow:0 1px 3px rgba(11,47,74,.08);padding:28px 22px}
.icono{width:64px;height:64px;margin:0 auto 14px;border-radius:50%;display:flex;align-items:center;justify-content:center}
.icono svg{width:34px;height:34px;fill:currentColor}
.icono.info{background:#EAF5FF;color:#0B83BD}
.icono.exito{background:#E3F4EE;color:#008866}
.icono.peligro{background:#FDE8E8;color:#E41B1A}
h1{margin:0 0 10px;text-align:center;font-size:24px;font-weight:900;color:#0B2F4A}
p{margin:0 0 16px;line-height:1.5;color:#35506A;text-align:center}
strong{color:#0B2F4A}
.grupo{margin-top:24px}
.campo{position:relative}
.campo input{display:block;width:100%;height:48px;margin:0;padding:0 19px 0 51px;border:1px solid #0B2F4A;border-radius:15px;background:#FFFFFF;color:#0B2F4A;font:inherit;font-size:16px;outline:0;-webkit-appearance:none;appearance:none}
.campo.con-alternar input{padding-right:51px}
.campo input::-ms-reveal,.campo input::-ms-clear{display:none}
.campo input:focus{box-shadow:inset 0 0 0 1px #0B2F4A}
.campo input:-webkit-autofill{-webkit-box-shadow:inset 0 0 0 48px #FFFFFF;-webkit-text-fill-color:#0B2F4A}
.campo label{position:absolute;top:24px;left:52px;max-width:calc(100% - 104px);padding:0;transform:translateY(-50%);color:#9E9E9E;font-size:16px;line-height:16px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;pointer-events:none;transition:top .167s,left .167s,padding .167s,font-size .167s,color .167s}
.campo input:focus+label,.campo input:not(:placeholder-shown)+label{top:0;left:20px;max-width:calc(100% - 40px);padding:0 4px;background:#FFFFFF;color:#0B83BD;font-size:12px;line-height:12px;font-weight:800}
.prefijo{position:absolute;top:12px;left:12px;width:24px;height:24px;fill:#0B83BD;pointer-events:none}
.alternar{position:absolute;top:0;right:0;width:48px;height:48px;padding:12px;border:0;border-radius:50%;background:transparent;color:#0B2F4A;cursor:pointer}
.alternar svg{display:block;width:24px;height:24px;fill:currentColor}
.alternar:focus-visible{outline:2px solid #0B83BD;outline-offset:-6px}
.ayuda,.error{margin:4px 0 0;padding:0 24px;font-size:12px;line-height:16px;text-align:left}
.ayuda{display:none;color:#35506A}
.grupo:focus-within .ayuda{display:block}
.grupo.invalido .ayuda{display:none}
.error{color:#E41B1A}
.grupo.invalido input{border-color:#E41B1A}
.grupo.invalido input:focus{box-shadow:inset 0 0 0 1px #E41B1A}
.grupo.invalido .alternar{color:#E41B1A}
.boton{display:block;width:100%;margin-top:26px;padding:15px 40px;border:0;border-radius:15px;background:#0B83BD;color:#FFFFFF;font:inherit;font-size:16px;font-weight:700;line-height:20px;text-align:center;text-decoration:none;cursor:pointer}
.boton:disabled{background:#9E9E9E;cursor:default}
.boton:focus-visible{outline:3px solid #0E2236;outline-offset:2px}
.girando{display:none;width:18px;height:18px;margin:1px auto;border:2px solid rgba(255,255,255,.35);border-top-color:#FFFFFF;border-radius:50%;animation:girar .8s linear infinite}
.cargando .texto{display:none}
.cargando .girando{display:block}
@keyframes girar{to{transform:rotate(360deg)}}
@media (prefers-reduced-motion:reduce){.campo label{transition:none}}
.nota{margin:14px 0 0;font-size:13px}
footer{margin-top:20px;text-align:center;font-size:12px;color:#35506A}
`;

const icono = (nombre: Icono) =>
  `<div class="icono ${tonoIcono[nombre]}"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="${trazosIcono[nombre]}"/></svg></div>`;

const pagina = (
  titulo: string,
  contenido: string,
  conFormulario = false
): string => `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<meta name="theme-color" content="#F3F7FB">
<title>${escaparHtml(titulo)} · UBBike</title>
<style>${estilos}</style>${conFormulario ? `\n<script src="${scriptFormulario}" defer></script>` : ''}
</head>
<body>
<main>
<div class="marca"><img src="/enlaces/recursos/ubbike-logo.png" alt="UBBike" width="198" height="68"></div>
<section class="tarjeta">
${contenido}
</section>
<footer>¿Necesitas ayuda? Escríbenos a soporte@ubbike.cl</footer>
</main>
</body>
</html>`;

const svg = (trazo: string, clase?: string, oculto = false) =>
  `<svg${clase ? ` class="${clase}"` : ''} viewBox="0 0 24 24" aria-hidden="true" focusable="false"${oculto ? ' hidden' : ''}><path d="${trazo}"/></svg>`;

const atributosRegla = (regla: ReglaCampo) =>
  [
    `data-obligatorio="${escaparHtml(regla.mensajes.obligatorio)}"`,
    `data-maximo="${regla.maximo}"`,
    `data-mensaje-maximo="${escaparHtml(regla.mensajes.maximo)}"`,
    regla.minimo ? `data-minimo="${regla.minimo}"` : '',
    `data-patron="${escaparHtml(regla.patron.source)}"`,
    `data-mensaje-formato="${escaparHtml(regla.mensajes.formato)}"`,
    regla.normalizar ? 'data-normalizar' : ''
  ]
    .filter(Boolean)
    .join(' ');

const botonAlternar = (controla: string) =>
  `<button class="alternar" type="button" data-alternar aria-controls="${controla}" aria-label="Mostrar contraseña" title="Mostrar contraseña" hidden>${svg(trazosCampo.ver)}${svg(trazosCampo.ocultar, undefined, true)}</button>`;

const campo = (opciones: {
  nombre: keyof ErroresFormulario;
  etiqueta: string;
  trazo: string;
  tipo: 'text' | 'password';
  atributos: string;
  ayuda: string;
  valor?: string;
  error?: string;
  alternar?: string;
}) => {
  const { nombre, etiqueta, trazo, tipo, atributos, ayuda, valor, error, alternar } = opciones;
  const id = `campo-${nombre}`;

  return `<div class="grupo${error ? ' invalido' : ''}">
<div class="campo${alternar ? ' con-alternar' : ''}">
${svg(trazo, 'prefijo')}
<input id="${id}" name="${nombre}" type="${tipo}" placeholder=" " required ${atributos} aria-describedby="${id}-ayuda ${id}-error"${error ? ' aria-invalid="true"' : ''}${valor ? ` value="${escaparHtml(valor)}"` : ''}>
<label for="${id}">${etiqueta}</label>${alternar ? `\n${botonAlternar(alternar)}` : ''}
</div>
<p class="ayuda" id="${id}-ayuda">${escaparHtml(ayuda)}</p>
<p class="error" id="${id}-error" role="alert"${error ? '' : ' hidden'}>${error ? escaparHtml(error) : ''}</p>
</div>`;
};

const campoNombre = (valor?: string, error?: string) =>
  campo({
    nombre: 'nombre',
    etiqueta: 'Nombre completo',
    trazo: trazosCampo.persona,
    tipo: 'text',
    atributos: `autocomplete="name" autocapitalize="words" spellcheck="false" ${atributosRegla(reglasFormulario.nombre)}`,
    ayuda: reglasFormulario.nombre.ayuda,
    valor,
    error
  });

const atributosClave =
  'autocomplete="new-password" autocapitalize="none" autocorrect="off" spellcheck="false"';

const camposContrasena = (etiqueta: string, errores: ErroresFormulario) =>
  [
    campo({
      nombre: 'contrasena',
      etiqueta,
      trazo: trazosCampo.candado,
      tipo: 'password',
      atributos: `${atributosClave} ${atributosRegla(reglasFormulario.contrasena)}`,
      ayuda: reglasFormulario.contrasena.ayuda,
      error: errores.contrasena,
      alternar: 'campo-contrasena'
    }),
    campo({
      nombre: 'confirmacion',
      etiqueta: `Confirmar ${etiqueta.toLowerCase()}`,
      trazo: trazosCampo.candado,
      tipo: 'password',
      atributos: `${atributosClave} data-igual-a="campo-contrasena" data-mensaje-distinta="${escaparHtml(reglaConfirmacion.mensaje)}"`,
      ayuda: reglaConfirmacion.ayuda,
      error: errores.confirmacion,
      alternar: 'campo-confirmacion'
    })
  ].join('\n');

const usuarioOculto = (correo: string) =>
  `<input type="email" autocomplete="username" value="${escaparHtml(correo)}" hidden>`;

const formulario = (accion: AccionEnlace, token: string, campos: string, boton: string) =>
  `<form method="post" action="/enlaces/${accion}" novalidate data-formulario>
<input type="hidden" name="token" value="${escaparHtml(token)}">${campos ? `\n${campos}` : ''}
<button class="boton" type="submit"><span class="texto">${boton}</span><span class="girando" aria-hidden="true"></span></button>
</form>`;

export const paginaFormulario = (
  accion: AccionEnlace,
  token: string,
  enlace: EnlaceValido,
  errores: ErroresFormulario = {},
  nombre?: string
): string => {
  if (accion === 'verificar-correo') {
    return pagina(
      'Confirma tu correo',
      `${icono('correo')}
<h1>Confirma tu correo</h1>
<p>Toca el botón para confirmar que <strong>${escaparHtml(enlace.correo)}</strong> es tu correo y activar tu cuenta UBBike.</p>
${formulario(accion, token, '', 'Confirmar mi correo')}`,
      true
    );
  }

  if (accion === 'completar-registro') {
    const campos = [
      usuarioOculto(enlace.correo),
      campoNombre(nombre, errores.nombre),
      camposContrasena('Contraseña', errores)
    ].join('\n');

    return pagina(
      'Activa tu cuenta',
      `${icono('persona')}
<h1>Activa tu cuenta</h1>
<p>Un guardia registró tu bicicleta en UBBike. Completa tus datos para activar tu cuenta.</p>
${formulario(accion, token, campos, 'Activar mi cuenta')}`,
      true
    );
  }

  const titulo = enlace.activacion ? 'Crea tu contraseña' : 'Restablece tu contraseña';
  const presentacion = enlace.activacion
    ? 'Te damos la bienvenida a UBBike. Crea la contraseña con la que vas a ingresar a la app.'
    : 'Crea una nueva contraseña para tu cuenta UBBike.';
  const boton = enlace.activacion ? 'Crear contraseña y activar' : 'Guardar nueva contraseña';
  const campos = [
    usuarioOculto(enlace.correo),
    camposContrasena(enlace.activacion ? 'Contraseña' : 'Nueva contraseña', errores)
  ].join('\n');

  return pagina(
    titulo,
    `${icono('candado')}
<h1>${titulo}</h1>
<p>${presentacion}</p>
${formulario(accion, token, campos, boton)}`,
    true
  );
};

const resultados: Record<
  ResultadoEnlace,
  { titulo: string; mensaje: string; icono?: Icono; abrirApp?: false }
> = {
  'correo-verificado': {
    titulo: '¡Correo confirmado!',
    mensaje:
      'Tu cuenta UBBike ya está activa. Abre la app e inicia sesión con tu correo y tu contraseña.'
  },
  'registro-completado': {
    titulo: 'Cuenta activada',
    mensaje:
      'Completaste tu registro. Vuelve a la app e inicia sesión con tu correo institucional y la contraseña que creaste.'
  },
  'cuenta-activada': {
    titulo: 'Cuenta activada',
    mensaje:
      'Tu cuenta quedó lista. Vuelve a la app e inicia sesión con tu correo y la contraseña que acabas de crear.'
  },
  'contrasena-actualizada': {
    titulo: 'Contraseña actualizada',
    mensaje:
      'Tu nueva contraseña ya está activa y cerramos las sesiones abiertas en otros dispositivos. Vuelve a la app e inicia sesión con ella.'
  },
  'enlace-reenviado': {
    titulo: 'Revisa tu correo',
    mensaje:
      'Te enviamos un enlace nuevo para confirmar tu correo. Vence en 24 horas; si no lo ves, revisa la carpeta de spam.',
    icono: 'correo',
    abrirApp: false
  }
};

export const paginaResultado = (resultado: ResultadoEnlace): string => {
  const {
    titulo,
    mensaje,
    icono: iconoResultado = 'listo',
    abrirApp: conBoton
  } = resultados[resultado];
  const accion =
    conBoton === false
      ? ''
      : `
<a class="boton" href="${abrirApp}">Abrir UBBike</a>
<p class="nota">¿Estás en el computador? Abre la app UBBike en tu celular.</p>`;
  return pagina(
    titulo,
    `${icono(iconoResultado)}
<h1>${titulo}</h1>
<p>${mensaje}</p>${accion}`
  );
};

const formularioReenvio = (token: string) =>
  `
<form method="post" action="/enlaces/reenviar-verificacion" data-formulario>
<input type="hidden" name="token" value="${escaparHtml(token)}">
<button class="boton" type="submit"><span class="texto">Enviarme un enlace nuevo</span><span class="girando" aria-hidden="true"></span></button>
</form>`;

export const paginaError = (titulo: string, mensaje: string, reenviarToken?: string): string =>
  pagina(
    titulo,
    `${icono('alerta')}
<h1>${escaparHtml(titulo)}</h1>
<p>${escaparHtml(mensaje)}</p>${reenviarToken ? formularioReenvio(reenviarToken) : ''}`,
    Boolean(reenviarToken)
  );
