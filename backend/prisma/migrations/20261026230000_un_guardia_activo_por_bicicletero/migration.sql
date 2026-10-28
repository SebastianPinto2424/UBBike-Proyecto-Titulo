UPDATE "asignaciones_guardias" AS a
SET "activa" = FALSE,
    "termina_en" = NOW(),
    "actualizada_en" = NOW()
WHERE a."activa" = TRUE
  AND EXISTS (
    SELECT 1
    FROM "asignaciones_guardias" AS b
    WHERE b."activa" = TRUE
      AND b."bicicletero_id" = a."bicicletero_id"
      AND (b."inicia_en", b."id") > (a."inicia_en", a."id")
  );

UPDATE "asignaciones_guardias" AS a
SET "activa" = FALSE,
    "termina_en" = NOW(),
    "actualizada_en" = NOW()
WHERE a."activa" = TRUE
  AND EXISTS (
    SELECT 1
    FROM "asignaciones_guardias" AS b
    WHERE b."activa" = TRUE
      AND b."guardia_id" = a."guardia_id"
      AND (b."inicia_en", b."id") > (a."inicia_en", a."id")
  );

CREATE UNIQUE INDEX "idx_asignaciones_bicicletero_unica_activa"
  ON "asignaciones_guardias"("bicicletero_id")
  WHERE "activa" = TRUE;

CREATE UNIQUE INDEX "idx_asignaciones_guardia_unica_activa"
  ON "asignaciones_guardias"("guardia_id")
  WHERE "activa" = TRUE;
