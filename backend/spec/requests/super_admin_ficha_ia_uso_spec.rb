require 'rails_helper'

# AC: en la ficha de la organización se ve cuánta IA consumió este mes, para poder fijar el
# tope mirando contra qué.
#
# Se medía desde el 11-ago (`ia_llamadas` + `Ia::Uso`) y no se exponía en ningún endpoint: el
# dato existía y nadie podía verlo.
#
# El detalle que hace falta probar: el super_admin NO tiene tenant fijado —no opera ninguna
# organización— y `IaLlamada` es tenant con `require_tenant=true`. Sin envolver la consulta en
# `with_tenant`, la ficha ENTERA revienta con NoTenantSet, no sólo este dato.
RSpec.describe 'SuperAdmin: consumo de IA en la ficha', type: :request do
  include AuthHelpers

  let(:club)        { create(:club, features: Club::FEATURES_POR_DEFECTO.merge('ia' => true)) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:super_admin) { create(:user, :super_admin, club: nil) }

  def ficha
    get "/api/super_admin/clubs/#{club.id}"
    expect(response).to have_http_status(:ok), response.body
    JSON.parse(response.body)
  end

  before do
    ActsAsTenant.with_tenant(club) do
      Ia::Uso.registrar(club: club, user: admin, funcion: :asistente_parsear,
                        modelo: 'claude-sonnet-4-6', tokens: { input: 1_000, output: 500 })
      Ia::Uso.registrar(club: club, user: admin, funcion: :analisis_lote,
                        modelo: 'claude-sonnet-4-6', tokens: { input: 2_000, output: 800 })
    end
    sign_in_as(super_admin)
  end

  it 'informa lo consumido en el mes y contra qué tope' do
    uso = ficha['ia_uso']

    expect(uso['llamadas']).to eq(2)
    expect(uso['tope']).to eq(club.ia_limite_mes)
    expect(uso['costo_usd']).to be > 0
  end

  it 'lo abre por función, que es lo que dice de dónde sale el gasto' do
    expect(ficha.dig('ia_uso', 'por_funcion')).to include('asistente_parsear' => 1,
                                                          'analisis_lote' => 1)
  end

  # El chivato del caché de prompt: si queda en 0 con el asistente en uso, algo rompió el
  # prefijo fijo y se está pagando 10× por los mismos tokens.
  it 'informa el hit ratio del caché' do
    expect(ficha.dig('ia_uso', 'cache_hit')).not_to be_nil
  end

  context 'una organización sin el add-on de IA' do
    let(:club) { create(:club, features: Club::FEATURES_POR_DEFECTO.dup) }

    it 'no calcula nada: son seis sumas que no le sirven a nadie' do
      expect(ficha['ia_uso']).to be_nil
    end

    it 'y la ficha sigue abriendo igual' do
      expect(ficha['id']).to eq(club.id)
    end
  end
end
