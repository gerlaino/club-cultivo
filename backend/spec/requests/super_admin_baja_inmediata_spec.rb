require 'rails_helper'

# AC: el super admin puede cortar un módulo AHORA, más allá de la fecha del período.
#
# La baja programada es lo correcto para una baja comercial —la organización pagó el mes— pero no
# sirve para lo demás: una organización que se va, una prueba que hay que revertir, un módulo
# prendido por error. Sin esto el único camino era esperar a fin de mes o tocar la base a mano.
RSpec.describe 'Baja inmediata de un módulo', type: :request do
  include AuthHelpers

  before { travel_to(Date.new(2026, 8, 10)) }
  after  { travel_back }

  let(:club) do
    create(:club, features: { 'cultivo' => true, 'produccion_dispensa' => true, 'delivery' => true })
  end
  let(:super_admin) { create(:user, :super_admin, club: nil) }

  before { sign_in_as(super_admin) }

  def apagar(inmediato: false)
    patch "/api/super_admin/clubs/#{club.id}",
          params: { club: { features: { 'delivery' => false } }, corte_inmediato: inmediato }.compact,
          as: :json
  end

  it 'con el corte inmediato, el módulo deja de estar disponible en el acto' do
    apagar(inmediato: true)

    expect(response).to have_http_status(:ok)
    expect(club.reload.feature?(:delivery)).to be(false)
  end

  it 'y no deja una baja pendiente que después diga "sigue andando hasta…"' do
    apagar(inmediato: true)

    expect(club.reload.baja_programada?('delivery')).to be(false)
    expect(club.features['delivery']).not_to be(true)
  end

  it 'la respuesta lo informa como inmediata, para que el panel no muestre una fecha futura' do
    apagar(inmediato: true)

    baja = JSON.parse(response.body)['bajas_programadas'].first
    expect(baja['inmediata']).to be(true)
    expect(baja['hasta']).to eq('2026-08-10')
  end

  # Nunca por defecto: cortar un módulo que la organización ya pagó es cobrarle el mes y no
  # prestárselo.
  it 'sin pedirlo, sigue siendo una baja programada a fin de mes' do
    apagar

    expect(club.reload.feature?(:delivery)).to be(true)
    expect(club.baja_programada_para('delivery')).to eq(Date.new(2026, 8, 31))
  end

  it 'también corta una SUITE entera, no sólo un add-on' do
    patch "/api/super_admin/clubs/#{club.id}",
          params: { club: { features: { 'cultivo' => false } }, corte_inmediato: true }, as: :json

    expect(club.reload.suite?('cultivo')).to be(false)
  end
end
