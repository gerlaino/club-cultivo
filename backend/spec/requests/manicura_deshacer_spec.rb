require 'rails_helper'

# AC (Germán, 30-oct-2026): el admin que pesa por QR tiene que poder «deshacer» si escaneó la planta
# equivocada o tipeó mal el peso, «mientras no haya pasado nada con ese frasco». Se anula como si no
# hubiera existido: el frasco vuelve a lo que tenía (el nuevo desaparece), la planta queda sin pesar y,
# si era la última, el lote vuelve a manicura. Si el frasco ya se usó, o pasó el rato, no: se corrige
# desde el frasco.
RSpec.describe 'Manicura: deshacer el pesaje directo del admin', type: :request do
  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'vegetativo', plants_count: 2) }
  let!(:p1)   { create(:plant, lote: lote, state: 'secado', nombre: 'P1') }
  let!(:p2)   { create(:plant, lote: lote, state: 'secado', nombre: 'P2') }

  before do
    ActsAsTenant.with_tenant(club) { lote.update_columns(estado: 'en_manicura', sala_id: nil, sede_id: sede.id, manicurador_id: admin.id) }
    sign_in_as(admin)
  end

  def json = JSON.parse(response.body)
  def t(&) = ActsAsTenant.with_tenant(club, &)
  def directo(params) = post("/lotes/#{lote.id}/pesajes_manicura/registrar_directo", params: params, headers: auth_headers, as: :json)
  def deshacer(id) = post("/lotes/#{lote.id}/pesajes_manicura/#{id}/deshacer", headers: auth_headers, as: :json)
  def frasco_viejo = t { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 5, cantidad_inicial: 5, calidad: 'altos') }

  it 'a un frasco que ya existía: el frasco vuelve a lo que tenía y la planta queda sin pesar' do
    viejo = frasco_viejo
    directo(pesos: [{ plant_id: p1.id, peso_seco_g: 340, peso_humedo_g: 400 }], stock_id: viejo.id)
    expect(response).to have_http_status(:created), response.body
    expect(viejo.reload.cantidad.to_f).to eq(345.0)

    deshacer(json['pesaje_id'])
    expect(response).to have_http_status(:ok), response.body
    expect(viejo.reload.attributes.values_at('cantidad', 'cantidad_inicial').map(&:to_f)).to eq([5.0, 5.0])
    expect(t { viejo.stock_movimientos.where(tipo: 'produccion').count }).to eq(0)
    expect(t { p1.reload.attributes.values_at('peso_seco', 'peso_humedo') }).to eq([nil, nil])
    expect(t { PesadaPlanta.where(plant_id: p1.id).count }).to eq(0)
    expect(t { lote.pesajes_manicura.count }).to eq(0)

    # Se puede volver a pesar bien.
    directo(pesos: [{ plant_id: p1.id, peso_seco_g: 34 }], stock_id: viejo.id)
    expect(response).to have_http_status(:created), response.body
    expect(viejo.reload.cantidad.to_f).to eq(39.0)
  end

  it 'repartido en uno existente y uno nuevo: el nuevo desaparece y el existente vuelve' do
    viejo = frasco_viejo
    directo(pesos: [{ plant_id: p1.id, peso_seco_g: 30 }],
            destinos: [{ stock_id: viejo.id, gramos: 20 }, { gramos: 10, descripcion: 'Bajos', calidad: 'bajos' }])
    expect(response).to have_http_status(:created), response.body
    nuevo_id = json['stock_ids'].last
    expect(json['stock_ids']).to eq([viejo.id, nuevo_id]) # en el orden del reparto

    deshacer(json['pesaje_id'])
    expect(response).to have_http_status(:ok), response.body
    expect(viejo.reload.cantidad.to_f).to eq(5.0)
    expect(t { Stock.where(id: nuevo_id).exists? }).to be(false)
  end

  it 'si era la última planta, el lote vuelve de curado a manicura' do
    directo(pesos: [{ plant_id: p1.id, peso_seco_g: 30 }], calidad: 'altos')
    directo(pesos: [{ plant_id: p2.id, peso_seco_g: 25 }], calidad: 'medios')
    expect(json['lote_estado']).to eq('curado')

    deshacer(json['pesaje_id'])
    expect(response).to have_http_status(:ok), response.body
    expect(json['lote_estado']).to eq('en_manicura')
    l = t { lote.reload }
    expect([l.estado, l.manicurador_id, l.rendimiento_real_g]).to eq(['en_manicura', admin.id, nil])
    expect(t { l.lote_eventos.where(estado_anterior: 'curado', estado_nuevo: 'en_manicura').count }).to eq(1)
  end

  it 'si el frasco ya se usó después, no se deshace' do
    directo(pesos: [{ plant_id: p1.id, peso_seco_g: 30 }], calidad: 'altos')
    id = json['pesaje_id']
    frasco = t { Stock.find(json['stock_id']) }
    t { frasco.stock_movimientos.create!(tipo: 'merma', gramos: -2, usuario: admin) }

    deshacer(id)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json['error']).to include('ya se usó', 'Editar pesaje del lote')
    expect(t { PesajeManicura.find(id).estado }).to eq('confirmado')
  end

  it 'pasado el rato, no se deshace' do
    directo(pesos: [{ plant_id: p1.id, peso_seco_g: 30 }], calidad: 'altos')
    id = json['pesaje_id']
    travel(PesajeManicura::DESHACER_DURA + 1.minute) do
      deshacer(id)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('Pasaron más de 30 minutos')
    end
  end

  it 'otro admin no deshace lo que registró otro' do
    directo(pesos: [{ plant_id: p1.id, peso_seco_g: 30 }], calidad: 'altos')
    id = json['pesaje_id']
    delete '/api/users/sign_out'
    sign_in_as(create(:user, :admin, club: club))
    deshacer(id)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json['error']).to include('quien lo registró')
  end

  it 'un pesaje de la manicura (enviado y confirmado por el admin) no se deshace por acá' do
    mica = create(:user, :manicura, club: club)
    j = t { lote.pesajes_manicura.create!(manicurador: mica, club: club, fecha_pesaje: Time.zone.today) }
    t { j.pesadas_plantas.create!(plant: p1, peso_seco_g: 30) }
    post "/lotes/#{lote.id}/pesajes_manicura/#{j.id}/enviar", headers: auth_headers, as: :json
    post "/lotes/#{lote.id}/pesajes_manicura/#{j.id}/confirmar", params: { peso_confirmado_g: 30, calidad: 'altos' }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok), response.body

    deshacer(j.id)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'aislamiento: un pesaje de otra organización no se encuentra' do
    otro_club  = create(:club, features: { 'cultivo' => true })
    otro_admin = create(:user, :admin, club: otro_club)
    otro_lote  = ActsAsTenant.with_tenant(otro_club) { create(:lote, club: otro_club, estado: 'en_manicura') }
    ajeno = ActsAsTenant.with_tenant(otro_club) do
      otro_lote.pesajes_manicura.create!(manicurador: otro_admin, club: otro_club, fecha_pesaje: Time.zone.today)
    end
    post "/lotes/#{otro_lote.id}/pesajes_manicura/#{ajeno.id}/deshacer", headers: auth_headers, as: :json
    expect(response).to have_http_status(:not_found)
    expect(ActsAsTenant.with_tenant(otro_club) { PesajeManicura.exists?(ajeno.id) }).to be(true)
  end
end
