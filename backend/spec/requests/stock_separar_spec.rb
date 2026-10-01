require 'rails_helper'

# AC (Germán, 1-oct-2026): «peso el lote entero, confirmo, se crea un frasco… ¿cómo divido los
# bajos de los copones de un frasco ya creado?». Cada frasco nuevo sale del original (misma sede,
# lote, genética) con su nombre, sus gramos y su precio; lo que no se separa queda en el original,
# que se puede renombrar. La trazabilidad no se corta y cada cuenta cierra. Lo que está sobre la
# mesa, reservado o apartado se queda en el original.
RSpec.describe 'POST /stocks/:id/separar', type: :request do
  let(:club)   { create(:club) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:sede)   { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)   { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)   { create(:lote, club: club, sala: sala) }
  let!(:frasco) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100,
                  precio_sugerido_ars: 150, costo_unitario_ars: 40, fecha_elaboracion: Date.new(2026, 9, 20))
  end

  before { sign_in_as(admin) }

  def json = JSON.parse(response.body)
  def t(&) = ActsAsTenant.with_tenant(club, &)
  def separar(params) = post("/stocks/#{frasco.id}/separar", params: params, headers: auth_headers, as: :json)

  it 'separa los bajos con su precio, y el original queda con el resto y renombrado' do
    separar(frascos: [{ descripcion: 'Bajos', gramos: 30, precio_sugerido_ars: 80 }], descripcion_origen: 'Copones')
    expect(response).to have_http_status(:created), response.body
    bajos = t { Stock.find(json['nuevos'].first['id']) }
    expect([bajos.descripcion, bajos.cantidad.to_f, bajos.precio_sugerido_ars.to_f, bajos.sede_id, bajos.lote_id, bajos.estado])
      .to eq(['Bajos', 30.0, 80.0, sede.id, lote.id, 'asignado'])
    expect(bajos.fecha_elaboracion).to eq(Date.new(2026, 9, 20))
    expect(bajos.costo_unitario_ars.to_f).to eq(40.0)
    expect([frasco.reload.descripcion, frasco.cantidad.to_f, frasco.cantidad_inicial.to_f]).to eq(['Copones', 70.0, 100.0])
  end

  it 'sin precio, el nuevo hereda el del original; y se puede separar en varios' do
    separar(frascos: [{ descripcion: 'Bajos', gramos: 20 }, { descripcion: 'Popcorn', gramos: 10, precio_sugerido_ars: 50 }])
    expect(response).to have_http_status(:created), response.body
    expect(json['nuevos'].map { |n| [n['descripcion'], n['cantidad'].to_f, n['precio_sugerido_ars'].to_f] })
      .to eq([['Bajos', 20.0, 150.0], ['Popcorn', 10.0, 50.0]])
    expect(frasco.reload.cantidad.to_f).to eq(70.0)
  end

  it 'la trazabilidad no se corta: el nuevo dice de dónde salió, el original a dónde siguió, y las dos cuentas cierran' do
    separar(frascos: [{ descripcion: 'Bajos', gramos: 30 }])
    bajos = t { Stock.find(json['nuevos'].first['id']) }
    tn = t { Stocks::Trazabilidad.new(stock: bajos).call }
    to = t { Stocks::Trazabilidad.new(stock: frasco.reload).call }
    expect(tn[:stock][:fraccionado_desde]).to include(numero: frasco.numero_lote_producto, gramos: 30.0)
    expect(tn[:totales]).to include(gramos_producidos: 30.0, sin_explicar_g: 0.0)
    expect(to[:siguio_en].map { |x| x[:numero] }).to eq([bajos.numero_lote_producto])
    expect(to[:totales][:sin_explicar_g]).to eq(0.0)
  end

  it 'no separa lo que está reservado o sobre la mesa, y dice cuánto se puede' do
    # 60 g suben a la mesa del mostrador: quedan 40 guardados y libres.
    t { Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'reposición', cambios: [{ stock_id: frasco.id, cantidad: 60 }]) }
    separar(frascos: [{ gramos: 50 }])
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json['error']).to include('hasta 40.0 g')
    expect(frasco.reload.cantidad.to_f).to eq(100.0)
  end

  describe 'lo que no se acepta (y no toca nada)' do
    after { expect(frasco.reload.cantidad.to_f).to eq(100.0) }

    it 'separar todo: algo tiene que quedar' do
      separar(frascos: [{ gramos: 60 }, { gramos: 40 }])
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('Algo tiene que quedar')
    end

    it 'un frasco sin cantidad' do
      separar(frascos: [{ descripcion: 'Bajos', gramos: 0 }])
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'sin frascos' do
      separar(frascos: [])
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  it 'un frasco cerrado no se separa' do
    t { frasco.update_columns(estado: 'agotado') }
    separar(frascos: [{ gramos: 10 }])
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'aislamiento: no se separa un frasco de otra organización' do
    otro = create(:club)
    ajeno = ActsAsTenant.with_tenant(otro) do
      a = create(:user, :admin, club: otro)
      Stock.create!(sede: create(:sede, club: otro, created_by: a), origen: 'compra_externa', proveedor: 'X', forma_producto: 'flor_seca', unidad: 'g', cantidad: 50)
    end
    post "/stocks/#{ajeno.id}/separar", params: { frascos: [{ gramos: 10 }] }, headers: auth_headers, as: :json
    expect(response.status).to be_in([403, 404])
    expect(ActsAsTenant.with_tenant(otro) { ajeno.reload.cantidad.to_f }).to eq(50.0)
  end

  it 'la ficha del frasco dice cuánto se puede separar' do
    get "/stocks/#{frasco.id}", headers: auth_headers
    expect(json['data']['separable']).to eq(100.0)
  end
end
