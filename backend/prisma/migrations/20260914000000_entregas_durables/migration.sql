CREATE TABLE "entregas_pendientes" (
  "id" UUID NOT NULL,
  "tipo" VARCHAR(20) NOT NULL,
  "datos" JSONB NOT NULL,
  "intentos" INTEGER NOT NULL DEFAULT 0,
  "disponible_en" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "creada_en" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "entregada_en" TIMESTAMPTZ(6),
  "agotada" BOOLEAN NOT NULL DEFAULT false,
  CONSTRAINT "entregas_pendientes_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "entregas_pendientes_entregada_en_agotada_disponible_en_idx"
  ON "entregas_pendientes"("entregada_en", "agotada", "disponible_en");
