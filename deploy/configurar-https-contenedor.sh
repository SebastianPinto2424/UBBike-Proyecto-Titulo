#!/usr/bin/env bash
set -euo pipefail

PUBLIC_HOST="${PUBLIC_HOST:?Define PUBLIC_HOST con la IP o dominio publico del contenedor}"
PUBLIC_HTTPS_PORT="${PUBLIC_HTTPS_PORT:-443}"
CERT_DIR="${CERT_DIR:-/etc/ssl/ubbike}"
CERT_FILE="$CERT_DIR/ubbike.crt"
KEY_FILE="$CERT_DIR/ubbike.key"
SITE_FILE="/etc/apache2/sites-available/ubbike.conf"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_ROOT/deploy/apache/ubbike-https.conf.example"

if [[ "$EUID" -ne 0 ]]; then
  echo "Ejecuta este script como root."
  exit 1
fi

if [[ ! -f "$TEMPLATE" ]]; then
  echo "No se encontro $TEMPLATE"
  exit 1
fi

mkdir -p "$CERT_DIR"

if [[ "$PUBLIC_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  SAN="IP:$PUBLIC_HOST"
else
  SAN="DNS:$PUBLIC_HOST"
fi

if [[ ! -s "$CERT_FILE" || ! -s "$KEY_FILE" ]]; then
  openssl req -x509 -nodes -newkey rsa:3072 -sha256 -days 365 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/CN=$PUBLIC_HOST" \
    -addext "subjectAltName=$SAN"
fi

chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"

if [[ "$PUBLIC_HTTPS_PORT" == "443" ]]; then
  PUBLIC_ORIGIN="https://$PUBLIC_HOST"
else
  PUBLIC_ORIGIN="https://$PUBLIC_HOST:$PUBLIC_HTTPS_PORT"
fi

a2enmod ssl headers rewrite proxy proxy_http proxy_wstunnel

if [[ -f "$SITE_FILE" ]]; then
  cp "$SITE_FILE" "$SITE_FILE.bak.$(date +%Y%m%d%H%M%S)"
fi

sed \
  -e "s|/etc/letsencrypt/live/<DOMINIO_O_IP_PUBLICA>/fullchain.pem|$CERT_FILE|g" \
  -e "s|/etc/letsencrypt/live/<DOMINIO_O_IP_PUBLICA>/privkey.pem|$KEY_FILE|g" \
  -e "s|https://%{SERVER_NAME}/|$PUBLIC_ORIGIN/|g" \
  -e "s|<DOMINIO_O_IP_PUBLICA>|$PUBLIC_HOST|g" \
  "$TEMPLATE" > "$SITE_FILE"

a2dissite 000-default >/dev/null 2>&1 || true
a2ensite ubbike >/dev/null
apache2ctl configtest

if command -v systemctl >/dev/null 2>&1 && systemctl is-active apache2 >/dev/null 2>&1; then
  systemctl reload apache2
else
  service apache2 reload
fi

curl --fail --silent --show-error --insecure https://127.0.0.1/salud
printf '\nHTTPS activo en %s\n' "$PUBLIC_ORIGIN"
printf 'Certificado publico: %s\n' "$CERT_FILE"
