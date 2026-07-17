require 'rails_helper'

# Disponibilidad de stock: para qué está habilitado cada stock (dispensa / produccion /
# ambas / ninguna). Filtra el carrito de dispensa, bloquea producir, y valida al dispensar.
RSpec.describe 'Stock — disponibilidad', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club) }
  let(:lote)  { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) }

  def stock_con(disp)
    create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                   cantidad: 100, costo_unitario_ars: 2, disponibilidad: disp)
  end

  describe 'modelo' do
    it 'default ambas y scopes/aptitudes coherentes' do
      s = create(:stock, club: club, sede: sede, lote: lote, cantidad: 10)
      expect(s.disponibilidad).to eq('ambas')
      expect(s.apto_dispensa?).to be(true)
      expect(s.apto_produccion?).to be(true)
    end

    it "'ninguna' no es apto para nada" do
      s = stock_con('ninguna')
      expect(s.apto_dispensa?).to be(false)
      expect(s.apto_produccion?).to be(false)
    end
  end

  describe 'GET /stocks?para_dispensa=true' do
    before { sign_in_as(admin) }

    it 'excluye el stock no habilitado para dispensa' do
      apto    = stock_con('dispensa')
      ambas   = stock_con('ambas')
      solo_prod = stock_con('produccion')
      ninguna = stock_con('ninguna')

      get '/stocks', params: { sede_id: sede.id, para_dispensa: true }, headers: auth_headers
      ids = JSON.parse(response.body).map { |s| s['id'] }
      expect(ids).to include(apto.id, ambas.id)
      expect(ids).not_to include(solo_prod.id, ninguna.id)
    end

    it 'sin el flag, las vistas de gestión ven todo' do
      solo_prod = stock_con('produccion')
      get '/stocks', params: { sede_id: sede.id }, headers: auth_headers
      ids = JSON.parse(response.body).map { |s| s['id'] }
      expect(ids).to include(solo_prod.id)
    end
  end

  describe 'POST /stocks/:id/producir' do
    before { sign_in_as(admin) }

    it 'bloquea producir desde un stock no habilitado para producción' do
      s = stock_con('dispensa')
      post "/stocks/#{s.id}/producir",
           params: { gramos_usados: 10, forma_producto: 'aceite', cantidad_producida: 5, unidad: 'ml' },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/producción/)
    end
  end

  describe 'validación al dispensar' do
    it 'una dispensa contra stock no apto para dispensa es inválida' do
      paciente = create(:paciente, club: club, created_by: admin)
      s = stock_con('produccion')
      d = Dispensacion.new(paciente: paciente, user: admin, stock: s, sede: sede,
                           cantidad: 5, medio_pago: 'efectivo', fecha_dispensacion: Date.today,
                           aporte_socio_ars: 100)
      expect(d).not_to be_valid
      expect(d.errors[:stock].join).to match(/habilitado para dispensa/)
    end
  end
end
