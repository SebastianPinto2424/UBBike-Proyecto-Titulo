import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const raiz = fileURLToPath(new URL('..', import.meta.url));
const rutaEsquema = `${raiz}prisma/schema.prisma`;
const rutaDbml = `${raiz}../docs/modelo-relacional.dbml`;

const nombresRegla = {
  Cascade: 'Cascade',
  SetNull: 'Set Null',
  Restrict: 'Restrict',
  NoAction: 'No Action'
};

const reglasDesdeEsquema = (esquema) => {
  const reglas = new Map();
  for (const bloque of esquema.matchAll(/^model (\w+) \{([\s\S]*?)^\}/gm)) {
    const cuerpo = bloque[2];
    const tabla = cuerpo.match(/@@map\("([^"]+)"\)/)?.[1] ?? bloque[1];
    for (const relacion of cuerpo.matchAll(/fields: \[(\w+)\][^)]*onDelete: (\w+)/g)) {
      reglas.set(`${tabla}.${relacion[1]}`, nombresRegla[relacion[2]] ?? relacion[2]);
    }
  }
  return reglas;
};

const reglas = reglasDesdeEsquema(readFileSync(rutaEsquema, 'utf-8'));
const dbml = readFileSync(rutaDbml, 'utf-8');
const ajustado = dbml.replace(
  /^(Ref: (\w+\.\w+) > \w+\.\w+ \[delete: )([^\]]+)(\])/gm,
  (linea, inicio, campo, regla, fin) =>
    reglas.has(campo) ? `${inicio}${reglas.get(campo)}${fin}` : linea
);

if (ajustado !== dbml) {
  writeFileSync(rutaDbml, ajustado);
}
