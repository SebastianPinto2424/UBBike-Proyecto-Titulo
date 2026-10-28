export class ErrorHttp extends Error {
  public readonly statusCode: number;
  public readonly codigo?: string;

  constructor(statusCode: number, message: string, codigo?: string) {
    super(message);
    this.statusCode = statusCode;
    this.codigo = codigo;
  }
}
