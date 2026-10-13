require 'rails_helper'

# COMERCIAL → RENDICIONES (Germán, 13-oct-2026). El panel del admin avisaba «Rendición entregada
# sin recibir · Delivery Test rindió el 17/09 a Pablo Ezquer» y el botón «Ver rendiciones» llevaba
# a una pantalla que decía «Todavía no se rindió ninguna caja»: mostraba sólo las RECIBIDAS. Y
# aunque la hubiera mostrado, sólo podía recibirla Pablo — si Pablo no la recibe, queda trabada.
RSpec.describe 'Historial de rendiciones y reasignación', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true, 'delivery' => true }) }
  let(:admin) { create(:user, :admin, club: club, first_name: 'Germán') }
  let(:pablo) { create(:user, :dispensador, club: club, first_name: 'Pablo') }
  let(:juan)  { create(:user, :delivery, club: club, first_name: 'Juan') }
  let(:ana)   { create(:user, :delivery, club: club, first_name: 'Ana') }

  def rendicion!(delivery:, receptor:, estado: 'pendiente', rendida_at: Time.current, club_de: club)
    ActsAsTenant.with_tenant(club_de) do
      RendicionCaja.create!(club: club_de, delivery: delivery, receptor: receptor, estado: estado,
                            monto_declarado_ars: 100_000, rendida_at: rendida_at,
                            monto_recibido_ars: (estado == 'recibida' ? 100_000 : nil),
                            recibida_at: (estado == 'recibida' ? rendida_at + 1.hour : nil))
    end
  end

  def listar(mes)
    get '/rendiciones', params: { mes: mes }
    JSON.parse(response.body)['rendiciones']
  end

  describe 'la pantalla del mes' do
    it 'muestra la pendiente aunque sea de otro mes, arriba, y las del mes pedido' do
      vieja    = rendicion!(delivery: juan, receptor: pablo, rendida_at: Time.zone.local(2026, 9, 17, 12))
      del_mes  = rendicion!(delivery: ana, receptor: admin, estado: 'recibida', rendida_at: Time.zone.local(2026, 10, 2, 12))
      otro_mes = rendicion!(delivery: ana, receptor: admin, estado: 'recibida', rendida_at: Time.zone.local(2026, 8, 2, 12))

      sign_in_as(admin)
      ids = listar('2026-10').map { |r| r['id'] }

      expect(ids.first).to eq(vieja.id)
      expect(ids).to include(del_mes.id)
      expect(ids).not_to include(otro_mes.id)
    end

    it 'el último día del mes entra entero (no corta a medianoche)' do
      tarde = rendicion!(delivery: ana, receptor: admin, estado: 'recibida', rendida_at: Time.zone.local(2026, 9, 30, 23, 30))
      sign_in_as(admin)
      expect(listar('2026-09').map { |r| r['id'] }).to include(tarde.id)
    end

    it 'trae quién, cuándo y a quién se le puede reasignar' do
      rendicion!(delivery: juan, receptor: pablo)
      sign_in_as(admin)
      get '/rendiciones', params: { mes: Time.zone.today.strftime('%Y-%m') }
      body = JSON.parse(response.body)
      fila = body['rendiciones'].first

      expect(fila).to include('delivery' => juan.nombre_completo, 'receptor' => pablo.nombre_completo,
                              'delivery_id' => juan.id, 'receptor_id' => pablo.id, 'puedo_reasignar' => true)
      expect(fila['rendida_at']).to be_present
      expect(body['receptores'].map { |p| p['id'] }).to include(admin.id, pablo.id)
    end

    # Mismo nombre, mismo número: lo que el panel cuenta como pendiente, la pantalla lo muestra.
    it 'toda pendiente que avisa el panel está en la pantalla' do
      pend = rendicion!(delivery: juan, receptor: pablo, rendida_at: 40.days.ago)
      panel = ActsAsTenant.with_tenant(club) { Panel::Conduccion.new(club: club).call }
      avisadas = panel[:atencion].select { |a| a[:tipo] == 'rendicion_sin_recibir' }.map { |a| a[:id] }
      expect(avisadas).to include("rcj-#{pend.id}")

      sign_in_as(admin)
      expect(listar(Time.zone.today.strftime('%Y-%m')).map { |r| r['id'] }).to include(pend.id)
    end

    it 'aislamiento: no aparecen las rendiciones de otra organización' do
      otra = create(:club, features: { 'delivery' => true })
      ajena = rendicion!(delivery: create(:user, :delivery, club: otra), receptor: create(:user, :admin, club: otra), club_de: otra)
      sign_in_as(admin)
      expect(listar(Time.zone.today.strftime('%Y-%m')).map { |r| r['id'] }).not_to include(ajena.id)
    end
  end

  describe 'reasignar una pendiente' do
    let!(:pendiente) { rendicion!(delivery: juan, receptor: pablo, rendida_at: 26.days.ago) }

    it 'el admin la dirige a otra persona, que es la que ahora la recibe' do
      sign_in_as(admin)
      post "/rendiciones/#{pendiente.id}/reasignar", params: { receptor_id: admin.id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(pendiente.reload.receptor_id).to eq(admin.id)
      expect(pendiente.estado).to eq('pendiente') # no se recibe sola: el nuevo receptor la cuenta
      expect(JSON.parse(response.body)['puedo_recibir']).to be true
    end

    it 'queda en el rastro quién la reasignó' do
      sign_in_as(admin)
      post "/rendiciones/#{pendiente.id}/reasignar", params: { receptor_id: admin.id }, as: :json
      cambio = ActsAsTenant.with_tenant(club) { Auditoria.where(auditable: pendiente).order(:created_at).last }
      expect(cambio).to be_present
    end

    it 'no a alguien que no recibe rendiciones, ni al propio repartidor' do
      sign_in_as(admin)
      post "/rendiciones/#{pendiente.id}/reasignar", params: { receptor_id: ana.id }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      post "/rendiciones/#{pendiente.id}/reasignar", params: { receptor_id: juan.id }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(pendiente.reload.receptor_id).to eq(pablo.id)
    end

    it 'una ya recibida no se reasigna' do
      recibida = rendicion!(delivery: ana, receptor: pablo, estado: 'recibida')
      sign_in_as(admin)
      post "/rendiciones/#{recibida.id}/reasignar", params: { receptor_id: admin.id }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'el dispensador (aunque sea el receptor) no reasigna' do
      sign_in_as(pablo)
      post "/rendiciones/#{pendiente.id}/reasignar", params: { receptor_id: admin.id }, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(pendiente.reload.receptor_id).to eq(pablo.id)
    end

    it 'aislamiento: no se reasigna la de otra organización ni a alguien de otra organización' do
      otra   = create(:club, features: { 'delivery' => true })
      ajena  = rendicion!(delivery: create(:user, :delivery, club: otra), receptor: create(:user, :admin, club: otra), club_de: otra)
      extraño = create(:user, :admin, club: otra)
      sign_in_as(admin)

      post "/rendiciones/#{ajena.id}/reasignar", params: { receptor_id: admin.id }, as: :json
      expect(response).to have_http_status(:not_found)

      post "/rendiciones/#{pendiente.id}/reasignar", params: { receptor_id: extraño.id }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(pendiente.reload.receptor_id).to eq(pablo.id)
    end
  end
end
