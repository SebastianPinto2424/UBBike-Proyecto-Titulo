import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ubbike/features/acceso/application/solicitudes_guardia_vm.dart';
import 'package:ubbike/features/auth/application/autenticacion_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/modelos/rol_usuario.dart';
import 'package:ubbike/shared/utils/sesion_ui_utils.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';

class VistaPerfil extends ConsumerStatefulWidget {
  const VistaPerfil({super.key, required this.rol});
  final RolUsuario rol;
  @override
  ConsumerState<VistaPerfil> createState() => _VistaPerfilState();
}

class _VistaPerfilState extends ConsumerState<VistaPerfil> {
  bool _enviando = false;
  int _espera = 0;
  Timer? _temporizador;

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  Future<void> _cambiarContrasena(String correo) async {
    if (_enviando || _espera > 0) return;
    setState(() => _enviando = true);
    try {
      final mensaje = await ref
          .read(autenticacionVmProvider)
          .solicitarCambioContrasena(correo);
      if (!mounted) return;
      context.mostrarExito(mensaje);
      setState(() => _espera = 60);
      _temporizador = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _espera--);
        if (_espera == 0) timer.cancel();
      });
    } on ExcepcionApi catch (error) {
      if (mounted) context.mostrarError(error.mensaje);
    } catch (_) {
      if (mounted) {
        context
            .mostrarError('No pudimos enviar el enlace. Intenta nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionProvider).valueOrNull;
    final usuario = sesion is SesionActiva ? sesion.usuario : null;
    final nombre = textoNoVacio(usuario?.nombre, widget.rol.etiqueta);
    final correo = textoNoVacio(usuario?.correo, '—');
    final iniciales = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((p) => p.characters.first)
        .join()
        .toUpperCase();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                  child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            ColoresUbb.azulApp.withValues(alpha: .10),
                        foregroundColor: ColoresUbb.azulApp,
                        child:
                            Text(iniciales, textScaler: TextScaler.noScaling),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(nombre,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: ColoresUbb.azulNoche)),
                            const SizedBox(height: 8),
                            ChipEstado(
                                texto: widget.rol.etiqueta,
                                color: ColoresUbb.azulApp),
                          ])),
                    ]),
              )),
              const SizedBox(height: 16),
              Text('Datos de la cuenta',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                  child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DatoPerfilFila(
                          etiqueta: 'Correo institucional', valor: correo),
                      const SizedBox(height: 8),
                      ChipEstado(
                          texto: usuario?.correoVerificado == true
                              ? 'Correo verificado'
                              : 'Verificación pendiente',
                          color: usuario?.correoVerificado == true
                              ? ColoresUbb.exito
                              : ColoresUbb.amarilloInstitucional),
                      const Divider(height: 28),
                      _DatoPerfilFila(
                          etiqueta: 'RUT',
                          valor:
                              textoNoVacio(usuario?.rut, 'Sin RUT registrado')),
                    ]),
              )),
              const SizedBox(height: 16),
              Text('Seguridad', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                  child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading:
                    const Icon(Icons.lock_outline, color: ColoresUbb.azulApp),
                title: Text(_enviando
                    ? 'Enviando enlace…'
                    : _espera > 0
                        ? 'Reenviar en ${_espera}s'
                        : 'Cambiar contraseña'),
                subtitle: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                        'Recibirás un enlace seguro en tu correo institucional.')),
                trailing: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right),
                onTap: usuario == null || _enviando || _espera > 0
                    ? null
                    : () => _cambiarContrasena(correo),
              )),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresUbb.rojoInstitucional,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => ref.read(sesionProvider.notifier).cerrar(),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatoPerfilFila extends StatelessWidget {
  const _DatoPerfilFila({required this.etiqueta, required this.valor});
  final String etiqueta;
  final String valor;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: ColoresUbb.textoSecundario)),
          const SizedBox(height: 4),
          SelectableText(valor,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600, color: ColoresUbb.azulNoche)),
        ],
      );
}

class SelectorBicicleteroGuardiaPerfil extends ConsumerStatefulWidget {
  const SelectorBicicleteroGuardiaPerfil({super.key, this.onCambiado});

  final VoidCallback? onCambiado;

  @override
  ConsumerState<SelectorBicicleteroGuardiaPerfil> createState() =>
      _SelectorBicicleteroGuardiaPerfilState();
}

