import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';

export const carpetaRecursos = path.resolve(__dirname, '../../../publico');

const versionScript = createHash('sha256')
  .update(readFileSync(path.join(carpetaRecursos, 'formulario-enlace.js')))
  .digest('hex')
  .slice(0, 12);

export const scriptFormulario = `/enlaces/recursos/formulario-enlace.js?v=${versionScript}`;
