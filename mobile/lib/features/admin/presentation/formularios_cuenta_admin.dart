import 'package:flutter/material.dart';

import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/utils/identidad.dart';
import 'package:ubbike/shared/widgets/estilos_formulario_auth.dart';

class SheetEditarCuenta extends StatefulWidget {
  const SheetEditarCuenta({super.key, required this.usuario});

  final UsuarioApp usuario;

  @override
  State<SheetEditarCuenta> createState() => _SheetEditarCuentaState();
}

class SheetCrearUsuario extends StatefulWidget {
  const SheetCrearUsuario({super.key});

  @override
  State<SheetCrearUsuario> createState() => _SheetCrearUsuarioState();
}

class _SheetCrearUsuarioState extends State<SheetCrearUsuario> {
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
                'Para guardias puedes usar un correo externo. La cuenta queda activa; el usuario recibirá un correo para verificarla y definir su contraseña.',
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

class _SheetEditarCuentaState extends State<SheetEditarCuenta> {
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
    return 'Máximo 120 caracteres.';
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
    return 'Máximo 160 caracteres.';
  }

  final correoValido = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  if (!correoValido.hasMatch(texto)) {
    return 'Ingresa un correo válido. Ej: usuario@ubiobio.cl';
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
