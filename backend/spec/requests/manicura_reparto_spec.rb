require 'rails_helper'

# AC (Germán, 1-oct-2026): «vienen los pesajes, el admin confirma y crea dos frascos, uno de bajos
# y uno de copones, pone la cantidad de cada frasco y fin». Todo es del mismo lote: la trazabilidad
# de cada frasco nombra las mismas plantas y cada cuenta cierra.
RSpec.describe 'Manicura: repartir un pesaje en varios frascos', type: :request do
  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'vegetativo', plants_count: 2) }
  let!(:p1)   { create(:plant, lote: lote, state: 'secado', nombre: 'P1') }
  let!(:p2)   { create(:plant, lote: lote, state: 'secado', nombre: 'P2') }

  before do
    ActsAsTenant.with_tenant(club) { lote.update_columns(estado: 'en_manicura', sala_id: nil, sede_id: sede.id) }
    sign_in_as(admin)
  end

  def json = JSON.parse(response.body)
  def t(&) = ActsAsTenant.with_tenant(club, &)
  def jornada_enviada!(gramos = [60, 40])
    post "/plants/#{p1.id}/registrar_peso", params: { peso_seco_g: gramos[0] }, headers: auth_headers, as: :json
    post "/plants/#{p2.id}/registrar_peso", params: { peso_seco_g: gramos[1] }, headers: auth_headers, as: :json
    j = t { lote.pesajes_manicura.last }
    post "/lotes/#{lote.id}/pesajes_manicura/#{j.id}/enviar", headers: auth_headers, as: :json
    j
  end
  def confirmar(j, peso, destinos) =
    post("/lotes/#{lote.id}/pesajes_manicura/#{j.id}/confirmar", params: { calidad: 'altos', peso_confirmado_g: peso, destinos: destinos }, headers: auth_headers, as: :json)
  def frascos = t { Stock.where(lote_id: lote.id).order(:id).to_a }

  it 'copones y bajos en dos frascos nuevos, cada uno con lo suyo y su nombre' do
    j = jornada_enviada!
    confirmar(j, 100, [{ gramos: 70, descripcion: 'Copones', calidad: 'altos' }, { gramos: 30, descripcion: 'Bajos', calidad: 'bajos' }])
    expect(response).to have_http_status(:ok), response.body
    expect(frascos.map { |s| [s.descripcion, s.cantidad.to_f, s.cantidad_inicial.to_f] }).to eq([['Copones', 70.0, 70.0], ['Bajos', 30.0, 30.0]])
    expect(json['destinos'].map { |d| [d['descripcion'], d['gramos']] }).to eq([['Copones', 70.0], ['Bajos', 30.0]])
    l = t { lote.reload }
    expect([l.estado, l.rendimiento_real_g.to_f]).to eq(['curado', 100.0])
  end

  it 'uno existente y uno nuevo' do
    viejo = t { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 5) }
    j = jornada_enviada!
    confirmar(j, 100, [{ stock_id: viejo.id, gramos: 80 }, { gramos: 20, descripcion: 'Bajos', calidad: 'bajos' }])
    expect(response).to have_http_status(:ok), response.body
    expect(viejo.reload.cantidad.to_f).to eq(85.0)
    expect(frascos.last.cantidad.to_f).to eq(20.0)
  end

  it 'la trazabilidad de cada frasco nombra las plantas y cierra' do
    j = jornada_enviada!
    confirmar(j, 100, [{ gramos: 70, descripcion: 'Copones', calidad: 'altos' }, { gramos: 30, descripcion: 'Bajos', calidad: 'bajos' }])
    frascos.each do |f|
      tr = t { Stocks::Trazabilidad.new(stock: f).call }
      expect(tr[:totales]).to include(gramos_producidos: f.cantidad_inicial.to_f, sin_explicar_g: 0.0)
      expect(tr[:plantas].map { |p| p[:nombre] }).to contain_exactly('P1', 'P2')
    end
  end

  describe 'lo que no se acepta (y no toca nada)' do
    def nada_tocado(j)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(t { j.reload.estado }).to eq('enviado')
      expect(frascos).to be_empty
    end

    it 'un reparto que no suma el peso confirmado, y lo dice con números' do
      j = jornada_enviada!
      confirmar(j, 100, [{ gramos: 70, calidad: 'altos' }, { gramos: 20, calidad: 'altos' }])
      expect(json['error']).to include('suma 90.0 g', '100.0 g')
      nada_tocado(j)
    end

    it 'un frasco sin gramos' do
      j = jornada_enviada!
      confirmar(j, 100, [{ gramos: 100, calidad: 'altos' }, { gramos: 0, calidad: 'altos' }])
      nada_tocado(j)
    end

    it 'el mismo frasco dos veces' do
      viejo = t { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 5) }
      j = jornada_enviada!
      confirmar(j, 100, [{ stock_id: viejo.id, gramos: 50 }, { stock_id: viejo.id, gramos: 50 }])
      expect(response).to have_http_status(:unprocessable_entity)
      expect(viejo.reload.cantidad.to_f).to eq(5.0)
    end

    it 'un frasco de otro lote' do
      otro = t { Stock.create!(sede: sede, lote: create(:lote, club: club, sala: sala), origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 5) }
      j = jornada_enviada!
      confirmar(j, 100, [{ stock_id: otro.id, gramos: 50 }, { gramos: 50, calidad: 'altos' }])
      expect(response.status).to be_in([404, 422])
      expect(otro.reload.cantidad.to_f).to eq(5.0)
      expect(t { j.reload.estado }).to eq('enviado')
    end
  end

  describe 'reajustar un pesaje repartido' do
    def reajustar(j, peso, stock_id = nil)
      patch "/lotes/#{lote.id}/pesajes_manicura/#{j.id}/reajustar_peso", params: { peso_confirmado_g: peso, stock_id: stock_id }.compact,
                                                                         headers: auth_headers, as: :json
    end

    it 'pide qué frasco, y corrige ése, el total del pesaje y el rendimiento del lote' do
      j = jornada_enviada!
      confirmar(j, 100, [{ gramos: 70, descripcion: 'Copones', calidad: 'altos' }, { gramos: 30, descripcion: 'Bajos', calidad: 'bajos' }])
      bajos = frascos.last
      reajustar(j, 35)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('elegí cuál')
      reajustar(j, 35, bajos.id)
      expect(response).to have_http_status(:ok), response.body
      expect(bajos.reload.cantidad.to_f).to eq(35.0)
      expect(frascos.first.cantidad.to_f).to eq(70.0)
      expect(t { j.reload.peso_confirmado_g.to_f }).to eq(105.0)
      expect(t { lote.reload.rendimiento_real_g.to_f }).to eq(105.0)
    end

    it 'un pesaje viejo (sin destinos anotados) se sigue reajustando como siempre' do
      j = jornada_enviada!
      confirmar(j, 100, nil)
      t { j.reload.destinos.delete_all } # como quedaron los confirmados antes del 1-oct
      reajustar(j, 110)
      expect(response).to have_http_status(:ok), response.body
      expect(t { j.reload.stock.cantidad.to_f }).to eq(110.0)
      expect(t { j.destinos.pluck(:gramos).map(&:to_f) }).to eq([110.0])
    end
  end

  describe '«registrar directo» del admin (pesa y confirma en un paso), también repartido' do
    def directo(params) = post("/lotes/#{lote.id}/pesajes_manicura/registrar_directo", params: params, headers: auth_headers, as: :json)

    it 'pesa las plantas y reparte lo pesado en copones y bajos, con la sede elegida' do
      directo(pesos: [{ plant_id: p1.id, peso_seco_g: 60 }, { plant_id: p2.id, peso_seco_g: 40 }],
              destinos: [{ gramos: 75, descripcion: 'Copones', calidad: 'altos' }, { gramos: 25, descripcion: 'Bajos', calidad: 'bajos' }], sede_id: sede.id)
      expect(response).to have_http_status(:created), response.body
      expect(json['stock_ids'].size).to eq(2)
      expect(frascos.map { |f| [f.descripcion, f.cantidad.to_f, f.sede_id, f.estado] })
        .to eq([['Copones', 75.0, sede.id, 'asignado'], ['Bajos', 25.0, sede.id, 'asignado']])
      expect(t { lote.reload.estado }).to eq('curado')
    end

    it 'un reparto que no suma lo pesado no guarda nada (ni los pesos de las plantas)' do
      directo(pesos: [{ plant_id: p1.id, peso_seco_g: 60 }, { plant_id: p2.id, peso_seco_g: 40 }],
              destinos: [{ gramos: 70, calidad: 'altos' }, { gramos: 20, calidad: 'altos' }])
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('suma 90.0 g', '100.0 g')
      expect(frascos).to be_empty
      expect(t { p1.reload.peso_seco }).to be_nil
    end

    # AC (Germán, 30-oct-2026): «el admin, al registrar el pesaje, tiene que poder dividir esa
    # planta en uno o más frascos, existentes o nuevos». Es lo que manda «Registrar pesaje» de la
    # ficha del lote: las plantas elegidas con su peso conjunto (`resto.plant_ids`) y el destino.
    it 'una sola planta, repartida en un frasco existente y uno nuevo' do
      viejo = t { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 5) }
      directo(resto: { plant_ids: [p1.id], peso_total_g: 30 },
              destinos: [{ stock_id: viejo.id, gramos: 20 }, { gramos: 10, descripcion: 'Bajos', calidad: 'bajos' }])
      expect(response).to have_http_status(:created), response.body
      expect(viejo.reload.cantidad.to_f).to eq(25.0)
      expect(frascos.last.attributes.values_at('descripcion', 'calidad')).to eq(%w[Bajos bajos])
      expect(frascos.last.cantidad.to_f).to eq(10.0)
      expect(t { p1.reload.peso_seco.to_f }).to eq(30.0)
      expect(t { p2.reload.peso_seco }).to be_nil
      expect(t { lote.reload.estado }).to eq('en_manicura') # falta P2
    end

    it 'una sola planta a un frasco existente, sin reparto' do
      viejo = t { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 5) }
      directo(resto: { plant_ids: [p1.id], peso_total_g: 30 }, stock_id: viejo.id)
      expect(response).to have_http_status(:created), response.body
      expect(viejo.reload.cantidad.to_f).to eq(35.0)
      expect(frascos.size).to eq(1)
    end

    it 'sin reparto, como siempre: un solo frasco' do
      directo(pesos: [{ plant_id: p1.id, peso_seco_g: 60 }, { plant_id: p2.id, peso_seco_g: 40 }], calidad: 'altos')
      expect(response).to have_http_status(:created), response.body
      expect(frascos.map { |f| f.cantidad.to_f }).to eq([100.0])
    end
  end
end
