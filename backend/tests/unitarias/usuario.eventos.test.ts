import '../apoyo/configurar-entorno';

jest.mock('../../src/tiempo-real/tiempo-real', () => ({
  EventosTiempoReal: { USUARIO: 'usuario' },
  salaRol: (rol: string) => `rol:${rol}`,
  emitirTiempoReal: jest.fn()
}));

import { emitirTiempoReal } from '../../src/tiempo-real/tiempo-real';
import { emitirCambioUsuarios } from '../../src/modulos/usuarios/usuario.eventos';

it('avisa los cambios de usuarios a administración y a central', () => {
  emitirCambioUsuarios();

  expect(emitirTiempoReal).toHaveBeenCalledWith(
    ['rol:ADMINISTRADOR', 'rol:ADMIN_CENTRAL'],
    'usuario'
  );
});
