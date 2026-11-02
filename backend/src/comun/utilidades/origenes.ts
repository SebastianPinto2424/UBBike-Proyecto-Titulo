import { entorno } from '../../configuracion/entorno';

const origenDe = (url: string): string | null => {
  try {
    return new URL(url).origin;
  } catch {
    return null;
  }
};

export const origenesNavegadorPermitidos = (): string[] => {
  const publico = origenDe(entorno.app.urlEnlaces);
  return [...new Set([...entorno.cors.origenes, ...(publico ? [publico] : [])])];
};

export const origenPermitido = (origen: string | undefined, host?: string): boolean => {
  if (!origen) {
    return true;
  }

  if (origenesNavegadorPermitidos().includes(origen)) {
    return true;
  }

  try {
    return host !== undefined && new URL(origen).host === host;
  } catch {
    return false;
  }
};
