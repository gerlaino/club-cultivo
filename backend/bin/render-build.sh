#!/usr/bin/env bash
# Build de producción para Render: compila el frontend y lo deja servido por Rails
# en el mismo origen que la API (cookie de auth first-party → login en incógnito/iOS).
#
# Configurar en el servicio (Web Service Ruby) de Render:
#   Build Command:  bash bin/render-build.sh   (si Root Directory = backend)
#   Start Command:  bundle exec puma -C config/puma.rb
#   Health Check Path: /up
set -o errexit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$BACKEND_DIR/.." && pwd)"
FRONTEND_DIR="$REPO_ROOT/frontend"

echo "==> BACKEND_DIR=$BACKEND_DIR"
echo "==> FRONTEND_DIR=$FRONTEND_DIR"

# 1) Dependencias del backend
cd "$BACKEND_DIR"
bundle install

# 2) Build del frontend (API en /api relativo → mismo origen).
#    Si no encuentra la carpeta del front, FALLA fuerte (antes se salteaba en silencio).
echo "==> Building frontend..."
cd "$FRONTEND_DIR"
npm ci
VITE_API_URL=/api npm run build

# 3) Publicar el build dentro de public/ para que Rails lo sirva
echo "==> Copiando build del frontend a backend/public ..."
rm -rf "$BACKEND_DIR/public/assets"
cp -r dist/. "$BACKEND_DIR/public/"
echo "==> Contenido de public/index.html:"
ls -la "$BACKEND_DIR/public/index.html"

# 4) Migraciones
cd "$BACKEND_DIR"
bundle exec rails db:migrate

echo "==> Build OK"
