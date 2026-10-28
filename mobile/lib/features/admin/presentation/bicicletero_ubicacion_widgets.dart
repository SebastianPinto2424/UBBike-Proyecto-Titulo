import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:ubbike/core/configuracion/configuracion_mapa.dart';
import 'package:ubbike/core/providers/mapa_provider.dart';
import 'package:ubbike/features/admin/application/buscador_lugares_vm.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/lugar_encontrado.dart';
import 'package:ubbike/core/modelos/punto_geografico.dart';
import 'package:ubbike/shared/utilidades/opciones_bicicletero.dart';
import 'package:ubbike/shared/widgets/mapa_ubicacion.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/estilos_formulario.dart';

class PanelUbicacionBicicletero extends ConsumerStatefulWidget {
  const PanelUbicacionBicicletero({
    super.key,
    required this.latitud,
    required this.longitud,
    required this.habilitado,
    this.alCambiar,
  });

  final TextEditingController latitud;
  final TextEditingController longitud;
  final bool habilitado;
  final VoidCallback? alCambiar;

  @override
  ConsumerState<PanelUbicacionBicicletero> createState() =>
      _PanelUbicacionBicicleteroState();
}

class _PanelUbicacionBicicleteroState
    extends ConsumerState<PanelUbicacionBicicletero> {
  final _mapa = MapController();
  final _busqueda = TextEditingController();

  Timer? _esperaBusqueda;
  List<LugarEncontrado> _resultados = const [];
  CapaMapa _capa = CapaMapa.estandar;

  bool _abierto = false;
  bool _mapaExpandido = true;
  bool _coordenadasVisibles = false;
  bool _mapaPreparado = false;
  bool _mapaDisponible = false;
  bool _buscandoLugares = false;
  bool _buscandoGps = false;
  int _revision = 0;
  String? _aviso;

  PuntoGeografico? get _punto =>
      PuntoGeografico.desdeTexto(widget.latitud.text, widget.longitud.text);

  @override
  void initState() {
    super.initState();

    _abierto = _punto != null;
  }

  @override
  void dispose() {
    _esperaBusqueda?.cancel();
    _busqueda.dispose();
    _mapa.dispose();
    super.dispose();
  }

  void _despuesDelCuadro(VoidCallback accion) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) accion();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _fijarPunto(PuntoGeografico punto, {bool centrar = false}) {
    if (!punto.esValido) return;
    _revision++;
    widget.latitud.text = punto.latitud.toStringAsFixed(6);
    widget.longitud.text = punto.longitud.toStringAsFixed(6);
    if (centrar && _mapaPreparado) {
      _mapa.move(
          LatLng(punto.latitud.clamp(-85, 85).toDouble(), punto.longitud), 18);
    }
    widget.alCambiar?.call();
  }

  void _quitarPunto() {
    _revision++;
    widget.latitud.clear();
    widget.longitud.clear();
    setState(() {
      _aviso = null;
      _resultados = const [];
      _busqueda.clear();
    });
    widget.alCambiar?.call();
  }

  void _zoom(double cambio) {
    if (!_mapaPreparado) return;
    _mapa.move(_mapa.camera.center,
        (_mapa.camera.zoom + cambio).clamp(3, 19).toDouble());
  }

  void _programarBusqueda(String valor) {
    _esperaBusqueda?.cancel();
    if (valor.trim().length < 3) {
      setState(() => _resultados = const []);
      return;
    }
    _esperaBusqueda =
        Timer(const Duration(milliseconds: 600), () => _buscar(valor));
  }

  Future<void> _buscar(String valor) async {
    if (!mounted) return;
    setState(() => _buscandoLugares = true);
    try {
      final lugares = await ref.read(buscadorLugaresVmProvider).buscar(valor);
      if (mounted) setState(() => _resultados = lugares);
    } catch (_) {
      if (mounted) {
        setState(() => _resultados = const []);
        context.mostrarError(
            'No se pudo buscar la dirección. Usa el mapa o las coordenadas.');
      }
    } finally {
      if (mounted) setState(() => _buscandoLugares = false);
    }
  }

  void _usarLugar(LugarEncontrado lugar) {
    FocusScope.of(context).unfocus();
    _fijarPunto(lugar.punto, centrar: true);
    setState(() {
      _resultados = const [];
      _busqueda.text = lugar.titulo;
      _aviso = 'Ajusta el pin sobre el acceso si hace falta.';
      _mapaExpandido = true;
    });
  }

  Future<void> _usarMiUbicacion() async {
    if (_buscandoGps) return;
    FocusScope.of(context).unfocus();
    final revision = ++_revision;
    setState(() {
      _buscandoGps = true;
      _aviso = null;
    });

    try {
      final posicion = await ref
          .read(ubicacionServicioProvider)
          .obtenerPosicionActual(
              precision: LocationAccuracy.high,
              limite: const Duration(seconds: 20));
      if (!mounted || revision != _revision) return;

      if (posicion == null) {
        setState(() => _aviso =
            'No se obtuvo tu ubicación. Revisa que la localización esté activada y que la app tenga permiso de ubicación precisa, o marca el punto en el mapa.');
        return;
      }

      final punto = PuntoGeografico(posicion.latitude, posicion.longitude);
      if (!punto.esValido) {
        setState(() => _aviso =
            'El GPS no entregó una posición válida. Marca el punto en el mapa.');
        return;
      }

      _fijarPunto(punto, centrar: true);
      setState(() {
        _mapaExpandido = true;
        _aviso = posicion.accuracy.isFinite
            ? 'Precisión aproximada: ${posicion.accuracy.round()} m. Ajusta el pin sobre el acceso.'
            : 'Ajusta el pin sobre el acceso.';
      });
    } catch (_) {
      if (mounted && revision == _revision) {
        context.mostrarError(
            'No se pudo obtener el GPS. Marca el punto en el mapa.');
      }
    } finally {
      if (mounted) setState(() => _buscandoGps = false);
    }
  }

  Widget _cabecera(ThemeData tema) {
    final punto = _punto;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ubicación en el mapa',
              style: tema.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(
              punto == null
                  ? 'Opcional. Sin coordenadas no aparece en las sugerencias por cercanía.'
                  : punto.etiqueta,
              style: tema.textTheme.bodySmall),
        ]),
      ),
      if (punto != null)
        TextButton(
            key: const Key('quitar-ubicacion'),
            style: TextButton.styleFrom(
                foregroundColor: ColoresUbb.rojoInstitucional),
            onPressed: widget.habilitado ? _quitarPunto : null,
            child: const Text('Quitar')),
    ]);
  }

  Widget _minimapa() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: SegmentedButton<CapaMapa>(
            key: const Key('capa-mapa'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: CapaMapa.estandar,
                  label: Text(CapaMapa.estandar.etiqueta),
                  icon: const Icon(Icons.map_outlined, size: 18)),
              ButtonSegment(
                  value: CapaMapa.satelital,
                  label: Text(CapaMapa.satelital.etiqueta),
                  icon: const Icon(Icons.satellite_alt_outlined, size: 18)),
            ],
            selected: {_capa},
            onSelectionChanged: widget.habilitado
                ? (seleccion) => setState(() => _capa = seleccion.first)
                : null,
          ),
        ),
        IconButton(
          key: const Key('expandir-minimapa'),
          tooltip: _mapaExpandido ? 'Contraer mapa' : 'Expandir mapa',
          onPressed: () => setState(() => _mapaExpandido = !_mapaExpandido),
          icon: Icon(_mapaExpandido
              ? Icons.close_fullscreen
              : Icons.open_in_full_outlined),
        ),
      ]),
      if (_mapaExpandido) ...[
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: Stack(children: [
            MapaUbicacion(
              centroInicial: _punto ?? ConfiguracionMapa.centroCampus,
              controlador: _mapa,
              interactivo: widget.habilitado,
              capa: _capa,
              alMover: (nuevo) => _fijarPunto(nuevo),
              alPreparar: () => _despuesDelCuadro(() {
                if (!_mapaPreparado) setState(() => _mapaPreparado = true);
              }),
              alCambiarDisponibilidad: (valor) => _despuesDelCuadro(() {
                if (_mapaDisponible != valor) {
                  setState(() => _mapaDisponible = valor);
                }
              }),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Card(
                  child: Column(children: [
                IconButton(
                    tooltip: 'Acercar mapa',
                    onPressed: _mapaPreparado ? () => _zoom(1) : null,
                    icon: const Icon(Icons.add, color: ColoresUbb.azulApp)),
                IconButton(
                    tooltip: 'Alejar mapa',
                    onPressed: _mapaPreparado ? () => _zoom(-1) : null,
                    icon: const Icon(Icons.remove, color: ColoresUbb.azulApp)),
              ])),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(
            _punto == null
                ? 'Mueve el mapa bajo el pin o toca el lugar donde llegan los usuarios.'
                : 'Ubicación seleccionada · ${_punto!.etiqueta}',
            style: Theme.of(context).textTheme.bodySmall),
        if (!_mapaDisponible)
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  'Si el mapa no carga, puedes escribir las coordenadas.',
                  style: Theme.of(context).textTheme.bodySmall)),
      ],
    ]);
  }

  Widget _buscador() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        key: const Key('buscar-direccion'),
        controller: _busqueda,
        enabled: widget.habilitado,
        textInputAction: TextInputAction.search,
        onChanged: _programarBusqueda,
        onSubmitted: _buscar,
        decoration: decoracionCampoFormularioBicicleta(
          labelText: 'Buscar dirección o lugar',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _buscandoLugares
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : null,
        ),
      ),
      if (_resultados.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Card(
            margin: EdgeInsets.zero,
            child: Column(
                children: _resultados
                    .map((lugar) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined,
                              color: ColoresUbb.azulApp),
                          title: Text(lugar.titulo),
                          subtitle: lugar.detalle.isEmpty
                              ? null
                              : Text(lugar.detalle),
                          onTap: () => _usarLugar(lugar),
                        ))
                    .toList()),
          ),
        ),
    ]);
  }

  Widget _coordenadas() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextButton.icon(
        key: const Key('alternar-coordenadas'),
        onPressed: () =>
            setState(() => _coordenadasVisibles = !_coordenadasVisibles),
        icon:
            Icon(_coordenadasVisibles ? Icons.expand_less : Icons.expand_more),
        label: const Text('Ingresar coordenadas'),
      ),
      if (_coordenadasVisibles) ...[
        Text('Completa ambos valores o deja ambos vacíos.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              key: const Key('bicicletero-latitud'),
              controller: widget.latitud,
              enabled: widget.habilitado,
              keyboardType: const TextInputType.numberWithOptions(
                  signed: true, decimal: true),
              decoration:
                  decoracionCampoFormularioBicicleta(labelText: 'Latitud'),
              validator: validarLatitudBicicletero,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              key: const Key('bicicletero-longitud'),
              controller: widget.longitud,
              enabled: widget.habilitado,
              keyboardType: const TextInputType.numberWithOptions(
                  signed: true, decimal: true),
              decoration:
                  decoracionCampoFormularioBicicleta(labelText: 'Longitud'),
              validator: validarLongitudBicicletero,
            ),
          ),
        ]),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    if (!_abierto) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _cabecera(tema),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('agregar-ubicacion'),
          onPressed:
              widget.habilitado ? () => setState(() => _abierto = true) : null,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Agregar ubicación'),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _cabecera(tema),
      const SizedBox(height: 12),
      _buscador(),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        key: const Key('usar-mi-ubicacion'),
        onPressed: widget.habilitado && !_buscandoGps ? _usarMiUbicacion : null,
        icon: _buscandoGps
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location),
        label:
            Text(_buscandoGps ? 'Obteniendo ubicación…' : 'Usar mi ubicación'),
      ),
      if (_aviso != null)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
                liveRegion: true,
                child: Text(_aviso!, style: tema.textTheme.bodySmall))),
      const SizedBox(height: 12),
      _minimapa(),
      const SizedBox(height: 4),
      _coordenadas(),
    ]);
  }
}
