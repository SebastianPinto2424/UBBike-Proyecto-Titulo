import { getMessaging } from 'firebase-admin/messaging';
import { obtenerFirebase } from '../../configuracion/firebase';
import { entorno } from '../../configuracion/entorno';
import * as dispositivoRepositorio from './dispositivo.repositorio';

type DatosPush = {
  titulo: string;
  mensaje: string;
  tipo?: string;
  datos?: Record<string, unknown>;
};

const aDatosString = (datos?: Record<string, unknown>): Record<string, string> => {
  const resultado: Record<string, string> = {};

  if (!datos) {
    return resultado;
  }

  for (const [clave, valor] of Object.entries(datos)) {
    if (valor !== null && valor !== undefined) {
      resultado[clave] = typeof valor === 'string' ? valor : JSON.stringify(valor);
    }
  }

  return resultado;
};

export const enviarPushAUsuario = async (usuarioId: string, push: DatosPush): Promise<void> => {
  const app = obtenerFirebase();

  if (!app) {
    if (entorno.ambiente === 'production') {
      throw new Error('Firebase no está disponible; no se puede confirmar la entrega push');
    }
    return;
  }

  const tokens = await dispositivoRepositorio.listarTokensDeUsuario(usuarioId);

  if (tokens.length === 0) {
    return;
  }

  const respuesta = await getMessaging(app).sendEachForMulticast({
    tokens,
    notification: {
      title: push.titulo,
      body: push.mensaje
    },
    data: aDatosString({ tipo: push.tipo, ...push.datos }),
    android: {
      priority: 'high',
      notification: {
        channelId: 'ubbike_notificaciones',
        sound: 'default'
      }
    }
  });

  const tokensInvalidos: string[] = [];
  let hayFalloTemporal = false;

  respuesta.responses.forEach((resultado, indice) => {
    if (!resultado.success) {
      const codigo = resultado.error?.code;
      if (
        codigo === 'messaging/registration-token-not-registered' ||
        codigo === 'messaging/invalid-argument' ||
        codigo === 'messaging/invalid-registration-token'
      ) {
        tokensInvalidos.push(tokens[indice]);
      } else {
        hayFalloTemporal = true;
      }
    }
  });

  if (tokensInvalidos.length > 0) {
    await dispositivoRepositorio.eliminarTokens(tokensInvalidos);
  }
  if (hayFalloTemporal) throw new Error('FCM informó entregas fallidas; reintentar');
};
