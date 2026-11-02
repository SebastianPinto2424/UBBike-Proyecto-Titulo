import { escaparHtml } from '../../comun/utilidades/html';
import {
  CORREO_SOPORTE,
  envolverHtml,
  fechaLegible,
  etiquetaRol,
  capitalizar,
  boton,
  pieHtml,
  pieTexto,
  propositoCuenta,
  saludoHtml,
  saludoTexto,
  usaBicicleta
} from './correo.formato';

type DatosConfirmacionCorreo = {
  nombre: string;
  correo: string;
  enlace: string;
  venceEn: Date;
  asunto: string;
  motivo: string;
  despues: string;
  aviso: string;
  vistaPrevia: string;
};

const crearCorreoConfirmacion = (datos: DatosConfirmacionCorreo) => {
  const vence = fechaLegible(datos.venceEn);
  return {
    asunto: datos.asunto,
    texto: `${saludoTexto(datos.nombre)}

${datos.motivo}, confirma que ${datos.correo} es tu correo abriendo este enlace:
${datos.enlace}

El enlace es de un solo uso y vence el ${vence}. ${datos.despues}
${datos.aviso}
${pieTexto()}`,
    html: envolverHtml(
      `
    <h2 style="color: #014898;">Confirma tu correo</h2>
    ${saludoHtml(datos.nombre)}
    <p>${escaparHtml(datos.motivo)}, confirma que <strong>${escaparHtml(datos.correo)}</strong> es tu correo.</p>
    ${boton(datos.enlace, 'Confirmar mi correo')}
    <p>El enlace es de <strong>un solo uso</strong> y vence el <strong>${escaparHtml(vence)}</strong>. ${escaparHtml(datos.despues)}</p>
    <p>${escaparHtml(datos.aviso)}</p>
    ${pieHtml()}
  `,
      datos.vistaPrevia
    )
  };
};

export const crearCorreoVerificacion = (
  nombre: string,
  correo: string,
  enlace: string,
  venceEn: Date
) =>
  crearCorreoConfirmacion({
    nombre,
    correo,
    enlace,
    venceEn,
    asunto: 'Confirma tu correo para activar tu cuenta UBBike',
    motivo: 'Gracias por registrarte en UBBike. Para activar tu cuenta',
    despues: 'Después podrás iniciar sesión en la app.',
    aviso:
      'Si no creaste esta cuenta, puedes ignorar este correo; sin esta confirmación la cuenta no se activa.',
    vistaPrevia: 'Un último paso para activar tu cuenta UBBike: confirma tu correo.'
  });

export const crearCorreoNuevoCorreo = (
  nombre: string,
  correo: string,
  enlace: string,
  venceEn: Date
) =>
  crearCorreoConfirmacion({
    nombre,
    correo,
    enlace,
    venceEn,
    asunto: 'Confirma tu nuevo correo en UBBike',
    motivo: 'Administración actualizó el correo de tu cuenta UBBike. Para seguir usándola',
    despues: 'Después podrás seguir ingresando a la app con este correo.',
    aviso: `Si no reconoces este cambio, escríbenos a ${CORREO_SOPORTE}.`,
    vistaPrevia: 'Confirma tu nuevo correo para seguir usando UBBike.'
  });

export const crearCorreoCompletarRegistro = (correoUsuario: string, enlace: string) => ({
  asunto: 'Activa tu cuenta UBBike para gestionar tu bicicleta',
  texto: `${saludoTexto()}

Un guardia registró un movimiento de tu bicicleta el ${fechaLegible()}, pero esta cuenta (${correoUsuario}) aún no está activa.
Actívala para ver tu historial y generar tus códigos QR (el enlace vence en 24 horas):
${enlace}

Si no reconoces este movimiento, escríbenos a ${CORREO_SOPORTE}.
${pieTexto()}`,
  html: envolverHtml(
    `
    <h2 style="color: #014898;">Activa tu cuenta UBBike</h2>
    ${saludoHtml()}
    <p>Un guardia registró un movimiento de tu bicicleta el <strong>${escaparHtml(fechaLegible())}</strong>, pero esta cuenta aún no está activa.</p>
    <p>Actívala para ver tu historial y generar tus códigos QR.</p>
    ${boton(enlace, 'Activar mi cuenta')}
    <p>El enlace vence en <strong>24 horas</strong>. Si no reconoces este movimiento, contáctanos.</p>
    ${pieHtml()}
  `,
    'Un guardia registró tu bicicleta. Activa tu cuenta para ver tu historial.'
  )
});

