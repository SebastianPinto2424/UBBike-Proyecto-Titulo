import 'package:flutter/material.dart';

import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/admin/presentation/formularios_cuenta_admin.dart';
import 'package:ubbike/shared/widgets/botones_accion.dart';
import 'package:ubbike/shared/widgets/dialogo_accion.dart';

class TarjetaUsuarioAdmin extends StatefulWidget {
  const TarjetaUsuarioAdmin({
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
  State<TarjetaUsuarioAdmin> createState() => _TarjetaUsuarioAdminState();
}

class _TarjetaUsuarioAdminState extends State<TarjetaUsuarioAdmin> {
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
        ? 'Puede iniciar sesión y usar las funciones asignadas.'
        : 'No puede iniciar sesión hasta reactivar el acceso.';

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
                          : 'Reenviar verificación',
                    ),
                  ),
                ),
              ],
              const Divider(height: 28),
              const _EtiquetaSeccion('Rol principal'),
              const SizedBox(height: 8),
              DropdownAdmin<RolUsuario>(
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
                    builder: (ctx) => DialogoAccion(
                      icono: Icons.manage_accounts_outlined,
                      titulo: 'Confirmar cambio de rol',
                      contenido: Text(
                        '¿Cambiar el rol de ${usuario.nombre} de '
                        '"${usuario.rol.etiqueta}" a "${rol.etiqueta}"?\n\n'
                        'Esto modifica sus permisos dentro de la app.',
                        textAlign: TextAlign.center,
                      ),
                      acciones: BotonesAccion.confirmacion(
                        textoConfirmar: 'Cambiar rol',
                        onCancelar: () => Navigator.pop(ctx, false),
                        onConfirmar: () => Navigator.pop(ctx, true),
                      ),
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
