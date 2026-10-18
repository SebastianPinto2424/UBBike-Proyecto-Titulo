import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/servicios/ubicacion_servicio.dart';

final ubicacionServicioProvider = Provider((ref) => const UbicacionServicio());

final fabricaTilesMapaProvider =
    Provider<TileProvider Function()>((ref) => () => NetworkTileProvider(
          attemptDecodeOfHttpErrorResponses: false,
          cachingProvider: kIsWeb
              ? null
              : BuiltInMapCachingProvider.getOrCreateInstance(
                  maxCacheSize: 50 * 1024 * 1024,
                ),
        ));
