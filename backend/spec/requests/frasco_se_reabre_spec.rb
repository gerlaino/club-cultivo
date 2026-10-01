require 'rails_helper'

# AC (Germán, 1-oct-2026): un frasco vacío (agotado) al que le VUELVE producto deja de estar
# agotado —si no, la lista de stock lo esconde— y su lote, si se había finalizado, vuelve a
# curado. Pasa al anular una dispensa cuyo producto vuelve y al editar una dispensa para menos.
# Lo que se descarta no vuelve: el frasco sigue cerrado.
RSpec.describe 'Un frasco vacío al que le vuelve producto', type: :request do
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

  # Se dispensa todo: el frasco queda agotado y el lote (en curado) se finaliza.
  let!(:dispensa) do
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: frasco.id, cantidad: 10, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today.to_s } },
         headers: auth_headers, as: :json
    Dispensacion.last
  end

  it 'arranca vacío y con el lote finalizado' do
    expect(frasco.reload.estado).to eq('agotado')
    expect(t { lote.reload.estado }).to eq('finalizado')
  end

  it 'anular la dispensa con el producto que vuelve: el frasco se reabre y el lote vuelve a curado' do
    r = t { Dispensaciones::Cancelar.call(dispensacion: dispensa, usuario: admin, motivo: 'error_carga', nota: 'no se entregó') }
    expect(r).to be_ok
    expect([frasco.reload.cantidad.to_f, frasco.estado]).to eq([10.0, 'asignado'])
    expect(t { lote.reload.estado }).to eq('curado')
    get '/stocks', headers: auth_headers
    ids = (json.is_a?(Hash) ? (json['data'] || json['stocks']) : json).map { |s| s['id'] }
    expect(ids).to include(frasco.id)
  end

  it 'editarla para menos: al frasco le queda producto, se reabre, y el lote sin idas y vueltas' do
    patch "/dispensaciones/#{dispensa.id}", params: { dispensacion: { cantidad: 6, aporte_socio_ars: 600 } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect([frasco.reload.cantidad.to_f, frasco.estado]).to eq([4.0, 'asignado'])
    expect(t { lote.reload.estado }).to eq('curado')
  end

  it 'editarla sin cambiar la cantidad no reabre nada ni agrega eventos' do
    eventos = t { lote.lote_eventos.count }
    patch "/dispensaciones/#{dispensa.id}", params: { dispensacion: { cantidad: 10, aporte_socio_ars: 1500 } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(frasco.reload.estado).to eq('agotado')
    expect(t { lote.reload.estado }).to eq('finalizado')
    expect(t { lote.lote_eventos.count }).to eq(eventos)
  end

  it 'lo que se descarta no vuelve: el frasco sigue cerrado y el lote finalizado' do
    r = t { Dispensaciones::Cancelar.call(dispensacion: dispensa, usuario: admin, motivo: 'producto_defectuoso', nota: 'roto') }
    expect(r).to be_ok, r.error.to_s
    expect([frasco.reload.cantidad.to_f, frasco.estado]).to eq([0.0, 'agotado'])
    expect(t { lote.reload.estado }).to eq('finalizado')
  end
end
