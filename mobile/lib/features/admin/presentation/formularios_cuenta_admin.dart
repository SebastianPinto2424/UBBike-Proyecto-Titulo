import 'package:flutter/material.dart';

import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/utilidades/identidad.dart';
import 'package:ubbike/shared/widgets/botones_accion.dart';
import 'package:ubbike/shared/widgets/estilos_formulario_autenticacion.dart';

class HojaEditarCuenta extends StatefulWidget {
  const HojaEditarCuenta({super.key, required this.usuario});

  final UsuarioApp usuario;

  @override
  State<HojaEditarCuenta> createState() => _HojaEditarCuentaState();
}

class HojaCrearUsuario extends StatefulWidget {
  const HojaCrearUsuario({super.key});

  @override
  State<HojaCrearUsuario> createState() => _HojaCrearUsuarioState();
}

class _HojaCrearUsuarioState extends State<HojaCrearUsuario> {
  final claveFormularioCrearCuenta = GlobalKey<FormState>();
  final controladorNombre = TextEditingController();
  final controladorCorreo = TextEditingController();
  final controladorRut = TextEditingController();
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
    controladorNombre.dispose();
    controladorCorreo.dispose();
    controladorRut.dispose();
    super.dispose();
  }

  void _guardar() {
    if (claveFormularioCrearCuenta.currentState?.validate() != true) {
      return;
    }

    Navigator.pop(
      context,
      (
        nombre: controladorNombre.text.trim(),
        correo: controladorCorreo.text.trim().toLowerCase(),
        rut: controladorRut.text.trim(),
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
          key: claveFormularioCrearCuenta,
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
                'La persona recibirá un correo para activar su cuenta y crear su contraseña.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColoresUbb.textoSecundario,
                    ),
              ),
              const SizedBox(height: 16),
              DropdownAdmin<RolUsuario>(
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
              const SizedBox(height: 18),
              TextFormField(
                controller: controladorNombre,
                focusNode: nombreFocus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: decoracionCampoAutenticacion(
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
                controller: controladorCorreo,
                focusNode: correoFocus,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
                decoration: decoracionCampoAutenticacion(
                  labelText: 'Correo',
                  icono: Icons.mail_outline,
                  helperText: _ayudaSiActivo(correoFocus, _ayudaCorreo(rol)),
                ),
                validator: (valor) => _validarCorreoCuentaAdmin(valor, rol),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: controladorRut,
                focusNode: rutFocus,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [FormateadorRut()],
                textInputAction: TextInputAction.next,
                decoration: decoracionCampoAutenticacion(
                  labelText: 'RUT',
                  icono: Icons.badge_outlined,
                  helperText: _ayudaSiActivo(
                    rutFocus,
                    'Con guion, formato xx.xxx.xxx-x',
                  ),
                ),
                validator: _validarRutCuentaAdmin,
              ),
              const SizedBox(height: 20),
              BotonesAccion.confirmacion(
                textoConfirmar: 'Crear',
                iconoConfirmar: Icons.person_add_alt_1_outlined,
                onCancelar: () => Navigator.pop(context),
                onConfirmar: _guardar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HojaEditarCuentaState extends State<HojaEditarCuenta> {
  final claveFormularioEditarCuenta = GlobalKey<FormState>();
  late final TextEditingController controladorNombre;
  late final TextEditingController controladorCorreo;
  late final TextEditingController controladorRut;

  @override
  void initState() {
    super.initState();
    controladorNombre = TextEditingController(text: widget.usuario.nombre);
    controladorCorreo = TextEditingController(text: widget.usuario.correo);
    controladorRut = TextEditingController(text: widget.usuario.rut ?? '');
  }

  @override
  void dispose() {
    controladorNombre.dispose();
    controladorCorreo.dispose();
    controladorRut.dispose();
    super.dispose();
  }

  void _guardar() {
    if (claveFormularioEditarCuenta.currentState?.validate() != true) {
      return;
    }

    Navigator.pop(
      context,
      (
        nombre: controladorNombre.text.trim(),
        correo: controladorCorreo.text.trim(),
        rut: controladorRut.text.trim(),
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
          key: claveFormularioEditarCuenta,
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
                controller: controladorNombre,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: _validarNombreCuentaAdmin,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controladorCorreo,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Correo',
                  helperText: _ayudaCorreo(widget.usuario.rol),
                ),
                validator: (valor) => _validarCorreoCuentaAdmin(
                  valor,
                  widget.usuario.rol,
                  correoActual: widget.usuario.correo,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controladorRut,
                autocorrect: false,
                inputFormatters: [FormateadorRut()],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _guardar(),
                decoration: const InputDecoration(labelText: 'RUT'),
                validator: _validarRutCuentaAdmin,
              ),
              const SizedBox(height: 20),
              BotonesAccion.confirmacion(
                textoConfirmar: 'Guardar',
                iconoConfirmar: Icons.save_outlined,
                onCancelar: () => Navigator.pop(context),
                onConfirmar: _guardar,
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
    return 'Máximo 120 caracteres.';
  }
  if (!nombreCompletoValido(texto)) {
    return 'Ingresa dos nombres y dos apellidos (Nombre Nombre Apellido Apellido).';
  }
  return null;
}

String _ayudaCorreo(RolUsuario rol) {
  final dominio = rol.dominioCorreo;
  return dominio == null
      ? 'Puede ser institucional o externo (ej: persona@gmail.com)'
      : 'Debe terminar en $dominio';
}

String _quienPorRol(RolUsuario rol) {
  switch (rol) {
    case RolUsuario.estudiante:
      return 'Un estudiante';
    case RolUsuario.funcionario:
      return 'Un funcionario';
    case RolUsuario.guardia:
      return 'Un guardia';
    case RolUsuario.adminCentral:
      return 'Un administrador central';
    case RolUsuario.administrador:
      return 'Un administrador';
  }
}

String? _validarCorreoCuentaAdmin(
  String? valor,
  RolUsuario rol, {
  String? correoActual,
}) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa un correo.';
  }
  if (texto.length > 160) {
    return 'Máximo 160 caracteres.';
  }

  final correoValido = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  if (!correoValido.hasMatch(texto)) {
    return 'Ingresa un correo válido. Ej: usuario@ubiobio.cl';
  }

  final sinCambios = texto.toLowerCase() == correoActual?.trim().toLowerCase();
  final dominio = rol.dominioCorreo;
  if (!sinCambios &&
      dominio != null &&
      !texto.toLowerCase().endsWith(dominio)) {
    return '${_quienPorRol(rol)} debe usar un correo $dominio';
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
    return 'Máximo 20 caracteres.';
  }
  if (!rutValido(texto)) {
    return 'RUT inválido. Revisa el número y el dígito verificador.';
  }
  return null;
}

class DropdownAdmin<T> extends StatelessWidget {
  const DropdownAdmin({
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
