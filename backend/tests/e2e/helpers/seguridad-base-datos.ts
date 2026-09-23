export const validarBasePruebas = (url: string | undefined, permitirReset: string | undefined) => {
  if (!url || permitirReset !== '1')
    throw new Error('Se requieren TEST_DATABASE_URL y ALLOW_TEST_DATABASE_RESET=1');
  const destino = new URL(url);
  if (
    !['postgres:', 'postgresql:'].includes(destino.protocol) ||
    !['127.0.0.1', 'localhost', '[::1]', 'postgres'].includes(destino.hostname) ||
    !/^\/ubbike_e2e(?:_[a-z0-9]+)?$/.test(destino.pathname)
  ) {
    throw new Error(
      'Las pruebas destructivas solo admiten una base aislada ubbike_e2e en loopback o el servicio CI postgres'
    );
  }
  return destino;
};
