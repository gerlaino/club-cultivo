#!/usr/bin/env bash
# Build de producción para Render: compila el frontend y lo deja servido por Rails
# en el mismo origen que la API (cookie de auth first-party → login en incógnito/iOS).
#
# Configurar en el servicio (Web Service Ruby) de Render:
#   Build Command:  ./backend/bin/render-build.sh   (o bin/render-build.sh si Root Dir = backend)
#   Start Command:  bundle exec puma -C config/puma.rb
#   Health Check Path: /up
set -o errexit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$BACKEND_DIR/.." && pwd)"
FRONTEND_DIR="$REPO_ROOT/frontend"

# 1) Dependencias del backend
cd "$BACKEND_DIR"
bundle install

# 2) Build del frontend (API en /api relativo → mismo origen)
if [ -d "$FRONTEND_DIR" ]; then
  cd "$FRONTEND_DIR"
  npm ci
  VITE_API_URL=/api npm run build

  # 3) Publicar el build dentro de public/ para que Rails lo sirva
  rm -rf "$BACKEND_DIR/public/assets"
  cp -r dist/. "$BACKEND_DIR/public/"
fi

# 4) Migraciones
cd "$BACKEND_DIR"
bundle exec rails db:migrate
