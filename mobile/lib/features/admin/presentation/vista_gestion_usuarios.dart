import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/admin/application/gestion_usuarios_vm.dart';
import 'package:ubbike/features/admin/presentation/filtros_usuarios_admin.dart';
import 'package:ubbike/features/admin/presentation/formularios_cuenta_admin.dart';
import 'package:ubbike/features/admin/presentation/tarjeta_usuario_admin.dart';
import 'package:ubbike/shared/widgets/dialogo_eliminar.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';
import 'package:ubbike/shared/widgets/lista_con_filtros.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

class VistaGestionUsuarios extends ConsumerStatefulWidget {
  const VistaGestionUsuarios({super.key});

  @override
  ConsumerState<VistaGestionUsuarios> createState() =>
      _VistaGestionUsuariosState();
}

class _VistaGestionUsuariosState extends ConsumerState<VistaGestionUsuarios> {
  final busquedaController = TextEditingController();

  GestionUsuariosVm get vm => ref.read(gestionUsuariosVmProvider.notifier);

  @override
  void initState() {
    super.initState();
    busquedaController.addListener(_alCambiarTextoBusqueda);
  }

  @override
  void dispose() {
    busquedaController.removeListener(_alCambiarTextoBusqueda);
    busquedaController.dispose();
    super.dispose();
  }

  void _alCambiarTextoBusqueda() {
    if (mounted) {
      setState(() {});
    }
  }

  void _limpiarFiltros() {
    busquedaController.clear();
    vm.limpiarFiltros();
  }

  void _limpiarBusqueda() {
    busquedaController.clear();
    vm.limpiarBusqueda();
  }

  Future<void> _actualizar(
    UsuarioApp usuario, {
    String? nombre,
    String? correo,
    String? rut,
    RolUsuario? rol,
    bool? cuentaActiva,
  }) async {
    try {
      await vm.actualizarPermisos(
        usuario,
        nombre: nombre,
        correo: correo,
        rut: rut,
        rol: rol,
        cuentaActiva: cuentaActiva,
      );
      if (mounted) {
        context.mostrarExito('Permisos actualizados');
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError(mensajeSinConexion);
      }
    }
  }

  Future<void> _reenviarCorreoCuenta(UsuarioApp usuario) async {
    try {
      await vm.reenviarCorreoCuenta(usuario);
      if (mounted) {
        context.mostrarExito(
          usuario.debeCambiarContrasena
              ? 'Correo de acceso reenviado'
              : 'Correo de verificación reenviado',
        );
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError(mensajeSinConexion);
      }
    }
  }

  Future<void> _crearUsuario() async {
    final resultado = await showModalBottomSheet<
        ({
          String nombre,
          String correo,
          String rut,
          RolUsuario rol,
        })>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      showDragHandle: false,
      useSafeArea: true,
      builder: (_) => const HojaCrearUsuario(),
    );

    if (resultado == null) {
      return;
    }

