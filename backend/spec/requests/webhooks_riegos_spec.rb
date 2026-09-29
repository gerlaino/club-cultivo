require 'rails_helper'

# El aparato que maneja la bomba avisa que regó y el riego queda en los lotes de su sala, firmado
# «Automático» (Germán, 29-sep-2026). Es un riego como cualquier otro: lo cuenta el historial y el
# resumen del ciclo.
RSpec.describe 'Webhooks::Riegos', type: :request do
  let(:club)        { create(:club) }
  before { club.update_columns(features: club.features.merge('iot' => true)) }
  let(:sala)        { create(:sala, club: club) }
  let(:dispositivo) { create(:dispositivo, sala: sala, nombre_amigable: 'ESP32 balcón') }
  let!(:token)      { dispositivo.regenerar_token! }
  let!(:lote)       { create(:lote, club: club, sala: sala, estado: 'vegetativo', origen: 'semilla', plants_count: 6) }

  def regar(ml: 600, ts: nil, tok: token)
    post '/webhooks/riegos',
         params: { dispositivo_id: dispositivo.id, ml_por_maceta: ml, timestamp: ts }.compact,
         headers: { 'X-Webhook-Token' => tok }
  end

  it 'deja un riego en el lote: litros = ml por maceta × plantas vivas, sin persona detrás' do
    create_list(:plant, 5, lote: lote)
    create(:plant, lote: lote, state: 'descartada')

    expect { regar(ml: 600) }.to change { lote.registros_ambientales.count }.by(1)
    expect(response).to have_http_status(:created)

    r = lote.registros_ambientales.last
    expect(r.tareas_realizadas).to eq(['riego'])
    expect(r.litros.to_f).to eq(3.0) # 5 vivas × 600 ml; la descartada no toma agua
    expect(r.user).to be_nil
    expect(r.fuente).to eq('dispositivo')
    expect(r.autor_nombre).to eq('Automático · ESP32 balcón')
  end

  it 'sin plantas cargadas usa la cantidad declarada del lote' do
    regar(ml: 500)
    expect(lote.registros_ambientales.last.litros.to_f).to eq(3.0) # 6 × 500 ml
  end

  it 'cuenta como riego en el resumen del ciclo' do
    regar
    expect(Lotes::ResumenCiclo.new(lote).call[:registros]).to include(riegos: 1)
  end

  it 'sólo riega los lotes en cultivo de SU sala: ni los que enraízan ni los de otra sala' do
    enraizando = create(:lote, club: club, sala: sala, estado: 'enraizado', origen: 'semilla')
    otra_sala  = create(:lote, club: club, sala: create(:sala, club: club), estado: 'vegetativo')

    regar
    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)['lotes'].map { |l| l['id'] }).to eq([lote.id])
    expect(enraizando.registros_ambientales.count).to eq(0)
    expect(otra_sala.registros_ambientales.count).to eq(0)
  end

  it 'no toca a otra organización' do
    otro_club = create(:club)
    ajeno = ActsAsTenant.with_tenant(otro_club) do
      create(:lote, club: otro_club, sala: create(:sala, club: otro_club), estado: 'vegetativo')
    end

    regar
    expect(ActsAsTenant.without_tenant { RegistroAmbiental.where(lote_id: ajeno.id).count }).to eq(0)
    expect(ActsAsTenant.without_tenant { RegistroAmbiental.where(club_id: otro_club.id).count }).to eq(0)
  end

  it 'un reintento del mismo riego no lo cuenta dos veces' do
    ts = 1.hour.ago.to_i
    regar(ts: ts)
    expect(response).to have_http_status(:created)

    expect { regar(ts: ts) }.not_to change(RegistroAmbiental, :count)
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['duplicado']).to be(true)
  end

  it 'sin lotes en cultivo en la sala responde 422 (el aparato no reintenta)' do
    lote.update_columns(estado: 'cosecha')
    expect { regar }.not_to change(RegistroAmbiental, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rechaza ml inválidos y un reloj en el futuro' do
    regar(ml: 0)
    expect(response).to have_http_status(:unprocessable_entity)
    regar(ml: 'mucho')
    expect(response).to have_http_status(:unprocessable_entity)
    regar(ts: 1.day.from_now.to_i)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it '401 con token inválido' do
    expect { regar(tok: 'otro') }.not_to change(RegistroAmbiental, :count)
    expect(response).to have_http_status(:unauthorized)
  end

  it '403 si la organización no tiene IoT' do
    club.update_columns(features: club.features.merge('iot' => false))
    expect { regar }.not_to change(RegistroAmbiental, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it 'un registro cargado por una persona sigue exigiendo autor' do
    r = RegistroAmbiental.new(lote: lote, club: club, registrado_en: Time.current)
    expect(r).not_to be_valid
    expect(r.errors[:user]).to be_present
  end
end
