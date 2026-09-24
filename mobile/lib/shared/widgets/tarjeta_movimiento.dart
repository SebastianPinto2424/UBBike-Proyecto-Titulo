import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/widgets/central_widgets.dart';
import 'package:ubbike/shared/utils/utiles_comun.dart';
import 'package:ubbike/shared/utils/etiquetas_movimiento.dart';

class TarjetaMovimientoCentral extends StatelessWidget {
  const TarjetaMovimientoCentral({
    super.key,
    required this.movimiento,
    this.mostrarIdentidad = true,
    this.mostrarGuardia = true,
  });

  final MovimientoApp movimiento;
  final bool mostrarIdentidad;
  final bool mostrarGuardia;

  @override
  Widget build(BuildContext context) {
    final esIngreso = movimiento.tipo == 'INGRESO';
    final confirmado = movimiento.estado == 'CONFIRMADO';
    final tipoTexto = esIngreso ? 'Ingreso' : 'Retiro';
    final motivo = movimiento.motivoDenegacion?.trim();
    final comentario = movimiento.comentarioGuardia?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  esIngreso ? Icons.login : Icons.logout,
                  color: confirmado
                      ? ColoresUbb.exito
                      : ColoresUbb.rojoInstitucional,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    mostrarIdentidad
                        ? '$tipoTexto | ${movimiento.usuarioNombre}'
                        : tipoTexto,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                ChipEstado(
                  texto: confirmado ? 'Confirmado' : 'Denegado',
                  color: confirmado
                      ? ColoresUbb.exito
                      : ColoresUbb.rojoInstitucional,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (mostrarIdentidad) ...[
              FilaDato(
                etiqueta: 'Correo',
                valor: movimiento.usuarioCorreo,
                anchoCompleto: true,
              ),
              FilaDato(
                etiqueta: 'RUT',
                valor: movimiento.usuarioRut ?? 'Sin RUT',
              ),
            ],
            FilaDato(
              etiqueta: 'Bicicleta',
              valor: movimiento.bicicletaDescripcion,
            ),
            if (movimiento.bicicletaMarca != null &&
                movimiento.bicicletaMarca!.trim().isNotEmpty)
              FilaDato(
                etiqueta: 'Marca',
                valor: movimiento.bicicletaMarca!,
              ),
            if (movimiento.bicicletaModelo != null &&
                movimiento.bicicletaModelo!.trim().isNotEmpty)
              FilaDato(
                etiqueta: 'Modelo',
                valor: movimiento.bicicletaModelo!,
              ),
            if (movimiento.bicicletaColor != null &&
                movimiento.bicicletaColor!.trim().isNotEmpty)
              FilaDato(
                etiqueta: 'Color',
                valor: movimiento.bicicletaColor!,
              ),
            if (movimiento.bicicletaAro != null &&
                movimiento.bicicletaAro!.trim().isNotEmpty)
              FilaDato(
                etiqueta: 'Aro',
                valor: movimiento.bicicletaAro!,
              ),
            if (movimiento.bicicletaNumeroSerie != null &&
                movimiento.bicicletaNumeroSerie!.trim().isNotEmpty)
              FilaDato(
                etiqueta: 'N° de serie',
                valor: movimiento.bicicletaNumeroSerie!,
              ),
            FilaDato(
              etiqueta: 'Bicicletero',
              valor: movimiento.bicicleteroNombre,
              anchoCompleto: true,
            ),
            if (mostrarGuardia)
              FilaDato(etiqueta: 'Guardia', valor: movimiento.guardiaNombre),
            FilaDato(
              etiqueta: 'Fecha',
              valor: formatearFecha(movimiento.creadoEn),
            ),
            FilaDato(
              etiqueta: 'Hora',
              valor: formatearHora(movimiento.creadoEn),
            ),
            FilaDato(
              etiqueta: 'Método',
              valor: etiquetaOrigenMovimientoFiltro(movimiento.origen),
            ),
            if (motivo != null && motivo.isNotEmpty)
              FilaDato(
                etiqueta: 'Motivo de rechazo',
                valor: motivo,
                anchoCompleto: true,
                valorColor: ColoresUbb.rojoInstitucional,
                valorPeso: FontWeight.w700,
              ),
            if (comentario != null && comentario.isNotEmpty)
              FilaDato(
                etiqueta: 'Comentario guardia',
                valor: comentario,
                anchoCompleto: true,
                valorColor: ColoresUbb.textoSecundario,
                valorPeso: FontWeight.w700,
              ),
          ],
        ),
      ),
    );
  }
}
