require 'rails_helper'
require 'rake'

# AC (1-oct-2026): los movimientos que ya quedaron con la fecha de la carga pasan a la fecha de su
# dispensa. En seco no escribe; con CONFIRMAR=1 sí; es idempotente y no toca otra cosa.
RSpec.describe 'rake stocks:fechar_movimientos_de_dispensa' do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'stocks:fechar_movimientos_de_dispensa' } }

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let(:stock)    { Stock.create!(club: club, sede: sede, origen: 'compra_externa', proveedor: 'X', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100) }
  let(:hace_40)  { Time.zone.today - 40 }

  def correr(confirmar:)
    ENV['CONFIRMAR'] = confirmar ? '1' : nil
    Rake::Task['stocks:fechar_movimientos_de_dispensa'].reenable
    expect { Rake::Task['stocks:fechar_movimientos_de_dispensa'].invoke }.to output.to_stdout
  ensure
    ENV.delete('CONFIRMAR')
  end

  # Como quedó con el código viejo: el movimiento con la fecha del día de la carga.
  let!(:dispensa) do
    ActsAsTenant.with_tenant(club) do
      d = Dispensacion.create!(paciente: paciente, user: admin, sede: sede, medio_pago: 'efectivo', fecha_dispensacion: hace_40,
                               items_attributes: [{ stock: stock, cantidad: 10 }])
      StockMovimiento.where(dispensacion_id: d.id).update_all(fecha: Time.zone.today)
      d
    end
  end
  let!(:merma) { ActsAsTenant.with_tenant(club) { stock.stock_movimientos.create!(tipo: 'merma', gramos: -1, usuario: admin, fecha: Time.zone.today) } }
  def fecha_mov = ActsAsTenant.with_tenant(club) { StockMovimiento.find_by(dispensacion_id: dispensa.id).fecha }

  it 'en seco no escribe' do
    correr(confirmar: false)
    expect(fecha_mov).to eq(Time.zone.today)
  end

  it 'con CONFIRMAR=1 pone la fecha de la dispensa, sin tocar otros movimientos, y repetirlo no cambia nada' do
    correr(confirmar: true)
    expect(fecha_mov).to eq(hace_40)
    expect(merma.reload.fecha).to eq(Time.zone.today)
    correr(confirmar: true)
    expect(fecha_mov).to eq(hace_40)
  end
end
