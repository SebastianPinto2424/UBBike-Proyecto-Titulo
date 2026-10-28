import fs from 'node:fs';
import path from 'node:path';

const raiz = path.resolve(__dirname, '../../src');

const listarArchivos = (dir: string): string[] =>
  fs.readdirSync(dir, { withFileTypes: true }).flatMap((entrada) => {
    const ruta = path.join(dir, entrada.name);
    if (entrada.isDirectory()) {
      return entrada.name === 'generated' ? [] : listarArchivos(ruta);
    }
    return ruta.endsWith('.ts') ? [ruta] : [];
  });

const archivos = listarArchivos(raiz).map((ruta) => ({
  ruta,
  relativa: path.relative(raiz, ruta).split(path.sep).join('/'),
  contenido: fs.readFileSync(ruta, 'utf8')
}));

const infraestructuraConPrisma = new Set([
  'aplicacion.ts',
  'servidor.ts',
  'configuracion/prisma.ts',
  'configuracion/datos-iniciales.ts',
  'scripts/quitar-usuarios-demo.ts'
]);

const resolverImport = (desde: string, destino: string) => {
  const base = path.resolve(path.dirname(desde), destino);
  return [`${base}.ts`, path.join(base, 'index.ts')].find((candidato) => fs.existsSync(candidato));
};

const importsEnEjecucion = (archivo: (typeof archivos)[number]) =>
  [...archivo.contenido.matchAll(/^import\s+(?!type\s)[^'"]*from\s+'(\.[^']+)'/gm)]
    .map((coincidencia) => resolverImport(archivo.ruta, coincidencia[1]))
    .filter((ruta): ruta is string => Boolean(ruta));

const buscarCiclo = (grafo: Map<string, string[]>) => {
  const estado = new Map<string, 'visitando' | 'listo'>();
  const pila: string[] = [];

  const visitar = (nodo: string): string[] | null => {
    estado.set(nodo, 'visitando');
    pila.push(nodo);
    for (const vecino of grafo.get(nodo) ?? []) {
      if (estado.get(vecino) === 'visitando') {
        return [...pila.slice(pila.indexOf(vecino)), vecino];
      }
      if (!estado.has(vecino)) {
        const ciclo = visitar(vecino);
        if (ciclo) return ciclo;
      }
    }
    pila.pop();
    estado.set(nodo, 'listo');
    return null;
  };

  for (const nodo of grafo.keys()) {
    if (!estado.has(nodo)) {
      const ciclo = visitar(nodo);
      if (ciclo) return ciclo;
    }
  }
  return null;
};

describe('arquitectura del backend', () => {
  it('solo los repositorios y la infraestructura usan Prisma', () => {
    const violaciones = archivos
      .filter((archivo) => /\bprisma\./.test(archivo.contenido))
      .filter(
        (archivo) =>
          !archivo.relativa.endsWith('.repositorio.ts') &&
          !infraestructuraConPrisma.has(archivo.relativa)
      )
      .map((archivo) => archivo.relativa);

    expect(violaciones).toEqual([]);
  });

  it('fuera de los repositorios nadie consulta tablas con el cliente de una transacción', () => {
    const consultaDirecta =
      /\b(?:db|client|tx)\.[a-z]\w*\.(?:find\w*|count|update\w*|create\w*|delete\w*|upsert|aggregate|groupBy)\(/;
    const violaciones = archivos
      .filter((archivo) => consultaDirecta.test(archivo.contenido))
      .filter(
        (archivo) =>
          !archivo.relativa.endsWith('.repositorio.ts') &&
          !infraestructuraConPrisma.has(archivo.relativa)
      )
      .map((archivo) => archivo.relativa);

    expect(violaciones).toEqual([]);
  });

  it('los controladores no acceden a repositorios ni a Prisma', () => {
    const violaciones = archivos
      .filter((archivo) => archivo.relativa.endsWith('.controlador.ts'))
      .filter((archivo) => /repositorio'|configuracion\/prisma'/.test(archivo.contenido))
      .map((archivo) => archivo.relativa);

    expect(violaciones).toEqual([]);
  });

  it('no hay dependencias circulares entre archivos', () => {
    const grafo = new Map(
      archivos.map((archivo) => [archivo.ruta, importsEnEjecucion(archivo)] as const)
    );
    const ciclo = buscarCiclo(grafo);

    expect(ciclo?.map((ruta) => path.relative(raiz, ruta))).toBeUndefined();
  });

  it('ningún archivo supera las 500 líneas', () => {
    const extensos = archivos
      .map((archivo) => ({ ...archivo, lineas: archivo.contenido.split('\n').length }))
      .filter((archivo) => archivo.lineas > 500)
      .map((archivo) => `${archivo.relativa} (${archivo.lineas})`);

    expect(extensos).toEqual([]);
  });

  it('las reglas y los mapeadores no dependen de servicios ni repositorios', () => {
    const violaciones = archivos
      .filter((archivo) => /\.(reglas|mapeador)\.ts$/.test(archivo.relativa))
      .flatMap((archivo) =>
        importsEnEjecucion(archivo)
          .filter((destino) => /\.(servicio|repositorio)\.ts$/.test(destino))
          .map((destino) => `${archivo.relativa} -> ${path.relative(raiz, destino)}`)
      );

    expect(violaciones).toEqual([]);
  });

  it('cada módulo con controlador expone sus rutas', () => {
    const modulosSinRutas = archivos
      .filter((archivo) => archivo.relativa.endsWith('.controlador.ts'))
      .map((archivo) => path.dirname(archivo.ruta))
      .filter((carpeta) => !fs.readdirSync(carpeta).some((nombre) => nombre.endsWith('.rutas.ts')))
      .map((carpeta) => path.relative(raiz, carpeta));

    expect(modulosSinRutas).toEqual([]);
  });
});
