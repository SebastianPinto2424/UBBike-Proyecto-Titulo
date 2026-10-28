(() => {
  'use strict';

  const validarValor = (escrito, reglas, referencia) => {
    if ('igualA' in reglas) {
      return escrito === (referencia ?? '') ? '' : reglas.mensajeDistinta;
    }
    const normalizar = 'normalizar' in reglas;
    const valor = normalizar ? escrito.trim() : escrito;
    if (!valor) {
      return reglas.obligatorio;
    }
    if (valor.length > Number(reglas.maximo)) {
      return reglas.mensajeMaximo;
    }
    const comparable = normalizar ? valor.replace(/\s+/g, ' ') : valor;
    if (valor.length < Number(reglas.minimo || 0) || !new RegExp(reglas.patron).test(comparable)) {
      return reglas.mensajeFormato;
    }
    return '';
  };

  if (typeof module === 'object' && module.exports) {
    module.exports = { validarValor };
    return;
  }

  const mostrarError = (entrada, mensaje) => {
    const error = document.getElementById(`${entrada.id}-error`);
    entrada.closest('.grupo').classList.toggle('invalido', Boolean(mensaje));
    if (mensaje) {
      entrada.setAttribute('aria-invalid', 'true');
    } else {
      entrada.removeAttribute('aria-invalid');
    }
    error.textContent = mensaje;
    error.hidden = !mensaje;
  };

  const formulario = document.querySelector('form[data-formulario]');

  if (formulario) {
    const boton = formulario.querySelector('button[type="submit"]');
    const entradas = Array.from(
      formulario.querySelectorAll('input[data-obligatorio], input[data-igual-a]')
    );

    boton.addEventListener('mousedown', (evento) => evento.preventDefault());
    formulario.addEventListener('submit', (evento) => {
      const errores = entradas.map((entrada) => {
        const referencia = entrada.dataset.igualA
          ? document.getElementById(entrada.dataset.igualA).value
          : undefined;
        const mensaje = validarValor(entrada.value, entrada.dataset, referencia);
        mostrarError(entrada, mensaje);
        return mensaje;
      });
      if (errores.some(Boolean)) {
        evento.preventDefault();
        return;
      }
      boton.disabled = true;
      boton.classList.add('cargando');
    });

    window.addEventListener('pageshow', () => {
      boton.disabled = false;
      boton.classList.remove('cargando');
    });
  }

  document.querySelectorAll('[data-alternar]').forEach((alternar) => {
    const entradas = alternar
      .getAttribute('aria-controls')
      .split(' ')
      .map((id) => document.getElementById(id))
      .filter(Boolean);
    const [ver, ocultar] = alternar.querySelectorAll('svg');
    alternar.hidden = false;
    alternar.addEventListener('mousedown', (evento) => evento.preventDefault());
    alternar.addEventListener('click', () => {
      const mostrar = entradas[0].type === 'password';
      entradas.forEach((entrada) => {
        const { selectionStart, selectionEnd } = entrada;
        entrada.type = mostrar ? 'text' : 'password';
        if (document.activeElement === entrada) {
          entrada.setSelectionRange(selectionStart, selectionEnd);
        }
      });
      const texto = mostrar ? 'Ocultar contraseña' : 'Mostrar contraseña';
      alternar.setAttribute('aria-label', texto);
      alternar.title = texto;
      ver.toggleAttribute('hidden', mostrar);
      ocultar.toggleAttribute('hidden', !mostrar);
    });
  });
})();
