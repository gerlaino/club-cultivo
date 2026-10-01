require 'rails_helper'

# AC (1-oct-2026): el diagnóstico encuentra lo que pudieron dejar mal los agujeros del pesaje ya
# cerrados, sin tocar nada; sólo destraba (a pedido) las plantas trabadas.
RSpec.describe Manicura::Diagnostico do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'vegetativo') }
  let(:frasco) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 0) }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }
  before { lote.update_columns(estado: 'en_manicura', sala_id: nil) }

  def jornada!(estado: 'confirmado', peso: 10, plantas: [])
    j = lote.pesajes_manicura.create!(manicurador: admin, club: club, fecha_pesaje: Time.zone.today, estado: estado,
                                      peso_confirmado_g: (peso if estado == 'confirmado'), stock: (frasco if estado == 'confirmado'))
    plantas.each { |p| j.pesadas_plantas.create!(plant: p, peso_seco_g: peso / plantas.size.to_f) }
    j
  end
  def diag = described_class.new(club_ids: [club.id]).call

  it 'sin problemas, no hay nada para revisar' do
    p = create(:plant, lote: lote, state: 'secado', peso_seco: 10)
    jornada!(plantas: [p])
    expect(diag).to be_vacio
  end

  it 'una planta en dos jornadas confirmadas: lo dice con los gramos de más' do
    p = create(:plant, lote: lote, state: 'secado', peso_seco: 10)
    jornada!(plantas: [p])
    jornada!(plantas: [p])
    expect(diag.doble_pesada).to contain_exactly(include(plant_id: p.id, gramos_de_mas: 10.0))
  end

  it 'una planta con peso y sin pesada en un lote en manicura está trabada; se destraba a pedido' do
    p = create(:plant, lote: lote, state: 'secado', peso_seco: 10)
    d = described_class.new(club_ids: [club.id])
    expect(d.call.trabadas).to contain_exactly(include(plant_id: p.id))
    expect(d.corregir_trabadas!).to eq(1)
    expect(p.reload.peso_seco).to be_nil
  end

  it 'un lote cerrado cuyo rendimiento no es la suma de sus pesajes' do
    jornada!(peso: 30)
    lote.update_columns(estado: 'curado', rendimiento_real_g: 25)
    expect(diag.rendimiento).to contain_exactly(include(lote: lote.codigo, rendimiento: 25.0, suma_pesajes: 30.0))
  end

  it 'un frasco agotado con producto' do
    jornada!
    frasco.update_columns(estado: 'agotado', cantidad: 10)
    expect(diag.agotado_con_peso).to contain_exactly(include(stock_id: frasco.id))
  end

  it 'reabre a pedido los frascos agotados con producto, y su lote finalizado vuelve a curado' do
    frasco.update_columns(estado: 'agotado', cantidad: 10, sede_id: nil)
    lote.update_columns(estado: 'finalizado')
    create(:user, :admin, club: club) # autor del evento
    d = described_class.new(club_ids: [club.id])
    expect(d.corregir_agotados!).to eq(1)
    expect(frasco.reload.estado).to eq('pendiente_asignacion')
    expect(lote.reload.estado).to eq('curado')
    expect(d.call.agotado_con_peso).to be_empty
  end

  it 'sólo mira la organización pedida' do
    create(:plant, lote: lote, state: 'secado', peso_seco: 10)
    expect(described_class.new(club_ids: [club.id + 999]).call.trabadas).to be_empty
    expect(diag.trabadas.size).to eq(1)
  end
end
