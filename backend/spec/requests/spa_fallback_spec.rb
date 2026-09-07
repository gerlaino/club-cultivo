require 'rails_helper'

# LA PWA INSTALADA ABRE `/m`, Y ESO TIENE QUE DEVOLVER LA APP.
#
# `render file:` no existe en modo API y no falla: devuelve una respuesta VACÍA —un espacio, con
# `text/plain`— en silencio. Toda ruta profunda contestaba 200 con la pantalla en blanco, y en una
# instalación NUEVA de la PWA la primera navegación va a la red: pantalla negra, sin JS, sin
# service worker que se registre. No había forma de salir de ahí.
#
# No se veía porque `/` lo sirve el middleware de estáticos sin pasar por el controller, y en
# desarrollo y test no hay `public/index.html`, o sea que se caía siempre por la otra rama — que es
# justamente por lo que este spec CREA el archivo.
RSpec.describe 'La SPA se sirve en cualquier ruta', type: :request do
  # URL ABSOLUTA A PROPÓSITO. El helper de specs le pone `/api` a todo lo que no empiece con
  # `/api`, `/webhooks`, `/public/`… o `http`: sin esto, `get '/m'` probaba `/api/m` y el spec
  # pasaba por la razón equivocada — que es peor que no tenerlo.
  def como_navegador(ruta)
    get "http://www.example.com#{ruta}", headers: { 'Accept' => 'text/html' }
  end

  let(:index) { Rails.root.join('public', 'index.html') }
  let(:contenido) { '<!doctype html><html><head><title>Cultivo Espacial</title></head><body><div id="app"></div></body></html>' }

  around do |ejemplo|
    existia = index.exist?
    previo  = existia ? index.read : nil
    index.dirname.mkpath
    index.write(contenido)
    ejemplo.run
    existia ? index.write(previo) : index.delete
  end

  # `/m` es el `start_url` del manifest: es LA ruta que abre la app instalada.
  it 'devuelve el HTML de la app en /m, que es lo que abre la PWA' do
    como_navegador('/m')

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/html')
    expect(response.body).to include('<div id="app">')
  end

  it 'y en cualquier otra ruta del frontend' do
    ['/login', '/mostrador', '/m/mostrador', '/pacientes/7'].each do |ruta|
      como_navegador(ruta)

      expect(response.body).to include('<div id="app">'),
        "#{ruta} devolvió #{response.status} #{response.media_type}: #{response.body[0, 120].inspect}"
    end
  end

  # El shell nombra los assets por hash: uno viejo cacheado apunta a archivos que ya no existen, y
  # ésa es la otra forma de que un arreglo no llegue nunca al teléfono.
  it 'sin caché' do
    como_navegador('/m')

    expect(response.headers['Cache-Control']).to include('no-store')
  end

  # La API no se toca: un endpoint que no existe tiene que contestar como API, no devolver el HTML
  # de la app —que un cliente esperando JSON no puede leer—.
  it 'no se come las rutas de la API' do
    get '/api/no-existe', headers: { 'Accept' => 'application/json' }

    expect(response.body).not_to include('<div id="app">')
  end
end
