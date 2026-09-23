import 'package:ubbike/shared/modelos/punto_geografico.dart';

enum CapaMapa {
  estandar('Mapa'),
  satelital('Satélite');

  const CapaMapa(this.etiqueta);

  final String etiqueta;
}

class ConfiguracionMapa {
  static const _urlTiles = String.fromEnvironment('MAP_TILE_URL');
  static const _urlSatelital = String.fromEnvironment('MAP_SATELLITE_URL');

  static const _urlTilesPorDefecto =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const _urlSatelitalPorDefecto =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  static const atribucion = String.fromEnvironment('MAP_ATTRIBUTION',
      defaultValue: '© OpenStreetMap contributors');
  static const urlAtribucion = String.fromEnvironment('MAP_ATTRIBUTION_URL',
      defaultValue: 'https://www.openstreetmap.org/copyright');

  static const urlBusqueda = String.fromEnvironment('MAP_SEARCH_URL',
      defaultValue: 'https://nominatim.openstreetmap.org/search');

  static const agenteBusqueda = 'UBBike/1.0 (Universidad del Bio-Bio)';

  static const paisBusqueda =
      String.fromEnvironment('MAP_SEARCH_COUNTRY', defaultValue: '');

  static const atribucionSatelital = 'Esri, Maxar, Earthstar Geographics';
  static const urlAtribucionSatelital =
      'https://www.esri.com/en-us/legal/terms/full-master-agreement';

  static String urlDeCapa(CapaMapa capa) => switch (capa) {
        CapaMapa.estandar =>
          _urlTiles.isEmpty ? _urlTilesPorDefecto : _urlTiles,
        CapaMapa.satelital =>
          _urlSatelital.isEmpty ? _urlSatelitalPorDefecto : _urlSatelital,
      };

  static String atribucionDeCapa(CapaMapa capa) => switch (capa) {
        CapaMapa.estandar => atribucion,
        CapaMapa.satelital => atribucionSatelital,
      };

  static String urlAtribucionDeCapa(CapaMapa capa) => switch (capa) {
        CapaMapa.estandar => urlAtribucion,
        CapaMapa.satelital => urlAtribucionSatelital,
      };

  static String get urlTiles => urlDeCapa(CapaMapa.estandar);

  static PuntoGeografico get centroCampus =>
      PuntoGeografico.desdeTexto(
        const String.fromEnvironment('MAP_CAMPUS_LAT',
            defaultValue: '-36.821728'),
        const String.fromEnvironment('MAP_CAMPUS_LNG',
            defaultValue: '-73.011604'),
      ) ??
      const PuntoGeografico(-36.821728, -73.011604);
}
