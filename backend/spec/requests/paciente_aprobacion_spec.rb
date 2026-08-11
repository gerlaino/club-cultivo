require 'rails_helper'

# AC: dar de alta a alguien es una decisión de ADMISIÓN, no una operación de mostrador.
#
# El dispensador y el supervisor pueden cargar la ficha de quien llega —no se manda de vuelta a
# nadie— pero entra como SOLICITUD: no puede recibir dispensaciones ni reservas hasta que admin
# o médico la aprueben. Admin y médico aprueban en el mismo acto de crear.
RSpec.describe 'Aprobación de pacientes', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:medico)      { create(:user, :medico, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:supervisor)  { create(:user, :supervisor, club: club) }

  def alta(datos = {})
    post '/api/pacientes', params: { paciente: {
      nombre: 'Nuevo', apellido: 'Paciente', dni: "4#{rand(1_000_000..9_999_999)}",
      fecha_nacimiento: '1990-05-05'
    }.merge(datos) }
    JSON.parse(response.body)['data']
  end

  describe 'quién crea aprobado y quién deja una solicitud' do
    it 'el admin aprueba en el mismo acto: para él dar de alta ES admitir' do
      sign_in_as(admin)
      expect(alta['aprobado_at']).to be_present
    end

    it 'el médico también' do
      sign_in_as(medico)
      expect(alta['aprobado_at']).to be_present
    end

    it 'el dispensador deja una solicitud pendiente' do
      sign_in_as(dispensador)
      expect(alta['aprobado_at']).to be_nil
    end

    it 'el supervisor también — atiende el mostrador igual que el dispensador' do
      # Antes el supervisor NO podía crear pacientes mientras el dispensador sí, aunque el
      # supervisor es el rol más senior de los dos. Era una incoherencia, no una regla.
      sign_in_as(supervisor)
      expect(response).not_to have_http_status(:forbidden)
      expect(alta['aprobado_at']).to be_nil
    end

    it 'avisa a admin y a médico, que son los que pueden aprobar' do
      sign_in_as(dispensador)
      expect { alta }.to change { AlertaInterna.where(tipo: 'paciente_pendiente_aprobacion').count }.by(2)
      expect(AlertaInterna.where(tipo: 'paciente_pendiente_aprobacion').pluck(:destinada_a_role))
        .to match_array(%w[admin medico])
    end
  end

  describe 'un paciente pendiente no puede recibir producto' do
    let(:paciente) { create(:paciente, club: club, created_by: dispensador, desde_mostrador: true) }
    let(:stock)    { create(:stock, club: club, cantidad: 100, cantidad_inicial: 100) }

    it 'la dispensación se rechaza y el mensaje dice qué hacer' do
      d = Dispensacion.new(user: dispensador, paciente: paciente, stock: stock, cantidad: 5,
                           fecha_dispensacion: Time.zone.today, precio_unitario_ars: 100)

      expect(d).not_to be_valid
      expect(d.errors[:base].join).to include('pendiente de aprobación')
      expect(d.errors[:base].join).to include('aprobarlo antes de dispensarle')
    end

    it 'la reserva también: apartar producto es adelantarse a la admisión' do
      r = Reserva.new(club: club, paciente: paciente, stock: stock, cantidad: 5,
                      fecha_entrega_estimada: Date.current + 2.days)

      expect(r).not_to be_valid
      expect(r.errors[:base].join).to include('pendiente de aprobación')
    end

    it 'una vez aprobado, dispensar funciona normal' do
      paciente.aprobar!(admin)

      d = Dispensacion.new(user: dispensador, paciente: paciente, stock: stock, cantidad: 5,
                           fecha_dispensacion: Time.zone.today, precio_unitario_ars: 100)

      expect(d.errors[:base].join).not_to include('pendiente de aprobación')
    end
  end

  describe 'POST /pacientes/:id/aprobar' do
    let!(:paciente) { create(:paciente, club: club, created_by: dispensador, desde_mostrador: true) }

    it 'el admin aprueba y queda registrado quién fue' do
      sign_in_as(admin)
      post "/api/pacientes/#{paciente.id}/aprobar"

      expect(response).to have_http_status(:ok)
      expect(paciente.reload.aprobado_at).to be_present
      expect(paciente.aprobado_por_id).to eq(admin.id)
    end

    it 'el médico también puede' do
      sign_in_as(medico)
      post "/api/pacientes/#{paciente.id}/aprobar"
      expect(response).to have_http_status(:ok)
    end

    %i[dispensador supervisor].each do |rol|
      it "el #{rol} NO puede aprobar su propia alta" do
        sign_in_as(send(rol))
        post "/api/pacientes/#{paciente.id}/aprobar"

        expect(response).to have_http_status(:forbidden)
        expect(paciente.reload).to be_pendiente_aprobacion
      end
    end

    it 'aprobar dos veces no pisa quién aprobó primero' do
      sign_in_as(admin)
      post "/api/pacientes/#{paciente.id}/aprobar"
      primera = paciente.reload.aprobado_at

      post "/api/pacientes/#{paciente.id}/aprobar"
      expect(response).to have_http_status(:unprocessable_entity)
      expect(paciente.reload.aprobado_at).to eq(primera)
    end
  end

  describe 'los pacientes que ya existían' do
    # El riesgo más grande del cambio: si el backfill de la migración fallara, TODO el padrón
    # quedaría pendiente y ninguna organización podría dispensarle a nadie.
    it 'quedan aprobados, no pendientes' do
      viejo = create(:paciente, club: club, created_by: admin)
      expect(viejo.reload).to be_aprobado
    end
  end

  describe 'el padrón informa cuántas altas esperan' do
    it 'las cuenta aparte en los KPIs' do
      create(:paciente, club: club, created_by: dispensador, desde_mostrador: true)
      create(:paciente, club: club, created_by: admin)

      sign_in_as(admin)
      get '/api/pacientes'

      expect(JSON.parse(response.body).dig('meta', 'kpis', 'pendientes_aprobacion')).to eq(1)
    end
  end
end
