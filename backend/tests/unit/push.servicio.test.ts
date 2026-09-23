import '../helpers/env-setup';
jest.mock('../../src/configuracion/firebase', () => ({ obtenerFirebase: jest.fn() }));
jest.mock('firebase-admin/messaging', () => ({ getMessaging: jest.fn() }));
jest.mock('../../src/modulos/notificaciones/dispositivo.repositorio', () => ({
  listarTokensDeUsuario: jest.fn(),
  eliminarTokens: jest.fn()
}));
import { getMessaging } from 'firebase-admin/messaging';
import { obtenerFirebase } from '../../src/configuracion/firebase';
import { entorno } from '../../src/configuracion/entorno';
import * as dispositivos from '../../src/modulos/notificaciones/dispositivo.repositorio';
import { enviarPushAUsuario } from '../../src/modulos/notificaciones/push.servicio';

const ambienteOriginal = entorno.ambiente;
const enviar = jest.fn();
const push = { titulo: 'Incidencia', mensaje: 'Revisar acceso', datos: { cantidad: 2 } };
beforeEach(() => {
  entorno.ambiente = 'test';
  jest.mocked(obtenerFirebase).mockReturnValue({} as never);
  jest.mocked(getMessaging).mockReturnValue({ sendEachForMulticast: enviar } as never);
  jest.mocked(dispositivos.listarTokensDeUsuario).mockResolvedValue(['token-1', 'token-2']);
  enviar.mockReset();
});
afterEach(() => { entorno.ambiente = ambienteOriginal; });

it('no confirma una entrega sin Firebase en producción', async () => {
  entorno.ambiente = 'production';
  jest.mocked(obtenerFirebase).mockReturnValue(null);
  await expect(enviarPushAUsuario('usuario', push)).rejects.toThrow('Firebase no está disponible');
  expect(enviar).not.toHaveBeenCalled();
});
it('permite desarrollo sin Firebase ni envíos externos', async () => {
  jest.mocked(obtenerFirebase).mockReturnValue(null);
  await expect(enviarPushAUsuario('usuario', push)).resolves.toBeUndefined();
  expect(enviar).not.toHaveBeenCalled();
});
it('no envía cuando no hay dispositivos registrados', async () => {
  jest.mocked(dispositivos.listarTokensDeUsuario).mockResolvedValue([]);
  await enviarPushAUsuario('usuario', push);
  expect(enviar).not.toHaveBeenCalled();
});
it('elimina tokens inválidos y conserva los que recibieron el aviso', async () => {
  enviar.mockResolvedValue({ responses: [
    { success: true },
    { success: false, error: { code: 'messaging/registration-token-not-registered' } }
  ] });
  await enviarPushAUsuario('usuario', push);
  expect(dispositivos.eliminarTokens).toHaveBeenCalledWith(['token-2']);
  expect(enviar).toHaveBeenCalledWith(expect.objectContaining({ data: { cantidad: '2' } }));
});
it('un fallo temporal parcial se propaga para que la cola reintente', async () => {
  enviar.mockResolvedValue({ responses: [
    { success: true },
    { success: false, error: { code: 'messaging/server-unavailable' } }
  ] });
  await expect(enviarPushAUsuario('usuario', push)).rejects.toThrow('reintentar');
  expect(dispositivos.eliminarTokens).not.toHaveBeenCalled();
});
