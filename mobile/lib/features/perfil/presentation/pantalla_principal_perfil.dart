import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final rut = textoNoVacio(usuario?.rut, 'Sin RUT registrado');
    final tieneRut = usuario?.rut != null && usuario!.rut!.trim().isNotEmpty;
    final iniciales = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((p) => p.characters.first)
        .join()
        .toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EncabezadoPerfil(
                iniciales: iniciales,
                nombre: nombre,
                rol: widget.rol,
                cuentaActiva: usuario?.cuentaActiva ?? true,
                correoVerificado: usuario?.correoVerificado ?? true,
              ),
              const SizedBox(height: 20),
              const TituloApartado(titulo: 'Datos de la cuenta'),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    _FilaDatoPerfil(
                      icono: Icons.alternate_email,
                      etiqueta: 'Correo institucional',
                      valor: correo,
                      copiable: usuario != null,
                      mensajeCopiado: 'Correo copiado',
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _FilaDatoPerfil(
                      icono: Icons.badge_outlined,
                      etiqueta: 'RUT',
                      valor: rut,
                      copiable: tieneRut,
                      mensajeCopiado: 'RUT copiado',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const TituloApartado(titulo: 'Seguridad'),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: const _IconoPerfil(
                    icono: Icons.lock_outline,
                    color: ColoresUbb.azulApp,
                  ),
                  title: Text(
                    _enviando
                        ? 'Enviando enlace…'
                        : _espera > 0
                            ? 'Reenviar en ${_espera}s'
                            : 'Cambiar contraseña',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: ColoresUbb.azulNoche,
                        ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Recibirás un enlace seguro en tu correo institucional.',
                    ),
                  ),
                  trailing: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.chevron_right,
                          color: ColoresUbb.textoSecundario,
                        ),
                  onTap: usuario == null || _enviando || _espera > 0
                      ? null
                      : () => _cambiarContrasena(correo),
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColoresUbb.rojoInstitucional,
                  side: BorderSide(
                    color: ColoresUbb.rojoInstitucional.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => ref.read(sesionProvider.notifier).cerrar(),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EncabezadoPerfil extends StatelessWidget {
  const _EncabezadoPerfil({
    required this.iniciales,
    required this.nombre,
    required this.rol,
    required this.cuentaActiva,
    required this.correoVerificado,
  });

  final String iniciales;
  final String nombre;
  final RolUsuario rol;
  final bool cuentaActiva;
  final bool correoVerificado;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ColoresUbb.superficieAzulSuave,
              ColoresUbb.superficie,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: ColoresUbb.superficie,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ColoresUbb.azulApp.withValues(alpha: 0.22),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  iniciales,
                  textScaler: TextScaler.noScaling,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: ColoresUbb.azulApp,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: ColoresUbb.azulNoche,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChipEstado(
                          texto: rol.etiqueta,
                          color: ColoresUbb.azulApp,
                        ),
                        if (!cuentaActiva)
                          const ChipEstado(
                            texto: 'Cuenta suspendida',
                            color: ColoresUbb.rojoInstitucional,
                          ),
                        if (!correoVerificado)
                          const ChipEstado(
                            texto: 'Verificación pendiente',
                            color: ColoresUbb.amarilloInstitucional,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconoPerfil extends StatelessWidget {
  const _IconoPerfil({required this.icono, required this.color});

  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icono, color: color, size: 20),
    );
  }
}

class _FilaDatoPerfil extends StatelessWidget {
  const _FilaDatoPerfil({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.copiable,
    required this.mensajeCopiado,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final bool copiable;
  final String mensajeCopiado;

  Future<void> _copiar(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: valor));
    if (context.mounted) {
      context.mostrarExito(mensajeCopiado);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: copiable ? () => _copiar(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _IconoPerfil(icono: icono, color: ColoresUbb.azulApp),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiqueta,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColoresUbb.textoSecundario,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    valor,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: ColoresUbb.azulNoche,
                        ),
                  ),
                ],
              ),
            ),
            if (copiable) ...[
              const SizedBox(width: 10),
              Icon(
                Icons.copy_rounded,
                size: 18,
                color: ColoresUbb.textoSecundario.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
