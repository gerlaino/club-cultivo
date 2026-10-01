require 'rails_helper'

# AC (Germán, 1-oct-2026): «al dispensar lo último de un frasco (y que no haya en depósito ni
# nada), en lugar de finalizar directo, un cartel que pregunta: ¿se dispensa lo último y se
# cierra el frasco?». Si se cierra: como siempre (y el lote se finaliza si era el último). Si no:
# queda ABIERTO y vacío —para rellenarlo con otra jornada— hasta que el admin lo cierra.
RSpec.describe 'Frasco vacío: cerrarlo o dejarlo abierto', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:frasco)  { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 10, precio_sugerido_ars: 100) }

  before do
    ActsAsTenant.with_tenant(club) { lote.update_columns(estado: 'curado', sala_id: nil, sede_id: sede.id) }
    sign_in_as(admin)
  end

  def t(&) = ActsAsTenant.with_tenant(club, &)
  def json = JSON.parse(response.body)
  def dispensar(cantidad, extra = {})
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: frasco.id, cantidad: cantidad, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today.to_s }.merge(extra) },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:created), response.body
  end

  it 'sin elegir nada (reservas, API), lo último cierra el frasco y el lote como siempre' do
    dispensar(10)
    expect(frasco.reload.estado).to eq('agotado')
    expect(t { lote.reload.estado }).to eq('finalizado')
  end

  it '«dejarlo abierto»: queda vacío y abierto, y el lote espera' do
    dispensar(10, dejar_abiertos: [frasco.id])
    expect([frasco.reload.cantidad.to_f, frasco.estado]).to eq([0.0, 'asignado'])
    expect(t { lote.reload.estado }).to eq('curado')
  end

  it 'una dispensa que no se lleva lo último no cierra nada, se pida o no' do
    dispensar(4, dejar_abiertos: [])
    expect([frasco.reload.cantidad.to_f, frasco.estado]).to eq([6.0, 'asignado'])
  end

  it 'el admin lo cierra sin motivo (está vacío) y con eso se finaliza el lote' do
    dispensar(10, dejar_abiertos: [frasco.id])
    post "/stocks/#{frasco.id}/descartar", headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(frasco.reload.estado).to eq('agotado')
    expect(t { lote.reload.estado }).to eq('finalizado')
    expect(t { frasco.stock_movimientos.where(tipo: %w[merma salida]).count }).to eq(0) # no sale nada
  end

  it 'Stock → «Vacíos» lista los frascos abiertos en cero (no los cerrados ni los que tienen producto)' do
    dispensar(10, dejar_abiertos: [frasco.id])
    otro = t { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 5) }
    get '/stocks', params: { vacios: 1 }, headers: auth_headers
    expect(json.map { |s| s['id'] }).to eq([frasco.id])
    expect(json.map { |s| s['id'] }).not_to include(otro.id)
  end

  it 'aislamiento: los vacíos de otra organización no aparecen' do
    otro_club = create(:club)
    ActsAsTenant.with_tenant(otro_club) do
      a = create(:user, :admin, club: otro_club)
      s2 = create(:sede, club: otro_club, created_by: a)
      Stock.create!(sede: s2, origen: 'compra_externa', proveedor: 'X', forma_producto: 'flor_seca', unidad: 'g', cantidad: 0)
    end
    get '/stocks', params: { vacios: 1 }, headers: auth_headers
    expect(json).to be_empty
  end

  it 'al confirmar un pesaje, el frasco abierto y vacío se ofrece para rellenar' do
    dispensar(10, dejar_abiertos: [frasco.id])
    get '/stocks', params: { lote_id: lote.id, incluir_vacios: 1 }, headers: auth_headers
    expect(json.map { |s| s['id'] }).to include(frasco.id)
  end
end
