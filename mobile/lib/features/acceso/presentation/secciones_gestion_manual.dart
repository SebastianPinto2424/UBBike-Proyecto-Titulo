import 'package:flutter/material.dart';
import 'package:ubbike/features/acceso/presentation/botones_decision_movimiento.dart';
import 'package:ubbike/features/acceso/presentation/campos_gestion_manual.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/acceso/presentation/gestion_manual_widgets.dart';
import 'package:ubbike/features/acceso/presentation/validaciones_gestion_manual.dart';
import 'package:ubbike/shared/utils/identidad.dart';

class SeccionUsuarioManual extends StatelessWidget {
  const SeccionUsuarioManual({
    super.key,
    required this.campos,
    required this.usuarioEncontrado,
    required this.requiereDatosNuevos,
    required this.buscando,
    required this.errorBusqueda,
    required this.onNombreEditado,
  });

  final CamposGestionManual campos;
  final bool usuarioEncontrado;
  final bool requiereDatosNuevos;
  final bool buscando;
  final String? errorBusqueda;
  final VoidCallback onNombreEditado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Datos de usuario',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: ColoresUbb.azulNoche,
              ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: campos.correo,
          focusNode: campos.focoCorreo,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          decoration: decoracionCampoGestionManual(
            labelText: 'Correo institucional',
            helperText: ayudaSiActivo(
              campos.focoCorreo,
              'Usa correo institucional cuando corresponda.',
            ),
          ),
          validator: (valor) => validarCorreoGestionManual(
            valor,
            campos.rut.text,
            requiereCorreo: requiereDatosNuevos,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: campos.rut,
          focusNode: campos.focoRut,
          autocorrect: false,
          inputFormatters: [RutInputFormatter()],
          decoration: decoracionCampoGestionManual(
            labelText: 'RUT',
            helperText: ayudaSiActivo(
              campos.focoRut,
              'Escribe el guion; los puntos se agregan solos.',
            ),
          ),
          validator: (valor) => validarRutGestionManual(
            valor,
            requerido: requiereDatosNuevos,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: campos.nombre,
          focusNode: campos.focoNombre,
          readOnly: usuarioEncontrado,
          textCapitalization: TextCapitalization.words,
          decoration: decoracionCampoGestionManual(
            labelText: 'Nombre',
            hintText:
                usuarioEncontrado ? null : 'Nombre y apellido de la persona',
            helperText: !usuarioEncontrado
                ? ayudaSiActivo(
                    campos.focoNombre,
                    'Nombre real para identificar a la persona.',
                  )
                : null,
          ),
          onChanged: (_) => onNombreEditado(),
          validator: (valor) => validarNombreGestionManual(
            valor,
            requerido: requiereDatosNuevos,
          ),
        ),
        EstadoBusquedaManual(
          buscando: buscando,
          error: errorBusqueda,
        ),
      ],
    );
  }
}

class AccionesGestionManual extends StatelessWidget {
  const AccionesGestionManual({
    super.key,
    required this.campos,
    required this.operacion,
    required this.retiroBloqueado,
    required this.registrando,
    required this.buscando,
    required this.onRegistrar,
    required this.onRechazar,
    required this.onCancelar,
  });

  final CamposGestionManual campos;
  final String operacion;
  final bool retiroBloqueado;
  final bool registrando;
  final bool buscando;
  final VoidCallback onRegistrar;
  final VoidCallback onRechazar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: campos.comentario,
          focusNode: campos.focoComentario,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Comentario opcional del guardia',
            hintText: 'Ej: Usuario posee U-Lock',
            alignLabelWithHint: true,
            helperText: ayudaSiActivo(
              campos.focoComentario,
              'Solo observaciones operativas si corresponde.',
            ),
          ),
          validator: (valor) => validarCampoOpcionalGestionManual(valor, 600),
        ),
        if (retiroBloqueado) ...[
          const SizedBox(height: 12),
          const CajaBusquedaManual(
            icono: Icons.lock_outline,
            color: ColoresUbb.rojoInstitucional,
            children: [
              Text(
                'Retiro bloqueado: el usuario debe completar su registro desde el correo de activación antes de retirar la bicicleta.',
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        BotonesDecisionMovimiento(
          esIngreso: operacion == 'INGRESO',
          procesando: registrando,
          habilitado: !buscando && !retiroBloqueado,
          onConfirmar: onRegistrar,
          onRechazar: onRechazar,
          textoSecundario: 'Cancelar acción',
          iconoSecundario: Icons.close,
          onSecundario: onCancelar,
        ),
      ],
    );
  }
}
