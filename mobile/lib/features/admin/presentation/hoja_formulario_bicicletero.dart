import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/admin/presentation/bicicletero_ubicacion_widgets.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/core/modelos/punto_geografico.dart';
import 'package:ubbike/shared/utilidades/opciones_bicicletero.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/estilos_formulario.dart';
import 'package:ubbike/shared/utilidades/revision_ortografica.dart';

typedef DatosFormularioBicicletero = ({
  String nombre,
  String ubicacion,
  int capacidad,
  double? latitud,
  double? longitud
});

class HojaFormularioBicicletero extends ConsumerStatefulWidget {
  const HojaFormularioBicicletero(
      {super.key, this.bicicletero, required this.alGuardar});

  final BicicleteroApp? bicicletero;
  final Future<void> Function(DatosFormularioBicicletero) alGuardar;

  @override
  ConsumerState<HojaFormularioBicicletero> createState() =>
      _HojaFormularioBicicleteroState();
}

class _HojaFormularioBicicleteroState
    extends ConsumerState<HojaFormularioBicicletero> {
  final _formulario = GlobalKey<FormState>();

  late final TextEditingController _nombre;
  late final TextEditingController _referencia;
  late final TextEditingController _capacidad;
  late final TextEditingController _latitud;
  late final TextEditingController _longitud;

  bool _guardando = false;
  String? _error;

  bool get _editando => widget.bicicletero != null;

  PuntoGeografico? get _punto =>
      PuntoGeografico.desdeTexto(_latitud.text, _longitud.text);

  @override
  void initState() {
    super.initState();
    final b = widget.bicicletero;
    _nombre = TextEditingController(text: b?.nombre ?? '');
    _referencia = TextEditingController(text: b?.ubicacion ?? '');
    _capacidad = TextEditingController(text: (b?.capacidad ?? 80).toString());
    _latitud =
        TextEditingController(text: b?.latitud?.toStringAsFixed(6) ?? '');
    _longitud =
        TextEditingController(text: b?.longitud?.toStringAsFixed(6) ?? '');
  }

  @override
  void dispose() {
    for (final control in [
      _nombre,
      _referencia,
      _capacidad,
      _latitud,
      _longitud
    ]) {
      control.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    FocusScope.of(context).unfocus();

    final camposValidos = _formulario.currentState?.validate() == true;
    final errorCoordenadas = validarLatitudBicicletero(_latitud.text) ??
        validarLongitudBicicletero(_longitud.text) ??
        (_latitud.text.trim().isEmpty != _longitud.text.trim().isEmpty
            ? 'Indica latitud y longitud juntas, o ninguna.'
            : null);

    if (errorCoordenadas != null) {
      setState(() => _error = errorCoordenadas);
      context.mostrarError(errorCoordenadas);
      return;
    }
    if (!camposValidos) return;

    final punto = _punto;
    final datos = (
      nombre: _nombre.text.trim(),
      ubicacion: _referencia.text.trim(),
      capacidad: int.parse(_capacidad.text.trim()),
      latitud: punto?.latitud,
      longitud: punto?.longitud
    );

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.alGuardar(datos);
      if (mounted) Navigator.pop(context, true);
    } on ExcepcionApi catch (error) {
      if (mounted) {
        setState(() {
          _error = error.mensaje;
          _guardando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'No se pudo guardar. Tus datos siguen aquí; revisa la conexión e inténtalo otra vez.';
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
        child: AbsorbPointer(
          absorbing: _guardando,
          child: Form(
            key: _formulario,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      _editando
                          ? 'Editar bicicletero'
                          : 'Registrar bicicletero',
                      style: tema.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('bicicletero-nombre'),
                    controller: _nombre,
                    spellCheckConfiguration: revisionOrtografica(),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: decoracionCampoFormularioBicicleta(
                        labelText: 'Nombre',
                        helperText:
                            'Nombre breve para reconocer el bicicletero.'),
                    validator: validarNombreBicicletero,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('bicicletero-referencia'),
                    controller: _referencia,
                    spellCheckConfiguration: revisionOrtografica(),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: decoracionCampoFormularioBicicleta(
                        labelText: 'Referencia para llegar',
                        helperText: 'Ej.: Junto al acceso principal de FACE.'),
                    validator: validarUbicacionBicicletero,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('bicicletero-capacidad'),
                    controller: _capacidad,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: decoracionCampoFormularioBicicleta(
                        labelText: 'Capacidad',
                        helperText: 'Cantidad de bicicletas que caben.'),
                    validator: validarCapacidadBicicletero,
                  ),
                  const SizedBox(height: 20),
                  PanelUbicacionBicicletero(
                    latitud: _latitud,
                    longitud: _longitud,
                    habilitado: !_guardando,
                    alCambiar: () {
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Semantics(
                          liveRegion: true,
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: ColoresUbb.rojoInstitucional))),
                    ),
                  ElevatedButton.icon(
                    key: const Key('guardar-bicicletero'),
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(_guardando ? 'Guardando' : 'Guardar'),
                  ),
                ]),
          ),
        ),
      ),
    );
  }
}
