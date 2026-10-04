require 'rails_helper'

# AC (4-oct-2026): el formulario de /bienvenida guarda la consulta SIEMPRE (el correo puede fallar),
# le avisa al super admin por push y por mail, y queda en su bandeja. Incluye el «botón de
# arrepentimiento» (tipo `baja`).
RSpec.describe 'Contacto desde /bienvenida', type: :request do
  include ActiveJob::TestHelper

  let!(:super_admin) { create(:user, :super_admin, email: 'plataforma@ejemplo.com') }
  let(:datos) { { tipo: 'organizacion', nombre: 'Ana', email: 'ana@ong.org', organizacion: 'ONG Verde', mensaje: 'Somos 80 pacientes' } }

  it 'guarda la consulta y avisa al super admin por push (tipo del catálogo) y por mail' do
    allow(PushNotificationService).to receive(:notify_user_async)
    expect { post '/api/public/contacto', params: datos, as: :json }
      .to change(SolicitudContacto, :count).by(1)
      .and have_enqueued_mail(AccesoMailer, :nueva_consulta)
      .and have_enqueued_mail(AccesoMailer, :acuse_consulta)
    expect(response).to have_http_status(:created)
    expect(PushNotificationService).to have_received(:notify_user_async)
      .with(super_admin, hash_including(tipo: 'consulta_nueva'))
    expect(SolicitudContacto.last).to have_attributes(tipo: 'organizacion', organizacion: 'ONG Verde', atendida_at: nil)
  end

  it 'el pedido de arrepentimiento es una consulta más' do
    post '/api/public/contacto', params: datos.merge(tipo: 'baja'), as: :json
    expect(response).to have_http_status(:created)
    # Res. SCI 424/2020: quien se arrepiente recibe un código de trámite.
    expect(response.parsed_body['codigo']).to eq("CE-#{SolicitudContacto.last.id.to_s.rjust(6, '0')}")
    expect(SolicitudContacto.last.tipo_label).to eq('Arrepentimiento / baja')
  end

  it 'sin mail válido no guarda' do
    expect { post '/api/public/contacto', params: datos.merge(email: 'no-es-mail'), as: :json }
      .not_to change(SolicitudContacto, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'un tipo inventado no se guarda' do
    post '/api/public/contacto', params: datos.merge(tipo: 'otro'), as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'el campo trampa descarta al robot sin decirle nada' do
    expect { post '/api/public/contacto', params: datos.merge(sitio: 'x'), as: :json }
      .not_to change(SolicitudContacto, :count)
    expect(response).to have_http_status(:created)
  end

  describe 'la bandeja del super admin' do
    let!(:consulta) { SolicitudContacto.create!(datos) }

    it 'la ve y la marca atendida' do
      sign_in_as(super_admin)
      get '/api/super_admin/consultas'
      expect(response.parsed_body['pendientes']).to eq(1)
      expect(response.parsed_body['consultas'].first).to include('nombre' => 'Ana', 'tipo_label' => 'Organización')

      patch "/api/super_admin/consultas/#{consulta.id}", params: { atendida: true }, as: :json
      expect(consulta.reload.atendida_at).to be_present
      expect(consulta.atendida_por).to eq(super_admin)
    end

    it 'el admin de una organización no la ve' do
      club = create(:club)
      sign_in_as(create(:user, :admin, club: club))
      get '/api/super_admin/consultas'
      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'el super admin tiene «Consulta nueva» en su catálogo de avisos, y prendido' do
    expect(Notificaciones::Catalogo.para(super_admin).map { |t| t[:clave] }).to eq(['consulta_nueva'])
    expect(super_admin.quiere_push?('consulta_nueva')).to be(true)
  end
end
