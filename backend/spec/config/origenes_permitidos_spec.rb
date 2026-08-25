require 'rails_helper'

# AC: la app tiene que seguir aceptando conexiones de su propio servidor CUANDO SE MUEVA EL
# DOMINIO. Es la lista que usan CORS y el handshake de ActionCable.
#
# El bug que esto cierra: la lista estaba escrita dos veces —`cors.rb` y `production.rb`— y las
# dos anotaban `club-cultivo-1.onrender.com`, el sitio VIEJO. El servidor donde la app corre de
# verdad no estaba en ninguna. Al pasar `FRONTEND_URL` al dominio propio, el host de Render salía
# de la lista y a todo el que siguiera entrando por ahí —durante las horas que tarda el DNS— se le
# cortaba el tiempo real SIN UN ERROR A LA VISTA: la pantalla se queda quieta.
RSpec.describe 'App.origenes_permitidos' do
  around do |ejemplo|
    original = ENV.to_hash
    ejemplo.run
  ensure
    ENV.replace(original)
  end

  def origenes
    ENV.delete('FRONTEND_URL')
    ENV.delete('EXTRA_CORS_ORIGINS')
    yield if block_given?
    App.origenes_permitidos
  end

  it 'siempre incluye el servidor donde la app corre hoy' do
    expect(origenes).to include('https://cultivo-staging-api.onrender.com')
  end

  it 'sigue incluyendo el static legacy mientras exista' do
    expect(origenes).to include('https://club-cultivo-1.onrender.com')
  end

  # El caso que motiva todo esto.
  it 'el host de Render NO se pierde al poner el dominio propio' do
    lista = origenes { ENV['FRONTEND_URL'] = 'https://cultivoespacial.com' }

    expect(lista).to include('https://cultivoespacial.com')
    expect(lista).to include('https://cultivo-staging-api.onrender.com')
  end

  it 'suma los orígenes extra de la transición y les saca los espacios' do
    lista = origenes { ENV['EXTRA_CORS_ORIGINS'] = ' https://www.cultivoespacial.com , https://otro.test ' }

    expect(lista).to include('https://www.cultivoespacial.com', 'https://otro.test')
  end

  it 'ignora los vacíos: una variable puesta en blanco no agrega un origen vacío' do
    lista = origenes do
      ENV['FRONTEND_URL']       = '   '
      ENV['EXTRA_CORS_ORIGINS'] = 'https://uno.test,,  ,'
    end

    expect(lista).to all(be_present)
    expect(lista).to include('https://uno.test')
  end

  it 'no repite un origen que ya estaba' do
    lista = origenes { ENV['FRONTEND_URL'] = 'https://cultivo-staging-api.onrender.com' }

    expect(lista.count('https://cultivo-staging-api.onrender.com')).to eq(1)
  end
end

# AC: el link del portal que le llega al paciente por mail tiene que llevarlo a algún lado.
#
# Tenía escrito a mano `https://app.cultivoespacial.com` como respaldo — un SUBDOMINIO, cuando la
# dirección elegida para la app es la raíz. Es el mail donde recibe su contraseña.
RSpec.describe 'App.base_url' do
  around do |ejemplo|
    original = ENV.to_hash
    ejemplo.run
  ensure
    ENV.replace(original)
  end

  before { ENV.delete('FRONTEND_URL'); ENV.delete('APP_HOST') }

  it 'usa FRONTEND_URL cuando está' do
    ENV['FRONTEND_URL'] = 'https://cultivoespacial.com'

    expect(App.base_url).to eq('https://cultivoespacial.com')
  end

  it 'se arma con APP_HOST cuando no hay FRONTEND_URL, y siempre en https' do
    ENV['APP_HOST'] = 'cultivoespacial.com'

    expect(App.base_url).to eq('https://cultivoespacial.com')
  end

  it 'sin ninguna de las dos cae a local, no a un dominio inventado' do
    expect(App.base_url).to eq('http://localhost:3001')
  end
end
