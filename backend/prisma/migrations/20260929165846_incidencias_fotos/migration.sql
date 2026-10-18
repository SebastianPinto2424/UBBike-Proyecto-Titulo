-- CreateTable
CREATE TABLE "incidencias_fotos" (
    "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
    "incidencia_id" UUID NOT NULL,
    "foto_url" TEXT NOT NULL,
    "nombre_archivo" VARCHAR(160) NOT NULL,
    "mime_type" VARCHAR(80) NOT NULL,
    "tamano_bytes" INTEGER NOT NULL,
    "creada_en" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "incidencias_fotos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "idx_incidencias_fotos_incidencia" ON "incidencias_fotos"("incidencia_id");

-- AddForeignKey
ALTER TABLE "incidencias_fotos" ADD CONSTRAINT "incidencias_fotos_incidencia_id_fkey" FOREIGN KEY ("incidencia_id") REFERENCES "incidencias"("id") ON DELETE CASCADE ON UPDATE CASCADE;
