-- AlterTable
ALTER TABLE "incidencias" ADD COLUMN     "recordatorios" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "ultimo_recordatorio_en" TIMESTAMPTZ(6);
