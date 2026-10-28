require 'rails_helper'

# AC (Germán, 27-oct-2026): «desde admin, invitar en lote»: en la lista de pacientes, el filtro
# «Portal: sin activar», elegir uno o más y mandarles la invitación por mail. Un mail por
# destinatario y el tope de 450 por día. El que no se puede invitar vuelve con el motivo.
RSpec.describe 'Invitar al portal en lote', type: :request do
  let(:club) do
    create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:admin) { create(:user, :admin, club: club) }

  def t(&) = ActsAsTenant.with_tenant(club, &)
  def json = JSON.parse(response.body)
  def paciente(nombre, email: "#{nombre.downcase}@example.com", **attrs)
    t { create(:paciente, club: club, nombre: nombre, email: email, aprobado_at: Time.current, created_by: admin, **attrs) }
  end
  def invitar_lote(ids) = post('/api/pacientes/acceso/invitar_lote', params: { paciente_ids: ids }, as: :json)

  before { sign_in_as(admin) }

  it 'a uno solo: le llega un mail' do
    ana = paciente('Ana')

    expect { invitar_lote([ana.id]) }.to have_enqueued_mail(AccesoMailer, :portal_link).once

    expect(response).to have_http_status(:ok), response.body
    expect(json['data']).to include('enviados' => 1, 'omitidos' => [])
  end

  it 'a varios: un mail POR paciente, cada uno a su casilla' do
    ids = %w[Ana Beto Carla].map { |n| paciente(n).id }

    expect { invitar_lote(ids) }.to have_enqueued_mail(AccesoMailer, :portal_link).exactly(3).times
    expect(json['data']['enviados']).to eq(3)
    expect(t { AccesoPortal.where(paciente_id: ids).distinct.count(:paciente_id) }).to eq(3)
  end

  it 'de varios, SÓLO el que no tiene mail queda afuera, con el motivo; a los demás les llega' do
    ana  = paciente('Ana')
    beto = paciente('Beto', email: nil)

    expect { invitar_lote([ana.id, beto.id]) }.to have_enqueued_mail(AccesoMailer, :portal_link).once
    expect(json['data']['enviados']).to eq(1)
    expect(json['data']['omitidos']).to contain_exactly(include('id' => beto.id, 'motivo' => 'No tiene mail en la ficha.'))
  end

  it 'al que ya activó su portal no se lo vuelve a invitar' do
    ana = paciente('Ana')
    t { AccesoPortal.emitir!(ana).acceso.usar! }

    expect { invitar_lote([ana.id]) }.not_to have_enqueued_mail(AccesoMailer, :portal_link)
    expect(json['data']['omitidos'].first['motivo']).to eq('Ya entra a su portal.')
  end

  it 'si el lote no entra en el tope del día, no manda ninguno y dice cuántos quedan' do
    ids = %w[Ana Beto].map { |n| paciente(n).id }
    stub_const('PortalAcceso::InvitarEnLote::LIMITE_DIARIO', 1)

    expect { invitar_lote(ids) }.not_to have_enqueued_mail(AccesoMailer, :portal_link)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json['errors'].first).to include('Hoy quedan 1 envíos de 1')
  end

  it 'los links que ya salieron hoy cuentan para el tope' do
    ana  = paciente('Ana')
    beto = paciente('Beto')
    t { AccesoPortal.emitir!(ana) }
    stub_const('PortalAcceso::InvitarEnLote::LIMITE_DIARIO', 1)

    invitar_lote([beto.id])
    expect(response).to have_http_status(:unprocessable_entity)
  end

  describe 'con el correo de la organización conectado (los mails salen por su casilla)' do
    before { club.update!(smtp_host: 'smtp.gmail.com', smtp_port: 587, smtp_user: 'org@gmail.com', smtp_pass: 'app-pass') }

    it 'el tope es el mismo cupo del correo: los mails sueltos de hoy también cuentan' do
      beto = paciente('Beto')
      t do
        MailEnviado.create!(club: club, paciente: paciente('Ana'), user: admin, asunto: 'Hola', cuerpo: 'Cuerpo',
                            tipo: 'personalizado', email_destino: 'ana@example.com', enviado_at: Time.current)
      end
      stub_const('Correo::CupoDiario::LIMITE', 1)

      expect { invitar_lote([beto.id]) }.not_to have_enqueued_mail(AccesoMailer, :portal_link)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'y los links del portal de hoy le restan al cupo de los envíos masivos' do
      ana = paciente('Ana')
      expect { invitar_lote([ana.id]) }.to change { Correo::CupoDiario.restante(club) }.by(-1)
    end
  end

  it 'sin el correo conectado, los links del portal no le restan al cupo de la organización' do
    ana = paciente('Ana')
    expect { invitar_lote([ana.id]) }.not_to(change { Correo::CupoDiario.restante(club) })
  end

  it 'con el portal cerrado no manda nada' do
    ana = paciente('Ana')
    club.update!(vista_paciente_activa: false)

    invitar_lote([ana.id])
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'el dispensador no puede' do
    ana = paciente('Ana')
    sign_in_as(create(:user, :dispensador, club: club))

    invitar_lote([ana.id])
    expect(response).to have_http_status(:forbidden)
  end

  describe 'la lista dice quién está sin activar' do
    it 'cada fila trae si activó y si tiene mail' do
      ana  = paciente('Ana')
      beto = paciente('Beto', email: nil)
      t { AccesoPortal.emitir!(beto).acceso.usar! }

      get '/api/pacientes', params: { limite: 50 }
      filas = json['data'].index_by { |f| f['id'] }
      expect(filas[ana.id]['portal']).to eq('activado' => false, 'tiene_mail' => true, 'sin_activar' => true, 'invitado_at' => nil)
      expect(filas[beto.id]['portal']).to include('activado' => true, 'tiene_mail' => false, 'sin_activar' => false)
      expect(filas[beto.id]['portal']['invitado_at']).to be_present
    end

    it 'con el portal cerrado la lista no habla del portal' do
      paciente('Ana')
      club.update!(vista_paciente_activa: false)

      get '/api/pacientes', params: { limite: 50 }
      expect(json['data'].first).not_to have_key('portal')
    end
  end

  describe 'aislamiento entre organizaciones' do
    it 'un paciente de otra organización vuelve como omitido y no recibe nada' do
      otra = create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
      ajeno = ActsAsTenant.with_tenant(otra) do
        create(:paciente, club: otra, email: 'ajeno@example.com', aprobado_at: Time.current, created_by: create(:user, :admin, club: otra))
      end

      expect { invitar_lote([ajeno.id]) }.not_to have_enqueued_mail(AccesoMailer, :portal_link)
      expect(json['data']['omitidos'].first['motivo']).to eq('No es un paciente de la organización.')
      expect(AccesoPortal.unscoped.where(paciente_id: ajeno.id)).to be_empty
    end
  end
end