export const crearCorreoCuentaVerificada = (nombre: string, rol?: string) => {
  const fecha = fechaLegible();
  const conBicicleta = usaBicicleta(rol);
  const correoConfirmado = conBicicleta ? 'tu correo institucional' : 'tu correo';
  const proposito = propositoCuenta(rol);
  const ingresar = 'Inicia sesión en la app con tu correo y tu contraseña.';
  return {
    asunto: 'Tu cuenta UBBike está activa',
    texto: `${saludoTexto(nombre)}

Confirmamos ${correoConfirmado} y tu cuenta quedó activa el ${fecha}. Desde ahora puedes usar UBBike para ${proposito}.

${
  conBicicleta
    ? `Para comenzar:
1. ${ingresar}
2. En la sección Bicicletas, registra tu bicicleta o revisa sus datos.
3. Al llegar al bicicletero, abre la sección QR, toca Generar QR y muéstraselo al guardia para registrar el ingreso o el retiro.`
    : ingresar
}
${pieTexto()}`,
    html: envolverHtml(
      `
    <h2 style="color: #014898;">Tu cuenta está activa</h2>
    ${saludoHtml(nombre)}
    <p>Confirmamos ${correoConfirmado} y tu cuenta quedó activa el <strong>${escaparHtml(fecha)}</strong>. Desde ahora puedes usar UBBike para ${proposito}.</p>
    ${
      conBicicleta
        ? `<p>Para comenzar:</p>
    <ol style="padding-left:20px;">
      <li>${ingresar}</li>
      <li>En la sección <strong>Bicicletas</strong>, registra tu bicicleta o revisa sus datos.</li>
      <li>Al llegar al bicicletero, abre la sección <strong>QR</strong>, toca <strong>Generar QR</strong> y muéstraselo al guardia para registrar el ingreso o el retiro.</li>
    </ol>`
        : `<p>${ingresar}</p>`
    }
    ${pieHtml()}
  `,
      `Ya puedes ${proposito}.`
    )
  };
};

export const crearCorreoCuentaAdministrativa = (
  nombre: string,
  enlace: string,
  horasExpiracion: number,
  rol?: string
) => {
  const rolTexto = etiquetaRol(rol);
  const fecha = fechaLegible();
  return {
    asunto: `Activa tu cuenta de ${rolTexto} en UBBike`,
    texto: `${saludoTexto(nombre)}

La administración de UBBike creó tu cuenta de ${rolTexto} el ${fecha}. Con ella podrás ${propositoCuenta(rol)}.
Para activarla, crea la contraseña con la que ingresarás a la app:
${enlace}

El enlace es de un solo uso y vence en ${horasExpiracion} horas. Si vence, abre la app y, en el inicio de sesión, toca "¿Has olvidado tu contraseña?" para recibir uno nuevo.
${pieTexto({ antiPhishing: true })}`,
    html: envolverHtml(
      `
    <h2 style="color: #014898;">Te damos la bienvenida a UBBike</h2>
    ${saludoHtml(nombre)}
    <p>La administración de UBBike creó tu cuenta de <strong>${escaparHtml(rolTexto)}</strong> el ${escaparHtml(fecha)}. Con ella podrás ${propositoCuenta(rol)}.</p>
    <p>Para activarla, crea la contraseña con la que ingresarás a la app.</p>
    ${boton(enlace, 'Crear mi contraseña')}
    <p>El enlace es de <strong>un solo uso</strong> y vence en ${horasExpiracion} horas. Si vence, abre la app y, en el inicio de sesión, toca <strong>¿Has olvidado tu contraseña?</strong> para recibir uno nuevo.</p>
    ${pieHtml({ antiPhishing: true })}
  `,
      `Crea tu contraseña para activar tu cuenta de ${rolTexto}.`
    )
  };
};

