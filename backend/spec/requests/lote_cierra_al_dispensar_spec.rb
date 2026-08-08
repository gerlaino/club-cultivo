require 'rails_helper'

# El ciclo del lote tiene que cerrarse solo cuando se va el último gramo. NO pasaba:
# `Dispensacion#decrementar_stock` usa `decrement!(:cantidad)`, que baja la cantidad pero no
# toca el estado del stock — y el callback que finaliza el lote escucha el CAMBIO DE ESTADO.
# Resultado: se dispensaba un lote entero, el stock quedaba 'asignado' en cero y el lote se
# quedaba en 'curado' para siempre.
RSpec.describe 'El lote cierra su ciclo al dispensarse', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:paciente)    { create(:paciente, club: club, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala, estado: 'curado') }

  let!(:flor) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 100, precio_sugerido_ars: 100)
  end

  before { sign_in_as(dispensador) }

  def dispensar(cantidad, stock: flor)
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { medio_pago: 'efectivo',
                                   items: [{ stock_id: stock.id, cantidad: cantidad }] } },
         headers: auth_headers
  end

  it 'no cierra el lote mientras quede producto' do
    dispensar(40)

    expect(response).to have_http_status(:created)
    expect(flor.reload.cantidad).to eq(60)
    expect(lote.reload.estado).to eq('curado')
  end

  it 'cierra el lote cuando se dispensa el último gramo' do
    dispensar(100)

    expect(response).to have_http_status(:created)
    expect(flor.reload.cantidad).to eq(0)
    expect(flor.reload.estado).to eq('agotado')
    expect(lote.reload.estado).to eq('finalizado')
  end

  it 'deja el evento con el autor de la dispensación, no un registro anónimo' do
    dispensar(100)

    evento = lote.reload.lote_eventos.find_by(estado_nuevo: 'finalizado')
    expect(evento).to be_present
    expect(evento.descripcion).to include('Stock agotado')
    expect(evento.user_id).to eq(dispensador.id)
  end

  context 'cuando el lote tiene derivados' do
    let!(:hash_del_lote) do
      Stock.create!(sede: sede, lote: lote, origen: 'derivado_lote', forma_producto: 'hash',
                    unidad: 'g', cantidad: 20, precio_sugerido_ars: 300,
                    lote_origen_consumido_g: 60, es_split: true)
    end

    it 'NO cierra el lote si se acabó la flor pero queda hash suyo' do
      dispensar(100)

      expect(response).to have_http_status(:created)
      expect(flor.reload.estado).to eq('agotado')
      expect(lote.reload.estado).to eq('curado')
    end

    it 'cierra recién cuando se dispensa también el derivado' do
      dispensar(100)
      expect(lote.reload.estado).to eq('curado')

      dispensar(20, stock: hash_del_lote)

      expect(response).to have_http_status(:created)
      expect(hash_del_lote.reload.estado).to eq('agotado')
      expect(lote.reload.estado).to eq('finalizado')
    end
  end
end
