export const conTiempoLimite = async <T>(operacion: Promise<T>, ms = 3000): Promise<T> => {
  let timer: ReturnType<typeof setTimeout>;
  try {
    return await Promise.race([
      operacion,
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('Dependencia excedió el tiempo límite')), ms);
      })
    ]);
  } finally {
    clearTimeout(timer!);
  }
};
