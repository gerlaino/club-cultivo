require 'rails_helper'

# AC (Germán, 20-oct-2026): el código de un lote no se repite dentro de una organización, ni
# siquiera por lo que escribe sin validar (así quedaron repetidos en el Club Modelo). Otra
# organización sí puede usar el mismo código, y el de un lote eliminado se puede volver a usar.
RSpec.describe 'Código de lote único por organización', type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { ActsAsTenant.with_tenant(club) { create(:sala, club: club, created_by: admin) } }
  let!(:primero) { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: sala, codigo: 'L-26-001') } }
  let(:segundo)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: sala, codigo: 'L-26-002') } }

  it 'la base lo impide aunque se escriba sin validar' do
    expect { segundo.update_columns(codigo: 'L-26-001') }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'otra organización puede tener el mismo código' do
    otro = create(:club)
    otro_admin = create(:user, :admin, club: otro)
    expect {
      ActsAsTenant.with_tenant(otro) { create(:lote, club: otro, sala: create(:sala, club: otro, created_by: otro_admin), codigo: 'L-26-001') }
    }.not_to raise_error
  end

  it 'el código de un lote eliminado se puede volver a usar' do
    primero.update_columns(deleted_at: Time.current)
    expect { segundo.update_columns(codigo: 'L-26-001') }.not_to raise_error
  end
end
