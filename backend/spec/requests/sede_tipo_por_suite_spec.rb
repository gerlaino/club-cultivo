require 'rails_helper'

# El tipo de sede tiene que existir en la operación de la organización: una que sólo contrató
# Cultivo no atiende pacientes, y una de sólo Producción y dispensa no tiene salas.
RSpec.describe 'Tipo de sede según las suites', type: :request do
  include AuthHelpers

  def club_con(*suites)
    features = Club::FEATURES_POR_DEFECTO.merge(
      'cultivo' => false, 'produccion_dispensa' => false
    )
    suites.each { |s| features[s.to_s] = true }
    create(:club, features: features)
  end

  describe 'una organización de sólo Cultivo' do
    let(:club)  { club_con(:cultivo) }
    let(:admin) { create(:user, :admin, club: club) }
    before { sign_in_as(admin) }

    it 'puede crear una sede de producción' do
      post '/sedes', headers: auth_headers, as: :json,
           params: { sede: { nombre: 'Finca Norte', tipo: 'produccion' } }

      expect(response).to have_http_status(:created)
    end

    it 'NO puede crear una social ni una mixta: no atiende pacientes' do
      %w[social mixta].each do |tipo|
        post '/sedes', headers: auth_headers, as: :json,
             params: { sede: { nombre: "Sede #{tipo}", tipo: tipo } }

        expect(response).to have_http_status(:unprocessable_entity), "tipo #{tipo}"
        expect(response.body).to match(/Producción y dispensa/i)
      end
    end

    it 'informa qué tipos puede crear' do
      expect(Sede.tipos_disponibles(club)).to eq(%w[produccion])
    end
  end

  describe 'una organización de sólo Producción y dispensa' do
    let(:club)  { club_con(:produccion_dispensa) }
    let(:admin) { create(:user, :admin, club: club) }
    before { sign_in_as(admin) }

    it 'puede crear una sede social' do
      post '/sedes', headers: auth_headers, as: :json,
           params: { sede: { nombre: 'Dispensario Centro', tipo: 'social' } }

      expect(response).to have_http_status(:created)
    end

    it 'NO puede crear una de producción: no tiene salas' do
      post '/sedes', headers: auth_headers, as: :json,
           params: { sede: { nombre: 'Finca', tipo: 'produccion' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to match(/Cultivo/i)
    end

    # Lo que preguntó Germán: con una sede social igual se puede cargar stock comprado afuera.
    # El stock no depende de una sede de producción —`sede` es opcional y hay stock del club—,
    # así que un dispensario que compra a terceros opera con normalidad.
    it 'igual puede cargar stock externo' do
      post '/sedes', headers: auth_headers, as: :json,
           params: { sede: { nombre: 'Dispensario', tipo: 'social' } }
      sede_id = JSON.parse(response.body).dig('data', 'id') || JSON.parse(response.body)['id']

      expect {
        post '/stocks', headers: auth_headers, as: :json, params: {
          stock: { descripcion: 'Flor comprada a tercero', forma_producto: 'externo',
                   cantidad: 500, origen: 'compra_externa', proveedor: 'Tercero SRL',
                   sede_id: sede_id }
        }
      }.to change { Stock.count }.by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe 'una organización con las dos suites' do
    let(:club)  { club_con(:cultivo, :produccion_dispensa) }
    let(:admin) { create(:user, :admin, club: club) }
    before { sign_in_as(admin) }

    it 'puede crear los tres tipos' do
      expect(Sede.tipos_disponibles(club)).to match_array(%w[produccion social mixta])
    end
  end

  # Dar de baja una suite no puede volver inguardable una sede que ya existía: si no, la
  # organización no podría ni corregirle la dirección.
  it 'una sede ya creada se sigue pudiendo editar aunque la suite se dé de baja' do
    club  = club_con(:cultivo, :produccion_dispensa)
    admin = create(:user, :admin, club: club)
    sede  = ActsAsTenant.with_tenant(club) do
      Sede.create!(club: club, created_by: admin, nombre: 'Mixta', tipo: 'mixta')
    end

    club.update!(features: club.features.merge('cultivo' => false))
    sign_in_as(admin)

    patch "/sedes/#{sede.id}", headers: auth_headers, as: :json,
          params: { sede: { direccion: 'Corrientes 1234' } }

    expect(response).to have_http_status(:ok)
    expect(sede.reload.direccion).to eq('Corrientes 1234')
  end
end
