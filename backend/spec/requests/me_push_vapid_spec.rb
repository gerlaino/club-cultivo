require 'rails_helper'

# La clave pública VAPID la manda el backend en /me. Antes vivía en el build del frontend
# (`VITE_VAPID_PUBLIC_KEY`), que en producción nadie fijaba: «Activar notificaciones» quedó
# compilado como `return false` y nunca existió una suscripción a la que mandarle un push.
RSpec.describe 'GET /me — clave pública para push', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  before { sign_in_as(admin) }

  def clave
    get '/me', headers: auth_headers
    JSON.parse(response.body)['push_vapid_public_key']
  end

  it 'es la misma con la que el job firma los envíos' do
    with_env('VAPID_PUBLIC_KEY' => 'BClavePublicaDePrueba') do
      expect(clave).to eq('BClavePublicaDePrueba')
    end
  end

  it 'es nula cuando este servidor no tiene push configurado, para que la pantalla no ofrezca el botón' do
    with_env('VAPID_PUBLIC_KEY' => nil) do
      expect(clave).to be_nil
    end
  end

  it 'una clave vacía cuenta como no configurada' do
    with_env('VAPID_PUBLIC_KEY' => '') do
      expect(clave).to be_nil
    end
  end

  def with_env(vars)
    viejas = vars.keys.to_h { |k| [k, ENV[k]] }
    vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    viejas.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
