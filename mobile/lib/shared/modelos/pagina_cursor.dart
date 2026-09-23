class PaginaCursor<T> {
  const PaginaCursor({required this.datos, this.cursor, this.noLeidas = 0});
  final List<T> datos;
  final String? cursor;
  final int noLeidas;
  bool get hayMas => cursor != null;
}
