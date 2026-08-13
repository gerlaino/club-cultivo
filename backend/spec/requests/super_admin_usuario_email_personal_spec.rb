require 'rails_helper'

# AC: un usuario creado desde el panel de plataforma tiene a dónde recibir los avisos.
#
# Son dos cosas distintas que el alta del panel confundía en un solo campo: `email` es el
# IDENTIFICADOR DE LOGIN (se usa `admin@laorganizacion.com` inventado, y está bien) y
# `email_personal` es el mail real de la persona — el que usa `User#email_notificacion`. El
# panel sólo aceptaba el primero, así que el alta nacía sin dirección real y los avisos salían
# a un buzón que no existe y rebotaban. La pantalla de usuarios del club ya los separaba.
RSpec.describe 'SuperAdmin: alta de usuario con mail real', type: :request do
  include AuthHelpers

  let(:club)        { create(:club) }
  let(:super_admin) { create(:user, :super_admin, club: nil) }

  before { sign_in_as(super_admin) }

  def crear(params)
    post '/api/super_admin/users', params: { user: { club_id: club.id, role: 'cultivador',
                                                     first_name: 'Ana', last_name: 'Pérez' }.merge(params) }
  end

  it 'guarda el mail personal, distinto del usuario de ingreso' do
    crear(email: 'cultivador@laorganizacion.com', email_personal: 'ana@gmail.com')

    expect(response).to have_http_status(:created), response.body
    user = User.find(JSON.parse(response.body)['id'])
    expect(user.email).to           eq('cultivador@laorganizacion.com')
    expect(user.email_personal).to  eq('ana@gmail.com')
    expect(user.email_notificacion).to eq('ana@gmail.com')
  end

  it 'lo devuelve en la ficha: si no se ve, nadie se entera de que falta' do
    crear(email: 'cultivador@laorganizacion.com', email_personal: 'ana@gmail.com')

    expect(JSON.parse(response.body)['email_personal']).to eq('ana@gmail.com')
  end

  it 'sigue siendo opcional: sin él, los avisos van al de ingreso como antes' do
    crear(email: 'cultivador@laorganizacion.com')

    expect(response).to have_http_status(:created), response.body
    expect(User.find(JSON.parse(response.body)['id']).email_notificacion)
      .to eq('cultivador@laorganizacion.com')
  end

  it 'también se puede corregir después, que es cuando se descubre el rebote' do
    crear(email: 'cultivador@laorganizacion.com')
    id = JSON.parse(response.body)['id']

    patch "/api/super_admin/users/#{id}", params: { user: { email_personal: 'ana@gmail.com' } }

    expect(response).to have_http_status(:ok), response.body
    expect(User.find(id).email_personal).to eq('ana@gmail.com')
  end
end