export const crearCorreoCuentaDesactivada = (nombre: string) => {
  const fecha = fechaLegible();
  return {
    asunto: 'Alerta de seguridad: tu cuenta UBBike fue desactivada',
    texto: `${saludoTexto(nombre)}

Tu cuenta UBBike fue desactivada el ${fecha}. No podrás iniciar sesión mientras siga así.
Si no esperabas esto, escríbenos de inmediato a ${CORREO_SOPORTE}.
${pieTexto()}`,
    html: envolverHtml(`
    <h2 style="color: #014898;">Tu cuenta fue desactivada</h2>
    ${saludoHtml(nombre)}
    <p>Tu cuenta UBBike fue desactivada el <strong>${escaparHtml(fecha)}</strong>. No podrás iniciar sesión mientras siga así.</p>
    <p>Si no esperabas esto, contáctanos de inmediato.</p>
    ${pieHtml()}
  `)
  };
};

export const crearCorreoCuentaReactivada = (nombre: string) => {
  const fecha = fechaLegible();
  return {
    asunto: 'Tu cuenta UBBike fue reactivada',
    texto: `${saludoTexto(nombre)}

Administración reactivó tu cuenta el ${fecha}. Ya puedes iniciar sesión con tu contraseña habitual.
Si no reconoces esta acción, escríbenos a ${CORREO_SOPORTE}.
${pieTexto()}`,
    html: envolverHtml(`
    <h2 style="color: #014898;">Tu cuenta fue reactivada</h2>
    ${saludoHtml(nombre)}
    <p>Administración reactivó tu cuenta el <strong>${escaparHtml(fecha)}</strong>. Ya puedes iniciar sesión con tu contraseña habitual.</p>
    <p>Si no reconoces esta acción, contáctanos.</p>
    ${pieHtml()}
  `)
  };
};

export const crearCorreoRolActualizado = (
  nombre: string,
  rolAnterior: string,
  rolNuevo: string
) => {
  const fecha = fechaLegible();
  const antes = capitalizar(etiquetaRol(rolAnterior));
  const ahora = capitalizar(etiquetaRol(rolNuevo));
  return {
    asunto: `Alerta de seguridad: tu rol en UBBike cambió a ${ahora}`,
    texto: `${saludoTexto(nombre)}

Administración cambió tu rol el ${fecha}.
Antes: ${antes} — Ahora: ${ahora}.
Esto modifica tus permisos dentro de la app. Si no reconoces este cambio, escríbenos de inmediato a ${CORREO_SOPORTE}.
${pieTexto()}`,
    html: envolverHtml(`
    <h2 style="color: #014898;">Tu rol cambió</h2>
    ${saludoHtml(nombre)}
    <p>Administración cambió tu rol el <strong>${escaparHtml(fecha)}</strong>.</p>
    <ul>
      <li><strong>Antes:</strong> ${escaparHtml(antes)}</li>
      <li><strong>Ahora:</strong> ${escaparHtml(ahora)}</li>
    </ul>
    <p>Esto modifica tus permisos dentro de la app. Si no reconoces este cambio, contáctanos de inmediato.</p>
    ${pieHtml()}
  `)
  };
};

