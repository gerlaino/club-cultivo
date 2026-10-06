require 'rails_helper'

# AC (Germán, 4-oct-2026, plan A): en /bienvenida, quien cultiva en casa se registra SOLO y entra en
# el momento, con 30 días de prueba; confirma el mail después (7 días de gracia desde que el mail
# salió, si no se pausa). Queda constancia de qué términos aceptó. Una organización NO se registra
# sola: deja una consulta (ver contacto_publico_spec).
RSpec.describe 'Autoregistro de uso personal', type: :request do
  include ActiveJob::TestHelper

  let(:datos) do
    { nombre: 'Juana Pérez', email: 'Juana@Ejemplo.com', password: 'clave-larga-1', acepta_terminos: true }
  end

  def registrar(extra = {})
    post '/api/public/registro', params: datos.merge(extra), as: :json
  end

  def iniciar_sesion(email, password)
    post '/api/users/sign_in', params: { user: { email: email, password: password } }, as: :json
  end

  it 'informa los días de prueba y la versión de los términos (la pantalla no los escribe)' do
    get '/api/public/registro'
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('dias_prueba' => 30, 'terminos_version' => Legal::TERMINOS_VERSION)
    # La lista de precios de las páginas públicas sale de acá (6-oct-2026), no escrita en la página.
    precios = response.parsed_body['precios']
    expect(precios).to include('moneda' => 'USD', 'sede_extra' => 50)
    expect(precios['autocultivo']).to eq('precio' => 8, 'plantas_floracion' => 9, 'espacios' => 2)
    expect(precios['escalones'].map { |e| [e['pacientes'], e['un_pack'], e['dos_packs']] }).to eq([[50, 200, 350], [100, 400, 700]])
    expect(precios['pack_pacientes']).to include('pacientes' => 10, 'plantas_floracion' => 90, 'precio' => 80)
  end

  describe 'crear la cuenta' do
    it 'arma un uso personal con sólo Cultivo, 30 días de prueba, y entra con su mail' do
      expect { registrar }.to change(Club, :count).by(1).and have_enqueued_job(EnviarConfirmacionRegistroJob)
      expect(response).to have_http_status(:created)

      reg  = RegistroPersonal.last
      club = reg.club
      expect(club).to be_personal
      expect(club.features).to eq(Club::FEATURES_PERSONAL)
      expect(club.plan_trial).to be(true)
      expect(club.plan_activo_hasta).to eq(Time.zone.today + 30)
      expect(reg.user).to be_admin
      expect(reg.user.email).to eq('juana@ejemplo.com')
      expect(reg.user.first_name).to eq('Juana')
      ActsAsTenant.with_tenant(club) { expect(club.sedes.pluck(:nombre)).to eq(['Mi cultivo']) }

      iniciar_sesion('juana@ejemplo.com', 'clave-larga-1')
      expect(response).to have_http_status(:ok)
    end

    it 'guarda la constancia de los términos: versión, cuándo y desde dónde' do
      registrar
      reg = RegistroPersonal.last
      expect(reg.terminos_version).to eq(Legal::TERMINOS_VERSION)
      expect(reg.terminos_aceptados_at).to be_within(5.seconds).of(Time.current)
      expect(reg.ip).to be_present
      expect(reg.confirmado_at).to be_nil
    end

    it 'sin aceptar los términos no crea nada' do
      expect { registrar(acepta_terminos: false) }.not_to change(Club, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to match(/términos/)
    end

    it 'con un mail que ya tiene cuenta (en cualquier organización) no crea otra' do
      otro = create(:club)
      create(:user, :admin, club: otro, email: 'juana@ejemplo.com')
      expect { registrar }.not_to change(Club, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to match(/Ya hay una cuenta/)
    end

    it 'con una contraseña corta no crea nada' do
      expect { registrar(password: 'corta') }.not_to change(Club, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'el robot que llena el campo trampa recibe «listo» y no se crea nada' do
      expect { registrar(sitio: 'http://spam.example') }.not_to change(Club, :count)
      expect(response).to have_http_status(:created)
    end

    it 'la cuenta nueva no ve nada de otra organización (aislamiento de tenant)' do
      otro = create(:club)
      ActsAsTenant.with_tenant(otro) { create(:lote, club: otro) }
      registrar
      iniciar_sesion('juana@ejemplo.com', 'clave-larga-1')
      get '/api/lotes'
      expect(response).to have_http_status(:ok)
      lotes = response.parsed_body.is_a?(Hash) ? response.parsed_body['data'] : response.parsed_body
      expect(lotes).to eq([])
    end
  end

  describe 'confirmar el mail' do
    let!(:reg) { registrar; RegistroPersonal.last }

    it 'el link del mail confirma, una sola vez' do
      token = reg.nuevo_token!
      post '/api/public/registro/confirmar', params: { token: token }, as: :json
      expect(response).to have_http_status(:ok)
      expect(reg.reload).to be_confirmado
    end

    it 'un token inventado no confirma nada' do
      post '/api/public/registro/confirmar', params: { token: 'no-existe' }, as: :json
      expect(response).to have_http_status(:not_found)
      expect(reg.reload).not_to be_confirmado
    end

    it 'si la cuenta estaba pausada por no confirmar, confirmar la despausa' do
      reg.club.suspender!(motivo: 'mail_sin_confirmar')
      post '/api/public/registro/confirmar', params: { token: reg.nuevo_token! }, as: :json
      expect(reg.club.reload).not_to be_suspendido
    end

    it 'si estaba pausada porque terminó la prueba, confirmar NO la despausa' do
      reg.club.suspender!(motivo: 'prueba_terminada')
      post '/api/public/registro/confirmar', params: { token: reg.nuevo_token! }, as: :json
      expect(reg.club.reload).to be_suspendido
    end

    it 'reenviar contesta lo mismo exista o no el mail, y sólo encola si existe' do
      expect { post '/api/public/registro/reenviar', params: { email: 'nadie@ejemplo.com' }, as: :json }
        .not_to have_enqueued_job(EnviarConfirmacionRegistroJob)
      expect(response.parsed_body).to eq('ok' => true)
      expect { post '/api/public/registro/reenviar', params: { email: 'JUANA@ejemplo.com' }, as: :json }
        .to have_enqueued_job(EnviarConfirmacionRegistroJob).with(reg.id)
      expect(response.parsed_body).to eq('ok' => true)
    end
  end

  describe '/me' do
    it 'le dice al autoregistrado si confirmó el mail, cuándo se pausaría y hasta cuándo es la prueba' do
      registrar
      reg = RegistroPersonal.last
      reg.update!(mail_enviado_at: Time.current)
      iniciar_sesion('juana@ejemplo.com', 'clave-larga-1')
      get '/api/me'
      expect(response.parsed_body['autoregistro']).to include(
        'mail_confirmado' => false, 'email' => 'juana@ejemplo.com',
        'pausa_el' => (Time.zone.today + 7).to_s, 'prueba_hasta' => (Time.zone.today + 30).to_s,
      )
    end

    it 'a quien no se registró solo no le manda nada' do
      club = create(:club)
      admin = create(:user, :admin, club: club)
      sign_in_as(admin)
      get '/api/me'
      expect(response.parsed_body['autoregistro']).to be_nil
    end
  end
end
