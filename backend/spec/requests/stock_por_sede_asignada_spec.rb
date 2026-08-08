require 'rails_helper'

# Asignarle una sede a un dispensador no servía de nada en el inventario: veía —y podía
# dispensar— el stock de TODAS las sedes del club. La asignación existe justamente para eso.
#
# Regla: con sedes asignadas se ve lo de esas sedes; sin ninguna asignada se ve todo (club de
# una sola sede, o un admin que no se asignó nada). El stock del POOL (sin sede) se ve siempre:
# no pertenece a ninguna sede, así que no hay asignación que lo acote.
RSpec.describe 'Stock acotado a las sedes asignadas', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:norte) { create(:sede, club: club, created_by: admin, nombre: 'Finca Norte') }
  let(:sur)   { create(:sede, club: club, created_by: admin, nombre: 'Finca Sur') }
  let(:lote)  { create(:lote, club: club) }

  let!(:stock_norte) do
    create(:stock, club: club, sede: norte, lote: lote, cantidad: 100, estado: 'asignado')
  end
  let!(:stock_sur) do
    create(:stock, club: club, sede: sur, lote: lote, cantidad: 200, estado: 'asignado')
  end

  let(:dispensador) { create(:user, :dispensador, club: club) }

  def ids_visibles
    get '/api/stocks'
    expect(response).to have_http_status(:ok), response.body
    JSON.parse(response.body).map { |s| s['id'] }
  end

  context 'un dispensador con la Finca Norte asignada' do
    before do
      dispensador.sedes_asignadas << norte
      sign_in_as(dispensador)
    end

    it 've el stock de su sede' do
      expect(ids_visibles).to include(stock_norte.id)
    end

    it 'NO ve el stock de la otra sede' do
      expect(ids_visibles).not_to include(stock_sur.id)
    end

    it 'tampoco lo ve pidiendo esa sede explícitamente' do
      get "/api/stocks?sede_id=#{sur.id}"

      expect(JSON.parse(response.body)).to be_empty
    end

    it 'la pestaña de inventario respeta lo mismo' do
      get '/api/stocks/inventario'

      ids = JSON.parse(response.body)['stocks'].map { |s| s['id'] }
      expect(ids).to include(stock_norte.id)
      expect(ids).not_to include(stock_sur.id)
    end
  end

  context 'con dos sedes asignadas' do
    before do
      dispensador.sedes_asignadas << norte
      dispensador.sedes_asignadas << sur
      sign_in_as(dispensador)
    end

    it 've el stock de las dos' do
      expect(ids_visibles).to include(stock_norte.id, stock_sur.id)
    end
  end

  context 'sin ninguna sede asignada' do
    before { sign_in_as(dispensador) }

    it 've todo el club, como antes' do
      expect(ids_visibles).to include(stock_norte.id, stock_sur.id)
    end
  end

  context 'el stock del pool (sin sede)' do
    let!(:stock_pool) do
      create(:stock, club: club, sede: nil, lote: lote, cantidad: 50, estado: 'asignado')
    end

    before do
      dispensador.sedes_asignadas << norte
      sign_in_as(dispensador)
    end

    it 'se ve igual: no es de ninguna sede' do
      expect(ids_visibles).to include(stock_pool.id)
    end
  end

  describe 'las reservas siguen el mismo criterio' do
    let(:paciente) { create(:paciente, club: club, created_by: admin) }

    def reserva_de(stock)
      Reserva.create!(club: club, paciente: paciente, stock: stock, cantidad: 5,
                      fecha_entrega_estimada: Date.current + 1, estado: 'pendiente',
                      aporte_estimado_ars: 500, user: admin)
    end

    it 'sólo muestra las del stock de sus sedes' do
      propia = reserva_de(stock_norte)
      ajena  = reserva_de(stock_sur)
      dispensador.sedes_asignadas << norte
      sign_in_as(dispensador)

      get '/api/reservas'

      ids = JSON.parse(response.body)['reservas'].map { |r| r['id'] }
      expect(ids).to include(propia.id)
      expect(ids).not_to include(ajena.id)
    end
  end
end