export const crearCorreoCambioContrasena = (nombre: string, enlace: string) => {
  const fecha = fechaLegible();
  return {
    asunto: 'Restablece tu contraseña de UBBike',
    texto: `${saludoTexto(nombre)}

Recibimos una solicitud para restablecer la contraseña de esta cuenta el ${fecha}.
Si fuiste tú, crea una nueva (enlace de un solo uso, vence en 30 minutos):
${enlace}

Este enlace reemplaza cualquier enlace de restablecimiento enviado antes.
Si no lo solicitaste, ignora este correo: tu contraseña no ha cambiado.
${pieTexto({ antiPhishing: true })}`,
    html: envolverHtml(
      `
    <h2 style="color: #014898;">Restablece tu contraseña</h2>
    ${saludoHtml(nombre)}
    <p>Recibimos una solicitud para restablecer la contraseña de esta cuenta el <strong>${escaparHtml(fecha)}</strong>.</p>
    ${boton(enlace, 'Restablecer contraseña')}
    <p>El enlace es de <strong>un solo uso</strong> y vence en <strong>30 minutos</strong>. Reemplaza cualquier enlace de restablecimiento enviado antes, así que usa siempre el correo más reciente.</p>
    <p>Si no lo solicitaste, ignora este correo: <strong>tu contraseña no ha cambiado</strong>.</p>
    ${pieHtml({ antiPhishing: true })}
  `,
      'Usa este enlace para crear una nueva contraseña. Vence en 30 minutos.'
    )
  };
};

export const crearCorreoContrasenaActualizada = (nombre: string) => {
  const fecha = fechaLegible();
  return {
    asunto: 'Alerta de seguridad: tu contraseña de UBBike fue cambiada',
    texto: `${saludoTexto(nombre)}

Tu contraseña UBBike se cambió correctamente el ${fecha}.
¿No fuiste tú? Tu cuenta podría estar en riesgo: restablece tu contraseña de inmediato y escríbenos a ${CORREO_SOPORTE}.
${pieTexto({ antiPhishing: true })}`,
    html: envolverHtml(`
    <h2 style="color: #014898;">Tu contraseña fue cambiada</h2>
    ${saludoHtml(nombre)}
    <p>Tu contraseña UBBike se cambió correctamente el <strong>${escaparHtml(fecha)}</strong>.</p>
    <p><strong>¿No fuiste tú?</strong> Tu cuenta podría estar en riesgo. Restablece tu contraseña de inmediato y escríbenos a
       <a href="mailto:${escaparHtml(CORREO_SOPORTE)}" style="color:#014898;">${escaparHtml(CORREO_SOPORTE)}</a>.</p>
    ${pieHtml({ antiPhishing: true })}
  `)
  };
};

export const crearCorreoCuentaActivada = (nombre: string, rol?: string) => {
  const rolTexto = etiquetaRol(rol);
  const fecha = fechaLegible();
  return {
    asunto: `Tu cuenta de ${rolTexto} en UBBike quedó activa`,
    texto: `${saludoTexto(nombre)}

Creaste tu contraseña y tu cuenta de ${rolTexto} quedó activa el ${fecha}.
Ya puedes iniciar sesión en la app UBBike con este correo y la contraseña que creaste.
Si no fuiste tú quien activó esta cuenta, escríbenos a ${CORREO_SOPORTE}.
${pieTexto({ antiPhishing: true })}`,
    html: envolverHtml(`
    <h2 style="color: #014898;">Tu cuenta está activa</h2>
    ${saludoHtml(nombre)}
    <p>Creaste tu contraseña y tu cuenta de <strong>${escaparHtml(rolTexto)}</strong> quedó activa el <strong>${escaparHtml(fecha)}</strong>.</p>
    <p>Ya puedes iniciar sesión en la app UBBike con este correo y la contraseña que creaste.</p>
    <p>Si no fuiste tú quien activó esta cuenta, escríbenos a
       <a href="mailto:${escaparHtml(CORREO_SOPORTE)}" style="color:#014898;">${escaparHtml(CORREO_SOPORTE)}</a>.</p>
    ${pieHtml({ antiPhishing: true })}
  `)
  };
};
