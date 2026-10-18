abstract interface class RegistroDispositivoPush {
  Future<void> registrarDispositivo(String token);

  Future<void> eliminarDispositivo(String token);
}