    try {
      await vm.crearUsuario(
        nombre: resultado.nombre,
        correo: resultado.correo,
        rut: resultado.rut,
        rol: resultado.rol,
      );
      if (mounted) {
        context.mostrarExito('Cuenta creada. Se envio el correo de acceso.');
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError(mensajeSinConexion);
      }
    }
  }

  Future<void> _eliminarUsuario(UsuarioApp usuario) async {
    final confirmar = await confirmarEliminacion(
      context,
      titulo: 'Eliminar cuenta',
      nombre: usuario.nombre,
      consecuencia: 'Se desactivará la cuenta, se cerrarán sus sesiones y '
          'dejará de aparecer en la gestión diaria.',
    );

    if (!confirmar || !mounted) {
      return;
    }

    try {
      await vm.eliminarUsuario(usuario);
      if (mounted) {
        context.mostrarExito('Cuenta eliminada');
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError(mensajeSinConexion);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(gestionUsuariosVmProvider);
    final filtros = ref.watch(filtrosGestionUsuariosProvider);
    final cargando = estado.isLoading;
    final usuarios = estado.valueOrNull ?? const <UsuarioApp>[];
    final tieneError = estado.hasError && estado.valueOrNull == null;
    final tieneFiltros = filtros.tieneFiltros;

    return ListaConFiltros(
      onRefrescar: () async => vm.recargar(),
      cabecera: [
        _EncabezadoAdminUsuarios(onCrear: _crearUsuario),
        const SizedBox(height: 12),
        FiltrosUsuariosAdmin(
          busquedaController: busquedaController,
          total: usuarios.length,
          cargando: cargando,
          tieneFiltros: tieneFiltros,
          rol: filtros.rol,
          estadoCuenta: filtros.estadoCuenta,
          estadoCorreo: filtros.estadoCorreo,
          activos: _filtrosActivos(filtros),
          onBuscar: vm.buscar,
          onRol: (rol) => vm.actualizarFiltros(
            rol: rol,
            limpiarRol: rol == null,
          ),
          onEstadoCuenta: (estado) =>
              vm.actualizarFiltros(estadoCuenta: estado),
          onEstadoCorreo: (estado) =>
              vm.actualizarFiltros(estadoCorreo: estado),
          onLimpiarBusqueda: _limpiarBusqueda,
          onLimpiar: _limpiarFiltros,
        ),
      ],
      contenido: _contenidoUsuarios(
        cargando: cargando,
        tieneError: tieneError,
        tieneFiltros: tieneFiltros,
        usuarios: usuarios,
      ),
    );
  }

  List<FiltroActivo> _filtrosActivos(FiltrosGestionUsuarios filtros) {
    final busqueda = busquedaController.text.trim();
    return [
      if (filtros.rol != null)
        FiltroActivo(
          etiqueta: filtros.rol!.etiqueta,
          onQuitar: () => vm.actualizarFiltros(limpiarRol: true),
        ),
      if (filtros.estadoCuenta != FiltroEstadoCuenta.todos)
        FiltroActivo(
          etiqueta: filtros.estadoCuenta.etiqueta,
          onQuitar: () =>
              vm.actualizarFiltros(estadoCuenta: FiltroEstadoCuenta.todos),
        ),
      if (filtros.estadoCorreo != FiltroEstadoCorreo.todos)
        FiltroActivo(
          etiqueta: filtros.estadoCorreo.etiqueta,
          onQuitar: () =>
              vm.actualizarFiltros(estadoCorreo: FiltroEstadoCorreo.todos),
        ),
      if (busqueda.isNotEmpty)
        FiltroActivo(
          etiqueta: 'Busca: $busqueda',
          onQuitar: _limpiarBusqueda,
        ),
    ];
  }

  Widget _contenidoUsuarios({
    required bool cargando,
    required bool tieneError,
    required bool tieneFiltros,
    required List<UsuarioApp> usuarios,
  }) {
    if (cargando) {
      return const SliverCargando();
    }

    if (tieneError) {
      return const SliverEspacioRestante(
        child: _EstadoUsuarios(
          icono: Icons.cloud_off_outlined,
          titulo: 'No se pudieron cargar usuarios',
          detalle: 'Revisa tu conexión y toca para reintentar.',
        ),
      );
    }

    if (usuarios.isEmpty) {
      return SliverEspacioRestante(
        child: _EstadoUsuarios(
          icono: Icons.people_outline,
          titulo: tieneFiltros ? 'Sin resultados' : 'Sin usuarios',
          detalle: tieneFiltros
              ? 'Ajusta la búsqueda o los filtros.'
              : 'Los registros aparecerán aquí.',
        ),
      );
    }

    return SliverList.builder(
      itemCount: usuarios.length,
      itemBuilder: (context, index) {
        final usuario = usuarios[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TarjetaUsuarioAdmin(
            key: ValueKey('usuario-${usuario.id}'),
            usuario: usuario,
            onActualizar: _actualizar,
            onReenviarCorreoCuenta: _reenviarCorreoCuenta,
            onEditarCredenciales: _editarCredenciales,
            onEliminar: _eliminarUsuario,
          ),
        );
      },
    );
  }

  Future<void> _editarCredenciales(UsuarioApp usuario) async {
    final resultado = await showModalBottomSheet<
        ({String nombre, String correo, String rut})>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      showDragHandle: false,
      useSafeArea: true,
      builder: (_) => HojaEditarCuenta(usuario: usuario),
    );

    if (resultado != null) {
      await _actualizar(
        usuario,
        nombre: resultado.nombre,
        correo: resultado.correo,
        rut: resultado.rut,
      );
    }
  }
}

class _EncabezadoAdminUsuarios extends StatelessWidget {
  const _EncabezadoAdminUsuarios({required this.onCrear});

  final VoidCallback onCrear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usuarios y permisos',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: ColoresUbb.azulNoche,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Roles, accesos y verificación de cuentas.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColoresUbb.textoSecundario,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ColoresUbb.azulApp,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onCrear,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 19),
            label: const Text('Usuario'),
          ),
        ],
      ),
    );
  }
}

class _EstadoUsuarios extends StatelessWidget {
  const _EstadoUsuarios({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icono, color: ColoresUbb.azulApp, size: 44),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(detalle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
