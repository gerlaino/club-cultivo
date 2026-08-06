require 'rails_helper'

# AC: el dispensador tiene que poder asignar un envío. Necesita la lista de a quién
# asignárselo, y GET /usuarios es sólo de admin — el modal pedía esa lista, se comía el
# 403 y mostraba "no hay usuarios delivery disponibles" cuando sí los había.
RSpec.describe 'GET /dispensaciones/entregadores', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club, first_name: 'Ana', last_name: 'Gómez') }
  let(:dispensador) { create(:user, :dispensador, club: club) }

  def nombres = JSON.parse(response.body)['data'].map { |u| u['nombre'] }

  it 'el dispensador ve a los repartidores del club' do
    create(:user, :delivery, club: club, first_name: 'Beto', last_name: 'Ruiz')
    sign_in_as(dispensador)

    get '/api/dispensaciones/entregadores'

    expect(response).to have_http_status(:ok)
    expect(nombres).to include('Beto Ruiz')
  end

  # El club chico no tiene a nadie con rol delivery: entrega el admin o el supervisor.
  it 'incluye admins y supervisores, no sólo el rol delivery' do
    create(:user, :supervisor, club: club, first_name: 'Caro', last_name: 'Paz')
    admin
    sign_in_as(dispensador)

    get '/api/dispensaciones/entregadores'

    expect(nombres).to include('Ana Gómez', 'Caro Paz')
  end

  it 'no expone gente de otro club' do
    otro = create(:club)
    create(:user, :delivery, club: otro, first_name: 'Ajeno', last_name: 'Ajeno')
    create(:user, :delivery, club: club, first_name: 'Propio', last_name: 'Propio')
    sign_in_as(dispensador)

    get '/api/dispensaciones/entregadores'

    expect(nombres).to include('Propio Propio')
    expect(nombres).not_to include('Ajeno Ajeno')
  end

  # La lista es para asignar un envío, no un directorio del club: sólo id, rol y nombre.
  it 'no filtra el email ni otros datos de los usuarios' do
    create(:user, :delivery, club: club)
    sign_in_as(dispensador)

    get '/api/dispensaciones/entregadores'

    expect(JSON.parse(response.body)['data'].first.keys).to match_array(%w[id role nombre])
  end

  it 'el cultivador no tiene nada que hacer acá' do
    sign_in_as(create(:user, :cultivador, club: club))

    get '/api/dispensaciones/entregadores'

    expect(response).to have_http_status(:forbidden)
  end
end
