require 'rails_helper'

# AC (Germán, 27-oct-2026): admin Y supervisor pesan aunque el lote esté asignado a otra manicura,
# por las tres puertas (QR, carga conjunta, registro directo). Lo que ella ya pesó queda en SU
# jornada. El admin puede «mandar a confirmar» la jornada abierta de ella. Otra manicura sigue sin
# poder pesar un lote que no es suyo.
RSpec.describe 'Admin y supervisor pesan un lote asignado a una manicura', type: :request do
  let(:club)       { create(:club) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:supervisor) { create(:user, club: club, role: 'supervisor') }
  let(:ella)       { create(:user, :manicura, club: club) }
  let(:otra)       { create(:user, :manicura, club: club) }
  let(:sede)       { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)       { create(:sala, sede: sede, club: club) }
  let(:lote)       { create(:lote, club: club, sala: sala, estado: 'en_manicura', manicurador: ella) }
  let!(:plantas)   { 3.times.map { create(:plant, lote: lote, club: club, state: 'cosechado') } }

  def json = JSON.parse(response.body)

  # Ella pesa la primera planta por QR: queda en su jornada abierta.
  def ella_pesa_la_primera!
    sign_in_as(ella)
    post "/api/plants/#{plantas.first.id}/registrar_peso", params: { peso_seco_g: 40 }, as: :json
    expect(response).to have_http_status(:ok), response.body
    delete '/api/users/sign_out'
    lote.pesajes_manicura.borradores.find_by!(manicurador_id: ella.id)
  end

  [:admin, :supervisor].each do |rol|
    context "como #{rol}" do
      before { sign_in_as(send(rol)) }

      it 'pesa por QR una planta del lote de ella, en una jornada a su nombre' do
        post "/api/plants/#{plantas.last.id}/registrar_peso", params: { peso_seco_g: 30 }, as: :json

        expect(response).to have_http_status(:ok), response.body
        pp = PesadaPlanta.find_by!(plant_id: plantas.last.id)
        expect(pp.pesaje_manicura.manicurador_id).to eq(send(rol).id)
      end

      it 'registra directo en el lote de ella y queda confirmado' do
        post "/api/lotes/#{lote.id}/pesajes_manicura/registrar_directo",
             params: { calidad: 'altos', resto: { peso_total_g: 90 } }, as: :json

        expect(response).to have_http_status(:created), response.body
        expect(lote.pesajes_manicura.confirmados.where(manicurador_id: send(rol).id)).to exist
      end
    end
  end

  it 'lo que ella ya pesó queda en SU jornada: el resto del admin reparte sólo entre las otras' do
    jornada_de_ella = ella_pesa_la_primera!
    sign_in_as(admin)

    post "/api/lotes/#{lote.id}/pesajes_manicura/registrar_directo",
         params: { calidad: 'altos', resto: { peso_total_g: 100 } }, as: :json

    expect(response).to have_http_status(:created), response.body
    expect(jornada_de_ella.reload.pesadas_plantas.pluck(:plant_id)).to eq([plantas.first.id])
    expect(plantas.first.reload.peso_seco.to_f).to eq(40.0)
    expect(plantas.last(2).map { |p| p.reload.peso_seco.to_f }).to all(eq(50.0))
    # Ella todavía no confirmó: el lote no cierra la manicura.
    expect(lote.reload.estado).to eq('en_manicura')
  end

  it 'el admin no puede pesar una planta que ya está en la jornada abierta de ella' do
    ella_pesa_la_primera!
    sign_in_as(admin)

    post "/api/plants/#{plantas.first.id}/registrar_peso", params: { peso_seco_g: 99 }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(plantas.first.reload.peso_seco.to_f).to eq(40.0)
  end

  describe 'otra manicura' do
    before { sign_in_as(otra) }

    # Ni la encuentra: el lote de otra no está a su alcance (404), y si lo estuviera el candado
    # (`Lote#pesa_manicura?`) daría 403. Lo que importa: no se pesa.
    it 'sigue sin poder pesar el lote de ella por QR' do
      post "/api/plants/#{plantas.first.id}/registrar_peso", params: { peso_seco_g: 10 }, as: :json
      expect(response.status).to be_in([403, 404])
      expect(plantas.first.reload.peso_seco).to be_blank
    end

    it 'sigue sin poder hacer la carga conjunta' do
      post "/api/lotes/#{lote.id}/pesajes_manicura", params: { peso_total_g: 10 }, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'no puede mandar a confirmar la jornada de ella' do
      delete '/api/users/sign_out'
      jornada = ella_pesa_la_primera!
      sign_in_as(otra)

      post "/api/lotes/#{lote.id}/pesajes_manicura/#{jornada.id}/enviar", as: :json

      expect(response).to have_http_status(:forbidden)
      expect(jornada.reload.estado).to eq('borrador')
    end
  end

  describe 'mandar a confirmar la jornada abierta de ella' do
    it 'el admin la ve entre las abiertas y la manda: pasa a «Para confirmar» y sigue siendo de ella' do
      jornada = ella_pesa_la_primera!
      sign_in_as(admin)

      get '/api/pesajes_manicura', params: { abiertas: 1 }
      expect(response).to have_http_status(:ok)
      expect(json.map { |p| p['id'] }).to eq([jornada.id])
      expect(json.first).to include('manicurador_id' => ella.id, 'plantas_registradas' => 1)

      post "/api/lotes/#{lote.id}/pesajes_manicura/#{jornada.id}/enviar", as: :json
      expect(response).to have_http_status(:ok), response.body
      expect(jornada.reload).to have_attributes(estado: 'enviado', manicurador_id: ella.id)

      get '/api/pesajes_manicura'
      expect(json.map { |p| p['id'] }).to include(jornada.id)
    end

    it 'sin «abiertas» la lista sigue siendo sólo lo enviado' do
      ella_pesa_la_primera!
      sign_in_as(admin)

      get '/api/pesajes_manicura'
      expect(json).to eq([])
    end

    it 'no muestra las jornadas abiertas de otra organización' do
      ella_pesa_la_primera!
      otro_club  = create(:club)
      otro_admin = create(:user, :admin, club: otro_club)
      sign_in_as(otro_admin)

      get '/api/pesajes_manicura', params: { abiertas: 1 }
      expect(response).to have_http_status(:ok)
      expect(json).to eq([])
    end
  end
end
