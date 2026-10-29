require 'rails_helper'

# AC (Javi, 15-oct-2026): «manicuro, mando a confirmar; si mientras el admin está armando los frascos
# confirmando el pesaje, manicura cambia el peso, y el admin confirma, se crea con los pesajes
# nuevos… no debería dejar: al abrir para confirmar se debería bloquear al manicura».
# Plan aprobado por Germán (16-oct): «En revisión por X» que bloquea reabrir y borrar; se libera al
# cerrar, al confirmar o a los 15 minutos; y confirmar se rechaza si el pesaje cambió.
RSpec.describe 'Pesaje de manicura · en revisión por el admin', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club, first_name: 'Germán') }
  let(:otro_adm) { create(:user, :admin, club: club, first_name: 'Javi') }
  let(:manicura) { create(:user, :manicura, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin, kind: 'manicura') }
  let(:lote)     { create(:lote, club: club, sala: sala, estado: 'en_manicura', manicurador: manicura) }
  let!(:pesaje) do
    ActsAsTenant.with_tenant(club) do
      PesajeManicura.create!(club: club, lote: lote, manicurador: manicura, fecha_pesaje: Time.zone.today).tap do |p|
        p.cargar_manual!(plantas: 3, peso: 120)
        p.enviar!
      end
    end
  end
  let(:base) { "/lotes/#{lote.id}/pesajes_manicura/#{pesaje.id}" }

  def como(user) = sign_in_as(user)
  def json = JSON.parse(response.body)

  def revisar_como(user)
    como(user)
    post "#{base}/revisar", headers: auth_headers
    json
  end

  def confirmar_como(user, version:)
    como(user)
    post "#{base}/confirmar", params: { calidad: 'altos', peso_confirmado_g: 120, version: version }, headers: auth_headers, as: :json
  end

  it 'mientras el admin lo revisa, la manicura no lo puede reabrir ni borrar, y ve quién lo tiene' do
    revisar_como(admin)
    expect(response).to have_http_status(:ok)

    como(manicura)
    post "#{base}/reabrir", headers: auth_headers
    expect(response).to have_http_status(:conflict)
    expect(json['error']).to include('Germán lo está revisando')

    delete base, headers: auth_headers
    expect(response).to have_http_status(:conflict)
    expect(pesaje.reload).to be_enviado

    get "/lotes/#{lote.id}/pesajes_manicura", headers: auth_headers
    fila = json.find { |p| p['id'] == pesaje.id }
    expect(fila).to include('en_revision' => true, 'revisando_por' => 'Germán')
  end

  it 'tampoco se puede devolver el lote a cosecha (borraría el pesaje que el admin está confirmando)' do
    revisar_como(admin)
    como(manicura)
    post "/lotes/#{lote.id}/devolver_manicura", params: { motivo: 'no se puede' }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json['error']).to include('Germán lo está revisando')
    expect(PesajeManicura.exists?(pesaje.id)).to be(true)
  end

  it 'la reabre el admin que lo revisa (es suyo), y eso lo libera' do
    revisar_como(admin)
    post "#{base}/reabrir", headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(pesaje.reload).to have_attributes(estado: 'borrador', revisando_por_id: nil)
  end

  it 'al cerrar el modal se libera y la manicura ya puede reabrir' do
    revisar_como(admin)
    delete "#{base}/revisar", headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(json['en_revision']).to be(false)

    como(manicura)
    post "#{base}/reabrir", headers: auth_headers
    expect(response).to have_http_status(:ok)
  end

  it 'sólo lo suelta quien lo tiene: cerrar el modal de otro admin no le saca el candado' do
    revisar_como(admin)
    como(otro_adm)
    delete "#{base}/revisar", headers: auth_headers
    expect(pesaje.reload.en_revision?).to be(true)
  end

  it 'a los 15 minutos se libera solo (un teléfono sin batería no lo traba para siempre)' do
    revisar_como(admin)
    travel 16.minutes do
      como(manicura)
      post "#{base}/reabrir", headers: auth_headers
      expect(response).to have_http_status(:ok)
    end
  end

  it 'otro admin no lo puede tomar ni confirmar mientras lo revisa el primero' do
    version = revisar_como(admin)['enviado_at']
    revisar_como(otro_adm)
    expect(response).to have_http_status(:conflict)
    expect(json['error']).to include('Germán')

    confirmar_como(otro_adm, version: version)
    expect(response).to have_http_status(:conflict)
    expect(pesaje.reload).to be_enviado
  end

  it 'confirmar con lo que vio: anda, suma el peso y libera la revisión' do
    version = revisar_como(admin)['enviado_at']
    confirmar_como(admin, version: version)
    expect(response).to have_http_status(:ok), response.body
    expect(pesaje.reload).to have_attributes(estado: 'confirmado', revisando_por_id: nil)
    expect(pesaje.stock.cantidad.to_f).to eq(120.0)
  end

  it 'si cambió mientras lo revisaba (se venció, la manicura reabrió, cambió el peso y reenvió), NO confirma' do
    version = revisar_como(admin)['enviado_at']
    travel 16.minutes do
      como(manicura)
      post "#{base}/reabrir", headers: auth_headers
      expect(response).to have_http_status(:ok)
      ActsAsTenant.with_tenant(club) { pesaje.reload.update!(peso_total_g: 200) }
      post "#{base}/enviar", headers: auth_headers
      expect(response).to have_http_status(:ok)

      confirmar_como(admin, version: version)
      expect(response).to have_http_status(:conflict)
      expect(json).to include('cambio' => true)
      expect(json['error']).to include('cambió mientras lo revisabas')
      expect(pesaje.reload).to be_enviado
      expect(Stock.where(lote_id: lote.id)).to be_empty
    end
  end

  it 'si la manicura lo reabrió (ya no está enviado), la confirmación lo dice en vez de un error genérico' do
    version = revisar_como(admin)['enviado_at']
    travel 16.minutes do
      como(manicura)
      post "#{base}/reabrir", headers: auth_headers
      confirmar_como(admin, version: version)
      expect(response).to have_http_status(:conflict)
      expect(json['error']).to include('reabrió')
    end
  end

  it 'la manicura no puede tomar la revisión' do
    revisar_como(manicura)
    expect(response).to have_http_status(:forbidden)
  end

  it 'aislamiento de tenant: un admin de otra organización no lo encuentra' do
    ajeno = create(:user, :admin, club: create(:club))
    como(ajeno)
    post "#{base}/revisar", headers: auth_headers
    expect(response.status).to be_in([403, 404])
    expect(pesaje.reload.revisando_por_id).to be_nil
  end
end
