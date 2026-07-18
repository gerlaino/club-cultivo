require 'rails_helper'

# Editar plants_count reconcilia las Plant reales (crea/quita), en vez de escribir un número
# suelto que driftea. Solo en cultivo pre-cosecha y sin borrar plantas con datos.
RSpec.describe 'PATCH /lotes/:id — reconciliación de plants_count', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club) }
  let(:sala)  { create(:sala, club: club, sede: sede, kind: 'vegetativo') }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'vegetativo', plants_count: 3) }

  before do
    create_list(:plant, 3, lote: lote, club: club, state: 'vegetativo')
    sign_in_as(admin)
  end

  def patch_pc(n)
    patch "/lotes/#{lote.id}", params: { lote: { plants_count: n } }, headers: auth_headers
  end

  it 'subir plants_count crea las plantas faltantes' do
    patch_pc(5)
    expect(response).to have_http_status(:ok)
    expect(lote.reload.plants.count).to eq(5)
    expect(lote.plants_count).to eq(5)
  end

  it 'bajar plants_count quita plantas vacías (soft-delete)' do
    patch_pc(1)
    expect(response).to have_http_status(:ok)
    expect(lote.reload.plants.count).to eq(1)
    expect(lote.plants_count).to eq(1)
  end

  it 'no borra plantas con datos: frena con error y no toca nada' do
    lote.plants.each { |p| p.update_column(:peso_seco, 10) } # tienen peso → no son candidatas
    patch_pc(1)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(lote.reload.plants.count).to eq(3)
  end
end
