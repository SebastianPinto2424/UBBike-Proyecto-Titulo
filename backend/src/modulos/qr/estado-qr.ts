export const EstadoQr = {
  ESCANEADO: 'ESCANEADO',
  CONFIRMADO: 'CONFIRMADO',
  DENEGADO: 'DENEGADO',
  LIBERADO: 'LIBERADO'
} as const;

export type EstadoQr = (typeof EstadoQr)[keyof typeof EstadoQr];
