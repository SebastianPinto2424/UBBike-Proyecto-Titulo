#!/usr/bin/env bash
set -euo pipefail

URL="${1:-}"
URL="${URL%/}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! "$URL" =~ ^https://[^/[:space:]]+$ ]]; then
  echo "Uso: ./compilar-apk.sh https://ubbike.midominio.cl" >&2
  exit 1
fi

if [[ ! -f "$RAIZ/mobile/android/app/google-services.json" ]]; then
  echo "Falta mobile/android/app/google-services.json. Se descarga en Firebase, Configuracion del proyecto, app Android cl.ubiobio.ubbike." >&2
  exit 1
fi

if [[ ! -f "$RAIZ/mobile/android/key.properties" ]]; then
  echo "Aviso: no existe mobile/android/key.properties; la APK se firma con la llave de depuracion de este equipo." >&2
fi

if curl -fsS --max-time 15 "$URL/health" >/dev/null; then
  echo "Backend en linea: $URL"
else
  echo "Aviso: $URL/health no respondio. La APK se compila igual." >&2
fi

cd "$RAIZ/mobile"
flutter pub get
flutter build apk --release "--dart-define=API_BASE_URL=$URL"

mkdir -p "$RAIZ/apks"
NOMBRE="ubbike-${URL#https://}-$(date +%Y%m%d-%H%M).apk"
cp build/app/outputs/flutter-apk/app-release.apk "$RAIZ/apks/$NOMBRE"
echo "APK lista: apks/$NOMBRE"
