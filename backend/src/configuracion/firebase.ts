import { readFileSync } from 'node:fs';
import { App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { entorno } from './entorno';

let appFirebase: App | null = null;
let yaSeIntento = false;

const cargarCredencial = () => {
  const base64 = entorno.firebase.credencialesBase64;
  if (base64) {
    return JSON.parse(Buffer.from(base64, 'base64').toString('utf-8'));
  }
  const ruta = entorno.firebase.credencialesPath;
  if (ruta) {
    return JSON.parse(readFileSync(ruta, 'utf-8'));
  }
  return null;
};

export const obtenerFirebase = (): App | null => {
  if (appFirebase) {
    return appFirebase;
  }

  if (yaSeIntento) {
    return null;
  }

  yaSeIntento = true;

  try {
    const credencial = cargarCredencial();

    if (!credencial) {
      console.log(
        '[firebase] Sin FIREBASE_CREDENTIALS_BASE64 ni FIREBASE_CREDENTIALS_PATH: push deshabilitado'
      );
      return null;
    }

    appFirebase =
      getApps().length > 0 ? getApps()[0] : initializeApp({ credential: cert(credencial) });
    console.log('[firebase] Admin SDK inicializado: push habilitado');
    return appFirebase;
  } catch (error) {
    console.error('[firebase] No se pudo inicializar Admin SDK; push deshabilitado', error);
    return null;
  }
};

export const firebaseHabilitado = (): boolean => obtenerFirebase() !== null;
