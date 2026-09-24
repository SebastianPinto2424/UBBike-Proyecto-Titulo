import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/widgets/lista_con_filtros.dart';

import 'package:ubbike/features/admin/application/gestion_usuarios_vm.dart';
import 'package:ubbike/shared/modelos/rol_usuario.dart';
import 'package:ubbike/shared/modelos/usuario_app.dart';
import 'package:ubbike/shared/utils/identidad.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/features/auth/presentation/widgets/estilos_formulario_auth.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';

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
        context.mostrarError('No se pudo conectar con el backend');
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
              : 'Correo de verificacion reenviado',
        );
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError('No se pudo conectar con el backend');
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
      builder: (_) => const _SheetCrearUsuario(),
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
        context.mostrarError('No se pudo conectar con el backend');
      }
    }
  }

  Future<void> _eliminarUsuario(UsuarioApp usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.delete_forever_outlined,
          color: ColoresUbb.rojoInstitucional,
          size: 44,
        ),
        title: const Text('Eliminar cuenta'),
        content: Text(
          'Se desactivara la cuenta de ${usuario.nombre}, se cerraran sus sesiones y dejara de aparecer en la gestion diaria.',
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ColoresUbb.rojoInstitucional,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) {
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
        context.mostrarError('No se pudo conectar con el backend');
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
        _FiltrosUsuariosAdmin(
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
          detalle: 'Revisa la conexión con el backend.',
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
          child: _TarjetaUsuarioAdmin(
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
      builder: (_) => _SheetEditarCuenta(usuario: usuario),
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

class _SheetEditarCuenta extends StatefulWidget {
  const _SheetEditarCuenta({required this.usuario});

  final UsuarioApp usuario;

  @override
  State<_SheetEditarCuenta> createState() => _SheetEditarCuentaState();
}

class _SheetCrearUsuario extends StatefulWidget {
  const _SheetCrearUsuario();

  @override
  State<_SheetCrearUsuario> createState() => _SheetCrearUsuarioState();
}

class _SheetCrearUsuarioState extends State<_SheetCrearUsuario> {
  final formKeyCrearCuenta = GlobalKey<FormState>();
  final nombreController = TextEditingController();
  final correoController = TextEditingController();
  final rutController = TextEditingController();
  final nombreFocus = FocusNode();
  final correoFocus = FocusNode();
  final rutFocus = FocusNode();
  RolUsuario rol = RolUsuario.guardia;

  @override
  void initState() {
    super.initState();
    nombreFocus.addListener(_actualizarAyuda);
    correoFocus.addListener(_actualizarAyuda);
    rutFocus.addListener(_actualizarAyuda);
  }

  void _actualizarAyuda() {
    if (mounted) {
      setState(() {});
    }
  }

  String? _ayudaSiActivo(FocusNode focus, String texto) =>
      focus.hasFocus ? texto : null;

  @override
  void dispose() {
    nombreFocus.dispose();
    correoFocus.dispose();
    rutFocus.dispose();
    nombreController.dispose();
    correoController.dispose();
    rutController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (formKeyCrearCuenta.currentState?.validate() != true) {
      return;
    }

    Navigator.pop(
      context,
      (
        nombre: nombreController.text.trim(),
        correo: correoController.text.trim().toLowerCase(),
        rut: rutController.text.trim(),
        rol: rol,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: formKeyCrearCuenta,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Crear cuenta',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Para guardias puedes usar un correo externo. La cuenta queda activa; el usuario recibira un correo para verificarla y definir su contrasena.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColoresUbb.textoSecundario,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nombreController,
                focusNode: nombreFocus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: decoracionCampoAuth(
                  labelText: 'Nombre completo',
                  icono: Icons.person_outline,
                  helperText: _ayudaSiActivo(
                    nombreFocus,
                    'Dos nombres y dos apellidos (ej: Nombre Nombre Apellido Apellido)',
                  ),
                ),
                validator: _validarNombreCuentaAdmin,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: correoController,
                focusNode: correoFocus,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
                decoration: decoracionCampoAuth(
                  labelText: 'Correo',
                  icono: Icons.mail_outline,
                  helperText: _ayudaSiActivo(
                    correoFocus,
                    'Institucional, o externo si es guardia (ej: persona@gmail.com)',
                  ),
                ),
                validator: _validarCorreoCuentaAdmin,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: rutController,
                focusNode: rutFocus,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [RutInputFormatter()],
                textInputAction: TextInputAction.next,
                decoration: decoracionCampoAuth(
                  labelText: 'RUT',
                  icono: Icons.badge_outlined,
                  helperText: _ayudaSiActivo(
                    rutFocus,
                    'Con guion, formato xx.xxx.xxx-x',
                  ),
                ),
                validator: _validarRutCuentaAdmin,
              ),
              const SizedBox(height: 12),
              _DropdownAdmin<RolUsuario>(
                value: rol,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: RolUsuario.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.etiqueta),
                      ),
                    )
                    .toList(),
                onChanged: (valor) {
                  if (valor != null) {
                    setState(() => rol = valor);
                  }
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: ColoresUbb.azulApp,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _guardar,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Crear'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetEditarCuentaState extends State<_SheetEditarCuenta> {
  final formKeyEditarCuenta = GlobalKey<FormState>();
  late final TextEditingController nombreController;
  late final TextEditingController correoController;
  late final TextEditingController rutController;

  @override
  void initState() {
    super.initState();
    nombreController = TextEditingController(text: widget.usuario.nombre);
    correoController = TextEditingController(text: widget.usuario.correo);
    rutController = TextEditingController(text: widget.usuario.rut ?? '');
  }

  @override
  void dispose() {
    nombreController.dispose();
    correoController.dispose();
    rutController.dispose();
    super.dispose();
  }

  void _guardar() {
    if (formKeyEditarCuenta.currentState?.validate() != true) {
      return;
    }

    Navigator.pop(
      context,
      (
        nombre: nombreController.text.trim(),
        correo: correoController.text.trim(),
        rut: rutController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: formKeyEditarCuenta,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Editar datos de cuenta',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nombreController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: _validarNombreCuentaAdmin,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: correoController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration:
                    const InputDecoration(labelText: 'Correo institucional'),
                validator: _validarCorreoCuentaAdmin,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: rutController,
                autocorrect: false,
                inputFormatters: [RutInputFormatter()],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _guardar(),
                decoration: const InputDecoration(labelText: 'RUT'),
                validator: _validarRutCuentaAdmin,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: ColoresUbb.azulApp,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _guardar,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _validarNombreCuentaAdmin(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'El nombre es obligatorio.';
  }
  if (texto.length > 120) {
    return 'Maximo 120 caracteres.';
  }
  if (!nombreCompletoValido(texto)) {
    return 'Ingresa dos nombres y dos apellidos (Nombre Nombre Apellido Apellido).';
  }
  return null;
}

String? _validarCorreoCuentaAdmin(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa un correo.';
  }
  if (texto.length > 160) {
    return 'Maximo 160 caracteres.';
  }

  final correoValido = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  if (!correoValido.hasMatch(texto)) {
    return 'Ingresa un correo valido. Ej: usuario@ubiobio.cl';
  }
  return null;
}

String? _validarRutCuentaAdmin(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'El RUT es obligatorio.';
  }
  if (!texto.contains('-')) {
    return 'El RUT debe incluir el guion (xx.xxx.xxx-x).';
  }
  if (texto.length > 20) {
    return 'Maximo 20 caracteres.';
  }
  if (!rutValido(texto)) {
    return 'RUT inválido. Revisa el número y el dígito verificador.';
  }
  return null;
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
                  'Roles, accesos y verificacion de cuentas.',
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

class _FiltrosUsuariosAdmin extends StatelessWidget {
  const _FiltrosUsuariosAdmin({
    required this.busquedaController,
    required this.total,
    required this.cargando,
    required this.tieneFiltros,
    required this.rol,
    required this.estadoCuenta,
    required this.estadoCorreo,
    required this.activos,
    required this.onBuscar,
    required this.onRol,
    required this.onEstadoCuenta,
    required this.onEstadoCorreo,
    required this.onLimpiarBusqueda,
    required this.onLimpiar,
  });

  final TextEditingController busquedaController;
  final int total;
  final bool cargando;
  final bool tieneFiltros;
  final RolUsuario? rol;
  final FiltroEstadoCuenta estadoCuenta;
  final FiltroEstadoCorreo estadoCorreo;
  final List<FiltroActivo> activos;
  final ValueChanged<String> onBuscar;
  final ValueChanged<RolUsuario?> onRol;
  final ValueChanged<FiltroEstadoCuenta> onEstadoCuenta;
  final ValueChanged<FiltroEstadoCorreo> onEstadoCorreo;
  final VoidCallback onLimpiarBusqueda;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    final contador = cargando ? 'Buscando...' : '$total usuarios';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Buscar usuarios',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: ColoresUbb.azulNoche,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Text(
                  contador,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColoresUbb.textoSecundario,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: busquedaController,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onChanged: onBuscar,
              decoration: InputDecoration(
                labelText: 'Nombre, correo o RUT',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: busquedaController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: onLimpiarBusqueda,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            _PanelFiltrosUsuarios(
              titulo: 'Filtros',
              detalle: _resumenFiltros(),
              activos: activos,
              onLimpiar: tieneFiltros ? onLimpiar : null,
              children: [
                _EtiquetaFiltroUsuarios(
                  texto: 'Rol',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChipFiltroUsuarios<RolUsuario?>(
                        label: 'Todos',
                        value: null,
                        selectedValue: rol,
                        onTap: onRol,
                      ),
                      for (final item in RolUsuario.values)
                        _ChipFiltroUsuarios<RolUsuario?>(
                          label: item.etiqueta,
                          value: item,
                          selectedValue: rol,
                          onTap: onRol,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _EtiquetaFiltroUsuarios(
                  texto: 'Estado cuenta',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in FiltroEstadoCuenta.values)
                        _ChipFiltroUsuarios<FiltroEstadoCuenta>(
                          label: item.etiqueta,
                          value: item,
                          selectedValue: estadoCuenta,
                          onTap: onEstadoCuenta,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _EtiquetaFiltroUsuarios(
                  texto: 'Estado correo',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in FiltroEstadoCorreo.values)
                        _ChipFiltroUsuarios<FiltroEstadoCorreo>(
                          label: item.etiqueta,
                          value: item,
                          selectedValue: estadoCorreo,
                          onTap: onEstadoCorreo,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _resumenFiltros() {
    final rolTexto = rol?.etiqueta ?? 'Todos los roles';
    return '$rolTexto | ${estadoCuenta.etiqueta} | ${estadoCorreo.etiqueta}';
  }
}

class _PanelFiltrosUsuarios extends StatelessWidget {
  const _PanelFiltrosUsuarios({
    required this.titulo,
    required this.detalle,
    required this.children,
    this.onLimpiar,
    this.activos = const <FiltroActivo>[],
  });

  final String titulo;
  final String detalle;
  final List<Widget> children;
  final VoidCallback? onLimpiar;
  final List<FiltroActivo> activos;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresUbb.superficie,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColoresUbb.bordeFuerte),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.tune, color: ColoresUbb.azulApp),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ColoresUbb.azulNoche,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (activos.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: ColoresUbb.azulApp,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${activos.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              detalle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColoresUbb.textoSecundario,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            children: [
              const SizedBox(height: 4),
              ...children,
              if (onLimpiar != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onLimpiar,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Restablecer filtros'),
                  ),
                ),
              ],
            ],
          ),
          if (activos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filtro in activos)
                    InputChip(
                      label: Text(filtro.etiqueta),
                      onDeleted: filtro.onQuitar,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      deleteButtonTooltipMessage: 'Quitar filtro',
                      visualDensity: VisualDensity.compact,
                      backgroundColor:
                          ColoresUbb.azulApp.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: ColoresUbb.azulApp.withValues(alpha: 0.28),
                      ),
                      labelStyle:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: ColoresUbb.azulNoche,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EtiquetaFiltroUsuarios extends StatelessWidget {
  const _EtiquetaFiltroUsuarios({required this.texto, required this.child});

  final String texto;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          texto,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColoresUbb.textoSecundario,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ChipFiltroUsuarios<T> extends StatelessWidget {
  const _ChipFiltroUsuarios({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onTap,
  });

  final String label;
  final T value;
  final T selectedValue;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    final seleccionado = value == selectedValue;
    return ChoiceChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (_) => onTap(value),
      showCheckmark: false,
      selectedColor: ColoresUbb.azulApp,
      backgroundColor: ColoresUbb.superficieAzulSuave,
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: seleccionado ? Colors.white : ColoresUbb.azulApp,
            fontWeight: FontWeight.w800,
          ),
      side: BorderSide(
        color: seleccionado ? ColoresUbb.azulApp : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _DropdownAdmin<T> extends StatelessWidget {
  const _DropdownAdmin({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.decoration,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tieneSeleccion = items.any((item) => item.value == value);
        final decoracion = decoration
            .applyDefaults(Theme.of(context).inputDecorationTheme)
            .copyWith(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            );

        return InputDecorator(
          decoration: decoracion,
          isEmpty: !tieneSeleccion,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              isDense: true,
              menuWidth: constraints.maxWidth,
              menuMaxHeight: 300,
              borderRadius: BorderRadius.circular(16),
              dropdownColor: Colors.white,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ColoresUbb.azulNoche,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        );
      },
    );
  }
}

class _TarjetaUsuarioAdmin extends StatefulWidget {
  const _TarjetaUsuarioAdmin({
    super.key,
    required this.usuario,
    required this.onActualizar,
    required this.onReenviarCorreoCuenta,
    required this.onEditarCredenciales,
    required this.onEliminar,
  });

  final UsuarioApp usuario;
  final Future<void> Function(
    UsuarioApp usuario, {
    RolUsuario? rol,
    bool? cuentaActiva,
  }) onActualizar;
  final Future<void> Function(UsuarioApp usuario) onReenviarCorreoCuenta;
  final Future<void> Function(UsuarioApp usuario) onEditarCredenciales;
  final Future<void> Function(UsuarioApp usuario) onEliminar;

  @override
  State<_TarjetaUsuarioAdmin> createState() => _TarjetaUsuarioAdminState();
}

class _TarjetaUsuarioAdminState extends State<_TarjetaUsuarioAdmin> {
  bool abierto = false;

  @override
  Widget build(BuildContext context) {
    final usuario = widget.usuario;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => abierto = !abierto),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usuario.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: ColoresUbb.azulNoche,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          usuario.correo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: ColoresUbb.textoSecundario,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    abierto
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: ColoresUbb.textoSecundario,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _ChipRolUsuario(texto: usuario.rol.etiqueta),
                  _IndicadorEstadoUsuario(
                    texto: usuario.cuentaActiva ? 'Activo' : 'Acceso denegado',
                    color: usuario.cuentaActiva
                        ? ColoresUbb.exito
                        : ColoresUbb.rojoInstitucional,
                  ),
                  _IndicadorEstadoUsuario(
                    texto: usuario.debeCambiarContrasena
                        ? 'Acceso pendiente'
                        : usuario.correoVerificado
                            ? 'Correo verificado'
                            : 'Correo pendiente',
                    color: usuario.correoVerificado &&
                            !usuario.debeCambiarContrasena
                        ? ColoresUbb.exito
                        : ColoresUbb.amarilloInstitucional,
                  ),
                ],
              ),
              if (abierto)
                _PanelGestionUsuario(
                  usuario: usuario,
                  onActualizar: widget.onActualizar,
                  onReenviarCorreoCuenta: widget.onReenviarCorreoCuenta,
                  onEditarCredenciales: widget.onEditarCredenciales,
                  onEliminar: widget.onEliminar,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipRolUsuario extends StatelessWidget {
  const _ChipRolUsuario({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresUbb.superficieAzulSuave,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ColoresUbb.grisInstitucional),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          texto,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ColoresUbb.azulApp,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _IndicadorEstadoUsuario extends StatelessWidget {
  const _IndicadorEstadoUsuario({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox(width: 7, height: 7),
        ),
        const SizedBox(width: 5),
        Text(
          texto,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColoresUbb.textoSecundario,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _ControlAccesoUsuario extends StatelessWidget {
  const _ControlAccesoUsuario({
    required this.habilitado,
    required this.onChanged,
  });

  final bool habilitado;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final titulo = habilitado ? 'Acceso habilitado' : 'Acceso denegado';
    final detalle = habilitado
        ? 'Puede iniciar sesion y usar las funciones asignadas.'
        : 'No puede iniciar sesion hasta reactivar el acceso.';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ColoresUbb.azulNoche,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                detalle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColoresUbb.textoSecundario,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: habilitado,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: ColoresUbb.azulApp,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor:
              ColoresUbb.rojoInstitucional.withValues(alpha: 0.78),
        ),
      ],
    );
  }
}

class _PanelGestionUsuario extends StatelessWidget {
  const _PanelGestionUsuario({
    required this.usuario,
    required this.onActualizar,
    required this.onReenviarCorreoCuenta,
    required this.onEditarCredenciales,
    required this.onEliminar,
  });

  final UsuarioApp usuario;
  final Future<void> Function(
    UsuarioApp usuario, {
    RolUsuario? rol,
    bool? cuentaActiva,
  }) onActualizar;
  final Future<void> Function(UsuarioApp usuario) onReenviarCorreoCuenta;
  final Future<void> Function(UsuarioApp usuario) onEditarCredenciales;
  final Future<void> Function(UsuarioApp usuario) onEliminar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ColoresUbb.fondo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColoresUbb.borde),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DatoUsuarioFila(
                etiqueta: 'Nombre completo',
                valor: usuario.nombre,
              ),
              const Divider(height: 20),
              _DatoUsuarioFila(
                etiqueta: 'Correo institucional',
                valor: usuario.correo,
              ),
              const Divider(height: 20),
              _DatoUsuarioFila(
                etiqueta: 'RUT',
                valor: usuario.rut?.trim().isNotEmpty == true
                    ? usuario.rut!
                    : 'Sin RUT registrado',
              ),
              const Divider(height: 20),
              _DatoUsuarioFila(
                etiqueta: 'Estado de la cuenta',
                valor: usuario.debeCambiarContrasena
                    ? 'Acceso pendiente de activación'
                    : usuario.correoVerificado
                        ? 'Correo verificado'
                        : 'Correo pendiente de verificación',
              ),
              const Divider(height: 24),
              const _EtiquetaSeccion('Acceso'),
              const SizedBox(height: 8),
              _ControlAccesoUsuario(
                habilitado: usuario.cuentaActiva,
                onChanged: (habilitado) =>
                    onActualizar(usuario, cuentaActiva: habilitado),
              ),
              if (usuario.debeCambiarContrasena ||
                  !usuario.correoVerificado) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => onReenviarCorreoCuenta(usuario),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      usuario.debeCambiarContrasena
                          ? 'Reenviar correo de acceso'
                          : 'Reenviar verificacion',
                    ),
                  ),
                ),
              ],
              const Divider(height: 28),
              const _EtiquetaSeccion('Rol principal'),
              const SizedBox(height: 8),
              _DropdownAdmin<RolUsuario>(
                key: ValueKey('rol-${usuario.id}-${usuario.rol.name}'),
                value: usuario.rol,
                decoration: const InputDecoration(),
                items: RolUsuario.values
                    .map(
                      (rol) => DropdownMenuItem(
                        value: rol,
                        child: Text(rol.etiqueta),
                      ),
                    )
                    .toList(),
                onChanged: (rol) async {
                  if (rol == null || rol == usuario.rol) {
                    return;
                  }
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Confirmar cambio de rol'),
                      content: Text(
                        '¿Cambiar el rol de ${usuario.nombre} de '
                        '"${usuario.rol.etiqueta}" a "${rol.etiqueta}"?\n\n'
                        'Esto modifica sus permisos dentro de la app.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Cambiar rol'),
                        ),
                      ],
                    ),
                  );
                  if (confirmar == true) {
                    await onActualizar(usuario, rol: rol);
                  }
                },
              ),
              const Divider(height: 28),
              const _EtiquetaSeccion('Acciones de cuenta'),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final anchoBoton = constraints.maxWidth >= 330
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: anchoBoton,
                        child: ElevatedButton(
                          onPressed: () => onEditarCredenciales(usuario),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Editar datos'),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: anchoBoton,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColoresUbb.rojoInstitucional,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => onEliminar(usuario),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Eliminar cuenta'),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatoUsuarioFila extends StatelessWidget {
  const _DatoUsuarioFila({
    required this.etiqueta,
    required this.valor,
  });

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ColoresUbb.textoSecundario,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: ColoresUbb.azulNoche,
              ),
        ),
      ],
    );
  }
}

class _EtiquetaSeccion extends StatelessWidget {
  const _EtiquetaSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: ColoresUbb.textoSecundario,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
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
