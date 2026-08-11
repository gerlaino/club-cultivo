require 'rails_helper'

RSpec.describe 'Envíos masivos de correo', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club).tap do |c|
      c.update!(smtp_host: 'smtp.gmail.com', smtp_port: 587, smtp_user: 'org@gmail.com',
                smtp_pass: 'app-pass', smtp_from: 'org@gmail.com', smtp_from_name: 'Mitocondria')
    end
  end
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }

  let!(:ana)  { create(:paciente, club: club, nombre: 'Ana',  apellido: 'Pérez', email: 'ana@ej.com') }
  let!(:beto) { create(:paciente, club: club, nombre: 'Beto', apellido: 'Díaz',  email: 'beto@ej.com') }

  def mandar(params)
    post '/envios_masivos', headers: auth_headers, as: :json, params: params
  end

  before { sign_in_as(admin) }

  describe 'a varios pacientes' do
    it 'arma UN destinatario por paciente, nunca una lista en el To:' do
      mandar(destino: 'pacientes', paciente_ids: [ana.id, beto.id],
             asunto: 'Hola', cuerpo: 'Mensaje')

      expect(response).to have_http_status(:created)
      envio = EnvioMasivo.last
      expect(envio.total).to eq(2)
      expect(envio.destinatarios.map { |d| d['email'] }).to contain_exactly('ana@ej.com', 'beto@ej.com')
      # Cada entrada es UNA dirección: no hay ninguna con varias juntas.
      expect(envio.destinatarios).to all(satisfy { |d| !d['email'].include?(',') })
    end

    # El mail que recibe cada uno tiene que decir SU nombre, no "{{nombre}}" ni el del primero.
    it 'resuelve las variables contra cada paciente' do
      mandar(destino: 'pacientes', paciente_ids: [ana.id, beto.id],
             asunto: 'Hola {{nombre}}', cuerpo: 'Te escribimos, {{nombre_completo}}.')

      cuerpos = EnvioMasivo.last.destinatarios.map { |d| d['cuerpo'] }
      expect(cuerpos).to contain_exactly('Te escribimos, Ana Pérez.', 'Te escribimos, Beto Díaz.')
      expect(cuerpos.join).not_to include('{{')
    end

    # Un contador de "1 salteado" no le sirve a nadie; saber a quién hay que llamar, sí.
    it 'saltea a quien no tiene email y dice quién es' do
      sin_mail = create(:paciente, club: club, nombre: 'Caro', apellido: 'Luna', email: nil)

      mandar(destino: 'pacientes', paciente_ids: [ana.id, sin_mail.id],
             asunto: 'Hola', cuerpo: 'Mensaje')

      expect(EnvioMasivo.last.total).to eq(1)
      expect(JSON.parse(response.body)['salteados']).to include('Caro Luna')
    end
  end

  describe 'a direcciones libres' do
    it 'acepta una lista escrita a mano, sin paciente detrás' do
      mandar(destino: 'libre', emails: ['proveedor@ej.com', 'otro@ej.com'],
             asunto: 'Pedido', cuerpo: 'Buenas')

      expect(response).to have_http_status(:created)
      envio = EnvioMasivo.last
      expect(envio.destino).to eq('libre')
      expect(envio.destinatarios.map { |d| d['paciente_id'] }.compact).to be_empty
    end

    it 'descarta las direcciones mal escritas' do
      mandar(destino: 'libre', emails: ['bien@ej.com', 'esto-no-es-un-mail'],
             asunto: 'Pedido', cuerpo: 'Buenas')

      expect(EnvioMasivo.last.total).to eq(1)
      expect(JSON.parse(response.body)['salteados']).to include('esto-no-es-un-mail')
    end
  end

  describe 'el tope diario' do
    # Pasarse del techo de Gmail le suspende la casilla al cliente, y con ella se cae también el
    # mail de bienvenida y todo lo demás. Por eso se corta ANTES de empezar: arrancar y frenar a
    # la mitad deja a media nómina avisada y a la otra media no.
    it 'no arranca un envío que no entra en lo que queda del día' do
      allow(Correo::CupoDiario).to receive(:restante).and_return(1)

      expect {
        mandar(destino: 'pacientes', paciente_ids: [ana.id, beto.id], asunto: 'H', cuerpo: 'M')
      }.not_to change { EnvioMasivo.count }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/quedan 1/)
    end

    it 'informa cuánto queda' do
      get '/envios_masivos', headers: auth_headers

      cupo = JSON.parse(response.body)['cupo']
      expect(cupo['limite']).to eq(Correo::CupoDiario::LIMITE)
      expect(cupo['restante']).to be <= cupo['limite']
    end
  end

  describe 'quién puede' do
    it 'el dispensador no manda correo masivo' do
      sign_in_as(dispensador)
      mandar(destino: 'pacientes', paciente_ids: [ana.id], asunto: 'H', cuerpo: 'M')

      expect(response).to have_http_status(:forbidden)
    end

    it 'sin el módulo de correo, no se puede' do
      club.update!(features: club.features.merge('mailer' => false))
      mandar(destino: 'pacientes', paciente_ids: [ana.id], asunto: 'H', cuerpo: 'M')

      expect(response).to have_http_status(:forbidden)
    end

    it 'sin casilla conectada, no se puede' do
      club.update!(smtp_host: nil, smtp_user: nil, smtp_pass: nil)
      mandar(destino: 'pacientes', paciente_ids: [ana.id], asunto: 'H', cuerpo: 'M')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/casilla/i)
    end

    it 'no alcanza a pacientes de otra organización' do
      ajeno = ActsAsTenant.with_tenant(create(:club)) do
        create(:paciente, club: ActsAsTenant.current_tenant, email: 'ajeno@ej.com')
      end

      mandar(destino: 'pacientes', paciente_ids: [ajeno.id], asunto: 'H', cuerpo: 'M')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(EnvioMasivo.count).to eq(0)
    end
  end

  describe 'el envío en sí' do
    it 'manda un mail POR destinatario y lo deja en el historial del paciente' do
      mandar(destino: 'pacientes', paciente_ids: [ana.id, beto.id], asunto: 'Hola', cuerpo: 'Mensaje')
      envio = EnvioMasivo.last

      expect { EnvioMasivoJob.new.perform(envio.id) }
        .to change { MailEnviado.count }.by(2)

      expect(envio.reload.estado).to eq('completado')
      expect(envio.enviados).to eq(2)
      expect(ana.mails_enviados.count).to eq(1)
      # Cada mensaje salió a UNA sola dirección.
      expect(ActionMailer::Base.deliveries.last(2).map(&:to)).to all(have_attributes(size: 1))
    end

    # Una dirección que rebota no puede cortar los que faltan.
    it 'un destinatario que falla no frena al resto' do
      mandar(destino: 'pacientes', paciente_ids: [ana.id, beto.id], asunto: 'Hola', cuerpo: 'Mensaje')
      envio = EnvioMasivo.last
      ana.update_columns(email: nil)   # se quedó sin dirección después de armado el envío

      EnvioMasivoJob.new.perform(envio.id)

      expect(envio.reload.enviados).to eq(1)
      expect(envio.fallidos).to eq(1)
      expect(envio.estado).to eq('completado')
      expect(envio.resultados.find { |r| !r['ok'] }['error']).to be_present
    end
  end
end
