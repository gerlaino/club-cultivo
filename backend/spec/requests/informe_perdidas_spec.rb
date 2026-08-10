require 'rails_helper'

# Ningún informe decía cuánto se PERDIÓ. Producción cuenta lo que salió bien y trazabilidad
# cierra el balance de un producto, pero el club no tenía dónde ver el total de lo que se cayó:
# plantas que no llegaron a cosecha, merma de inventario, vencido en góndola.
RSpec.describe 'Informe de pérdidas', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  before { sign_in_as(admin) }

  def informe
    get '/api/informes/perdidas'
    expect(response).to have_http_status(:ok), response.body
    JSON.parse(response.body)
  end

  describe 'plantas descartadas' do
    before do
      create(:plant, lote: lote, club: club, state: 'descartada', motivo_descarte: 'plaga')
      create(:plant, lote: lote, club: club, state: 'descartada', motivo_descarte: 'plaga')
      create(:plant, lote: lote, club: club, state: 'descartada', motivo_descarte: 'macho')
      create(:plant, lote: lote, club: club, state: 'vegetativo')
    end

    it 'cuenta sólo las descartadas' do
      expect(informe['plantas_descartadas']).to eq(3)
    end

    # El motivo es lo que hace accionable el informe: tres por plaga es un problema de sala;
    # tres machos es un problema de semilla.
    it 'las agrupa por motivo' do
      expect(informe['plantas_por_motivo']).to include('Plaga' => 2, 'Macho' => 1)
    end
  end

  describe 'producto perdido' do
    let(:stock) { create(:stock, club: club, sede: sede, lote: lote, cantidad: 500) }

    it 'suma la merma declarada' do
      stock.stock_movimientos.create!(tipo: 'merma', gramos: -50, usuario: admin)

      expect(informe['merma_g']).to eq(50.0)
    end

    # Un ajuste en menos es producto que ya no está, aunque se haya cargado como corrección.
    it 'suma los ajustes en menos, y NO los que suman' do
      stock.stock_movimientos.create!(tipo: 'ajuste', gramos: -20, usuario: admin)
      stock.stock_movimientos.create!(tipo: 'ajuste', gramos: 15, usuario: admin)

      expect(informe['ajustes_negativos_g']).to eq(20.0)
    end

    it 'una dispensación NO es una pérdida' do
      stock.stock_movimientos.create!(tipo: 'dispensacion', gramos: -30, usuario: admin)

      expect(informe['total_gramos']).to eq(0.0)
    end
  end

  describe 'stock vencido' do
    it 'lo cuenta aparte: todavía no es pérdida, pero lo va a ser' do
      create(:stock, club: club, sede: sede, lote: lote, cantidad: 80,
                     estado: 'asignado', fecha_vencimiento_est: Time.zone.today - 1)

      datos = informe
      expect(datos['stock_vencido_g']).to eq(80.0)
      expect(datos['stock_vencido_items']).to eq(1)
      # No entra en el total de perdido: sigue estando.
      expect(datos['total_gramos']).to eq(0.0)
    end

    it 'lo que no venció no aparece' do
      create(:stock, club: club, sede: sede, lote: lote, cantidad: 80,
                     estado: 'asignado', fecha_vencimiento_est: Time.zone.today + 30)

      expect(informe['stock_vencido_g']).to eq(0.0)
    end
  end

  it 'dice de qué habla' do
    expect(informe['resena']).to match(/qué se perdió/i)
  end
end
