-- DropForeignKey
ALTER TABLE "incidencias" DROP CONSTRAINT "incidencias_reportada_por_usuario_id_fkey";

-- DropForeignKey
ALTER TABLE "movimientos" DROP CONSTRAINT "movimientos_bicicleta_id_fkey";

-- DropForeignKey
ALTER TABLE "movimientos" DROP CONSTRAINT "movimientos_usuario_id_fkey";

-- DropForeignKey
ALTER TABLE "solicitudes_guardia" DROP CONSTRAINT "solicitudes_guardia_solicitada_por_usuario_id_fkey";

-- DropIndex
DROP INDEX "idx_qr_token";

-- AddForeignKey
ALTER TABLE "solicitudes_guardia" ADD CONSTRAINT "solicitudes_guardia_solicitada_por_usuario_id_fkey" FOREIGN KEY ("solicitada_por_usuario_id") REFERENCES "usuarios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "movimientos" ADD CONSTRAINT "movimientos_bicicleta_id_fkey" FOREIGN KEY ("bicicleta_id") REFERENCES "bicicletas"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "movimientos" ADD CONSTRAINT "movimientos_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "incidencias" ADD CONSTRAINT "incidencias_reportada_por_usuario_id_fkey" FOREIGN KEY ("reportada_por_usuario_id") REFERENCES "usuarios"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


-- AddCheckConstraints
ALTER TABLE "bicicleteros" ADD CONSTRAINT "chk_bicicleteros_capacidad" CHECK ("capacidad" BETWEEN 1 AND 1000);
ALTER TABLE "bicicleteros" ADD CONSTRAINT "chk_bicicleteros_latitud" CHECK ("latitud" IS NULL OR "latitud" BETWEEN -90 AND 90);
ALTER TABLE "bicicleteros" ADD CONSTRAINT "chk_bicicleteros_longitud" CHECK ("longitud" IS NULL OR "longitud" BETWEEN -180 AND 180);
ALTER TABLE "bicicleteros" ADD CONSTRAINT "chk_bicicleteros_coordenadas_completas" CHECK (("latitud" IS NULL) = ("longitud" IS NULL));
ALTER TABLE "bicicletas" ADD CONSTRAINT "chk_bicicletas_foto_tamano" CHECK ("foto_tamano_bytes" IS NULL OR "foto_tamano_bytes" > 0);
ALTER TABLE "solicitudes_guardia" ADD CONSTRAINT "chk_solicitudes_notificaciones_guardia" CHECK ("notificaciones_guardia" >= 0);
ALTER TABLE "incidencias" ADD CONSTRAINT "chk_incidencias_recordatorios" CHECK ("recordatorios" >= 0);
ALTER TABLE "incidencias_fotos" ADD CONSTRAINT "chk_incidencias_fotos_tamano" CHECK ("tamano_bytes" > 0);
ALTER TABLE "entregas_pendientes" ADD CONSTRAINT "chk_entregas_pendientes_intentos" CHECK ("intentos" >= 0);