class _SelectorBicicleteroGuardiaPerfilState
    extends ConsumerState<SelectorBicicleteroGuardiaPerfil> {
  SolicitudesGuardiaVm get vm => ref.read(solicitudesGuardiaVmProvider);
  List<BicicleteroApp> bicicleteros = [];
  BicicleteroApp? bicicleteroSeleccionado;
  bool cargando = true;
  bool guardando = false;
  bool liberando = false;
  bool abierto = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => cargando = true);

    try {
      final resultados = await Future.wait([
        vm.listarBicicleteros(),
        vm.obtenerBicicleteroGestionado(),
      ]);
      final lista = resultados[0] as List<BicicleteroApp>;
      final actual = resultados[1] as BicicleteroApp?;
      final seleccionado = actual == null
          ? null
          : lista.cast<BicicleteroApp?>().firstWhere(
                (item) => item?.id == actual.id,
                orElse: () => null,
              );

      if (!mounted) {
        return;
      }

      setState(() {
        bicicleteros = lista;
        bicicleteroSeleccionado = seleccionado;
        cargando = false;
      });
    } on ExcepcionApi catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => cargando = false);
      context.mostrarError(error.mensaje);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => cargando = false);
      context.mostrarError('No se pudo conectar con el backend');
    }
  }

  Future<void> _guardar() async {
    final seleccionado = bicicleteroSeleccionado;
    if (seleccionado == null || guardando) {
      return;
    }

    setState(() => guardando = true);

    try {
      final actualizado =
          await vm.seleccionarBicicleteroGestionado(seleccionado.id);

      if (!mounted) {
        return;
      }

      setState(() {
        bicicleteros = bicicleteros
            .map((item) => item.id == actualizado.id ? actualizado : item)
            .toList();
        bicicleteroSeleccionado = bicicleteros.firstWhere(
          (item) => item.id == actualizado.id,
        );
        guardando = false;
        abierto = false;
      });
      context.mostrarExito('Ahora gestionas ${actualizado.nombre}');
      widget.onCambiado?.call();
    } on ExcepcionApi catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => guardando = false);
      context.mostrarError(error.mensaje);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => guardando = false);
      context.mostrarError('No se pudo conectar con el backend');
    }
  }

  Future<void> _liberar() async {
    if (guardando || bicicleteroSeleccionado == null) {
      return;
    }

    setState(() {
      guardando = true;
      liberando = true;
    });

    try {
      await vm.liberarBicicleteroGestionado();

      if (!mounted) {
        return;
      }

      setState(() {
        bicicleteroSeleccionado = null;
        guardando = false;
        liberando = false;
        abierto = false;
      });
      context.mostrarExito('Ya no gestionas un bicicletero');
      widget.onCambiado?.call();
    } on ExcepcionApi catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        guardando = false;
        liberando = false;
      });
      context.mostrarError(error.mensaje);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        guardando = false;
        liberando = false;
      });
      context.mostrarError('No se pudo conectar con el backend');
    }
  }

  String _textoBicicleteroSeleccionado() {
    final seleccionado = bicicleteroSeleccionado;
    if (seleccionado == null) {
      return 'Selecciona un bicicletero';
    }

    final cupos = seleccionado.cuposDisponibles == 1
        ? '1 cupo libre'
        : '${seleccionado.cuposDisponibles} cupos libres';
    return '${seleccionado.nombre} · $cupos';
  }

  Widget _opcionNinguno() {
    final seleccionado = bicicleteroSeleccionado == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: guardando || seleccionado ? null : _liberar,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: seleccionado
                  ? ColoresUbb.azulApp.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: seleccionado ? ColoresUbb.azulApp : ColoresUbb.borde,
                width: seleccionado ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ninguno',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dejar de gestionar un bicicletero',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ColoresUbb.textoSecundario,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (liberando)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    seleccionado
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: seleccionado
                        ? ColoresUbb.azulApp
                        : ColoresUbb.textoSecundario,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _opcionBicicletero(BicicleteroApp bicicletero) {
    final seleccionado = bicicleteroSeleccionado?.id == bicicletero.id;
    final guardandoEste = guardando && seleccionado;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: guardando || seleccionado
              ? null
              : () {
                  setState(() => bicicleteroSeleccionado = bicicletero);
                  _guardar();
                },
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: seleccionado
                  ? ColoresUbb.azulApp.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: seleccionado ? ColoresUbb.azulApp : ColoresUbb.borde,
                width: seleccionado ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bicicletero.nombre,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${bicicletero.cuposDisponibles} cupos disponibles',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ColoresUbb.textoSecundario,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (guardandoEste)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    seleccionado
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: seleccionado
                        ? ColoresUbb.azulApp
                        : ColoresUbb.textoSecundario,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bicicleteros.isEmpty) {
      return const EstadoLista(
        icono: Icons.location_off_outlined,
        titulo: 'Sin bicicleteros activos',
        detalle: 'Central debe habilitar al menos un bicicletero.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => abierto = !abierto),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ColoresUbb.bordeFuerte),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: ColoresUbb.azulApp,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _textoBicicleteroSeleccionado(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: bicicleteroSeleccionado == null
                                        ? ColoresUbb.textoSecundario
                                        : ColoresUbb.textoPrincipal,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          Icon(
                            abierto
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: ColoresUbb.textoSecundario,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Text(
                  'Bicicletero a gestionar',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ColoresUbb.azulApp,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
          ],
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState:
              abierto ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ColoresUbb.fondo,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColoresUbb.borde),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _opcionNinguno(),
                    ...bicicleteros.map(_opcionBicicletero),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
