require 'rails_helper'

RSpec.describe 'Cambio de rol — guard de despachos pendientes', type: :request do
  include AuthHelpers

  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:delivery)    { create(:user, club: club, role: 'delivery') }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente) do
    create(:paciente, club: club, created_by: admin, telefono: '1',
           domicilio_calle: 'X', domicilio_ciudad: 'Y')
  end
  let!(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }

  def crear_despacho
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 500,
                                   con_envio: true, delivery_id: delivery.id, usar_domicilio_paciente: true } },
         headers: auth_headers
  end

  it 'bloquea cambiar el rol de un delivery con despachos pendientes' do
    sign_in_as(dispensador)
    crear_despacho
    expect(response).to have_http_status(:created)

    delete '/api/users/sign_out'
    sign_in_as(admin)
    patch "/usuarios/#{delivery.id}", params: { user: { role: 'cultivador' } }, headers: auth_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(delivery.reload.role).to eq('delivery')
    expect(JSON.parse(response.body)['errors'].first).to match(/pendiente/)
  end

  it 'permite cambiar el rol de un delivery sin despachos pendientes' do
    sign_in_as(admin)
    patch "/usuarios/#{delivery.id}", params: { user: { role: 'cultivador' } }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(delivery.reload.role).to eq('cultivador')
  end

  # CAMBIAR EL ROL PASA POR LAS MISMAS PUERTAS QUE CREARLO (Germán, sep-2026). `update` aceptaba
  # cualquier rol: uno que no se ofrece, uno sin módulo, o pisando el cupo del plan.
  describe 'las mismas puertas que el alta' do
    before { sign_in_as(admin) }

    it 'no deja pasar a un rol que no se ofrece (supervisor, auditor, abogado)' do
      %w[supervisor auditor abogado].each do |rol|
        patch "/usuarios/#{dispensador.id}", params: { user: { role: rol } }, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity), rol
        expect(JSON.parse(response.body)['errors'].first).to match(/no está disponible/)
      end
      expect(dispensador.reload.role).to eq('dispensador')
    end

    it 'no deja pasar a un rol cuyo módulo la organización no tiene' do
      club.update!(features: club.features.merge('delivery' => false))
      patch "/usuarios/#{dispensador.id}", params: { user: { role: 'delivery' } }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].first).to match(/necesita el módulo/)
    end

    it 'respeta el cupo del plan: en Básico no puede haber dos cultivadores por cambio de rol' do
      club.update!(plan: 'basico')
      create(:user, :cultivador, club: club)
      patch "/usuarios/#{dispensador.id}", params: { user: { role: 'cultivador' } }, headers: auth_headers

      expect(response).to have_http_status(:payment_required)
      expect(dispensador.reload.role).to eq('dispensador')
    end

    it 'el cambio queda en la auditoría del usuario, con quién y de qué a qué' do
      patch "/usuarios/#{dispensador.id}", params: { user: { role: 'cultivador' } }, headers: auth_headers
      expect(response).to have_http_status(:ok)

      a = Auditoria.where(auditable: dispensador).order(:created_at).last
      expect(a.user_id).to eq(admin.id)
      expect(a.cambios['role']).to eq(%w[dispensador cultivador])
    end

    it 'editar nombre o mail sin tocar el rol no pasa por ninguna puerta' do
      club.update!(plan: 'basico')
      patch "/usuarios/#{dispensador.id}", params: { user: { first_name: 'Dani', role: 'dispensador' } }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(dispensador.reload.first_name).to eq('Dani')
    end
  end
end
