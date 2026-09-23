import { createClient, RedisClientType } from 'redis';
import { entorno } from './entorno';

let cliente: RedisClientType | null = null;
let promesaConexion: Promise<RedisClientType> | null = null;

export const obtenerClienteRedis = async (): Promise<RedisClientType | null> => {
  if (!entorno.redis.url) {
    return null;
  }

  if (cliente?.isReady) {
    return cliente;
  }
  if (cliente?.isOpen) throw new Error('Redis reconectando');

  if (cliente && !cliente.isOpen) {
    cliente = null;
    promesaConexion = null;
  }

  if (!promesaConexion) {
    cliente = createClient({
      url: entorno.redis.url,
      disableOfflineQueue: true,
      socket: {
        connectTimeout: 3000,
        reconnectStrategy: (intentos) => (intentos < 3 ? 500 : false)
      }
    });

    cliente.on('error', (error) => {
      console.error('Redis no disponible para rate limiting', error);
    });

    promesaConexion = cliente
      .connect()
      .then(() => cliente as RedisClientType)
      .catch((error) => {
        cliente = null;
        promesaConexion = null;
        throw error;
      });
  }

  return promesaConexion;
};

export const cerrarRedis = async () => {
  if (cliente?.isOpen) cliente.destroy();
  cliente = null;
  promesaConexion = null;
};
