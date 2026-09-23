import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ubbike/core/configuracion/configuracion_mapa.dart';
import 'package:ubbike/core/providers/mapa_provider.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/punto_geografico.dart';

class MapaUbicacion extends ConsumerStatefulWidget {
  const MapaUbicacion(
      {super.key,
      required this.centroInicial,
      this.controlador,
      this.interactivo = false,
      this.mostrarPin = true,
      this.capa = CapaMapa.estandar,
      this.alMover,
      this.alCambiarDisponibilidad,
      this.alPreparar});

  final PuntoGeografico centroInicial;
  final MapController? controlador;
  final bool interactivo;
  final bool mostrarPin;
  final CapaMapa capa;
  final ValueChanged<PuntoGeografico>? alMover;
  final ValueChanged<bool>? alCambiarDisponibilidad;
  final VoidCallback? alPreparar;

  @override
  ConsumerState<MapaUbicacion> createState() => _MapaUbicacionState();
}

class _MapaUbicacionState extends ConsumerState<MapaUbicacion> {
  late TileProvider _tiles;
  Timer? _limiteCarga;
  bool _cargado = false;
  bool _fallo = false;
  bool _actualizacionPendiente = false;
  bool? _resultadoPendiente;
  int _intento = 0;

  @override
  void initState() {
    super.initState();
    _tiles = ref.read(fabricaTilesMapaProvider)();
    _programarLimite();
  }

  void _programarLimite() {
    _limiteCarga?.cancel();
    _limiteCarga = Timer(const Duration(seconds: 12), () {
      if (mounted && !_cargado) _informarCarga(false);
    });
  }

  void _informarCarga(bool correcta) {
    if (!mounted ||
        (_fallo && correcta) ||
        (correcta && _cargado) ||
        (!correcta && _fallo)) {
      return;
    }
    if (_actualizacionPendiente) {
      if (!correcta) _resultadoPendiente = false;
      return;
    }
    _resultadoPendiente = correcta;
    _actualizacionPendiente = true;
    final intento = _intento;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _actualizacionPendiente = false;
      if (!mounted || intento != _intento) return;
      final disponible = _resultadoPendiente ?? correcta;
      _resultadoPendiente = null;
      _limiteCarga?.cancel();
      setState(() {
        _cargado = disponible;
        _fallo = !disponible;
      });
      widget.alCambiarDisponibilidad?.call(disponible);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void didUpdateWidget(covariant MapaUbicacion anterior) {
    super.didUpdateWidget(anterior);

    if (anterior.capa != widget.capa) {
      _reiniciarCarga();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.alCambiarDisponibilidad?.call(false);
      });
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  void _reiniciarCarga() {
    _intento++;
    _cargado = false;
    _fallo = false;
    _actualizacionPendiente = false;
    _resultadoPendiente = null;
    _tiles = ref.read(fabricaTilesMapaProvider)();
    _programarLimite();
  }

  void _reintentar() {
    setState(_reiniciarCarga);
    widget.alCambiarDisponibilidad?.call(false);
  }

  @override
  void dispose() {
    _limiteCarga?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
          child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(children: [
          FlutterMap(
            mapController: widget.controlador,
            options: MapOptions(
              initialCenter: LatLng(
                  widget.centroInicial.latitud.clamp(-85, 85).toDouble(),
                  widget.centroInicial.longitud),
              initialZoom: 17,
              minZoom: 3,
              maxZoom: 19,
              backgroundColor: ColoresUbb.superficieAzul,
              interactionOptions: InteractionOptions(
                  flags: widget.interactivo
                      ? InteractiveFlag.all & ~InteractiveFlag.rotate
                      : InteractiveFlag.none),
              onMapReady: widget.alPreparar,
              onTap: widget.interactivo
                  ? (_, punto) {
                      widget.controlador
                          ?.move(punto, widget.controlador!.camera.zoom);
                      widget.alMover?.call(PuntoGeografico(
                          punto.latitude, (punto.longitude + 180) % 360 - 180));
                    }
                  : null,
              onPositionChanged: (camara, gesto) {
                if (widget.interactivo && gesto) {
                  widget.alMover?.call(PuntoGeografico(camara.center.latitude,
                      (camara.center.longitude + 180) % 360 - 180));
                }
              },
            ),
            children: [
              TileLayer(
                key: ValueKey('${widget.capa.name}-$_intento'),
                urlTemplate: ConfiguracionMapa.urlDeCapa(widget.capa),
                userAgentPackageName: 'cl.ubiobio.ubbike',
                tileProvider: _tiles,
                panBuffer: 0,
                maxNativeZoom: 19,
                errorTileCallback: (_, __, ___) => _informarCarga(false),
                tileBuilder: (context, imagen, tile) => ListenableBuilder(
                  listenable: tile,
                  builder: (context, _) {
                    if (tile.loadFinishedAt != null && !tile.loadError) {
                      _informarCarga(true);
                    }
                    return imagen;
                  },
                ),
              )
            ],
          ),
          if (widget.mostrarPin)
            const Center(
                child: IgnorePointer(
              child: FractionalTranslation(
                  translation: Offset(0, -0.5),
                  child: Icon(Icons.location_on,
                      size: 44,
                      color: ColoresUbb.azulApp,
                      shadows: [
                        Shadow(color: ColoresUbb.superficie, blurRadius: 4)
                      ])),
            )),
          if (!_cargado && !_fallo)
            const Positioned(
                top: 10,
                left: 10,
                child: Card(
                    child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Cargando mapa…'),
                        ])))),
          if (_fallo)
            Positioned.fill(
                child: ColoredBox(
              color: ColoresUbb.superficieAzul,
              child: Center(
                  child: SingleChildScrollView(
                      child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.map_outlined,
                      color: ColoresUbb.textoSecundario),
                  const SizedBox(height: 6),
                  const Text('No se pudo cargar el mapa',
                      textAlign: TextAlign.center),
                  TextButton.icon(
                      onPressed: _reintentar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar')),
                ]),
              ))),
            )),
        ]),
      )),
      Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () async {
              final uri = Uri.tryParse(
                  ConfiguracionMapa.urlAtribucionDeCapa(widget.capa));
              if (uri == null || uri.scheme != 'https') return;
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(ConfiguracionMapa.atribucionDeCapa(widget.capa),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColoresUbb.textoSecundario,
                        decoration: TextDecoration.underline))),
          )),
    ]);
  }
}
