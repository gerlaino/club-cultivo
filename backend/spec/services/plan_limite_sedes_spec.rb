require 'rails_helper'

# El tope de sedes contaba sólo las ACTIVAS, así que desactivar una liberaba el cupo: una
# organización del plan Básico —una sola sede— podía tener las que quisiera creando, apagando y
# volviendo a prender. Es el mismo agujero que ya se había tapado en salas.
RSpec.describe 'Tope de sedes del plan', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, plan: 'basico') }
  let(:admin) { create(:user, :admin, club: club) }

  before { sign_in_as(admin) }

  def crear(nombre)
    post '/sedes', headers: auth_headers, as: :json,
         params: { sede: { nombre: nombre, tipo: 'produccion' } }
  end

  it 'el plan Básico deja crear una sola sede' do
    crear('Primera')
    expect(response).to have_http_status(:created)

    crear('Segunda')
    expect(response).to have_http_status(:payment_required)
  end

  it 'desactivar una sede NO libera el cupo' do
    crear('Primera')
    club.sedes.first.update!(activa: false)

    expect { crear('Segunda') }.not_to change { club.sedes.count }
    expect(response).to have_http_status(:payment_required)
  end

  it 'el uso que se le informa al super admin cuenta igual que el tope' do
    crear('Primera')
    club.sedes.first.update!(activa: false)

    expect(PlanEnforcer.new(club.reload).info[:uso][:sedes]).to eq(1)
  end

  it 'el plan Total no tiene tope' do
    club.update!(plan: 'total')

    3.times { |i| crear("Sede #{i}") }

    expect(club.sedes.count).to eq(3)
    expect(response).to have_http_status(:created)
  end
end
