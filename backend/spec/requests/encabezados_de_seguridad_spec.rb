require 'rails_helper'

# AC (29-oct-2026): toda respuesta —la API y la cáscara del frontend— le dice al navegador que la
# app no se muestra dentro de otra página, que no adivine el tipo de un archivo y que no mande la
# dirección completa al salir. En producción no llegaba ninguno (HDR-01).
RSpec.describe 'Encabezados de seguridad', type: :request do
  ESPERADOS = {
    'x-frame-options' => 'SAMEORIGIN',
    'x-content-type-options' => 'nosniff',
    'referrer-policy' => 'strict-origin-when-cross-origin'
  }.freeze

  it 'van en la API, también sin sesión' do
    get '/api/me', as: :json
    ESPERADOS.each { |k, v| expect(response.headers[k]).to eq(v), k }
    expect(response.headers['content-security-policy']).to include("frame-ancestors 'self'")
  end

  it 'van en lo que se sirve de public/ (la cáscara de la app)' do
    archivo = Dir[Rails.public_path.join('*.{html,txt,png,ico}')].first
    skip 'sin archivos en public/' unless archivo

    get "/#{File.basename(archivo)}"
    ESPERADOS.each { |k, v| expect(response.headers[k]).to eq(v), k }
  end
end
