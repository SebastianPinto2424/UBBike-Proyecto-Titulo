ALTER TABLE "solicitudes_guardia" RENAME COLUMN "nota_cierre_central" TO "motivo_cierre";

ALTER TABLE "solicitudes_guardia" ADD COLUMN "cerrada_por_usuario_id" UUID;

ALTER TABLE "solicitudes_guardia" ADD CONSTRAINT "solicitudes_guardia_cerrada_por_usuario_id_fkey" FOREIGN KEY ("cerrada_por_usuario_id") REFERENCES "usuarios"("id") ON DELETE SET NULL ON UPDATE CASCADE;
