require 'rails_helper'

# AC (Germán): "uno por sector, por sede, y cada sede tendrá los sectores correspondientes, es
# decir, dependiendo de si es sede mixta, de producción o social" — y antes: "que haya los
# sectores que te pedí nada más y sólo categorías".
#
# El problema que resolvía: el admin podía crear áreas propias y cada una arrastraba su depósito,
# así que aparecían varios depósitos para el mismo sector y no se sabía cuál era el bueno.
RSpec.describe 'Sectores y sus depósitos', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'cultivo' => true, 'produccion_dispensa' => true, 'bar' => true }) }
  let(:admin) { create(:user, :admin, club: club) }

  def sembrar(sede_tipo)
    create(:sede, club: club, created_by: admin, tipo: sede_tipo)
    Finanzas::SembrarDepositos.new(club).call
    club.reload
  end

  def depositos_de(sede)
    ActsAsTenant.with_tenant(club) { club.depositos.where(sede_id: sede.id).to_a }
  end

  describe 'los sectores' do
    it 'son los cinco y nada más' do
      ActsAsTenant.with_tenant(club) { Finanzas::SembrarCatalogo.new(club).call }

      nombres = ActsAsTenant.with_tenant(club) { club.unidades_negocio.pluck(:nombre) }
      expect(nombres).to match_array(['General', 'Cultivo', 'Dispensario', 'Buffet', 'Otro'])
    end

    it 'no se pueden crear otros' do
      sign_in_as(admin)

      post '/unidades_negocio', params: { unidad_negocio: { nombre: 'Marketing', tipo: 'general' } },
                                headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/fijos/i)
    end

    # El Buffet es un add-on: sin contratarlo no tiene sentido tener el sector.
    it 'el Buffet sólo aparece si está contratado' do
      sin_bar = create(:club, features: { 'cultivo' => true })
      ActsAsTenant.with_tenant(sin_bar) { Finanzas::SembrarCatalogo.new(sin_bar).call }

      nombres = ActsAsTenant.with_tenant(sin_bar) { sin_bar.unidades_negocio.pluck(:nombre) }
      expect(nombres).not_to include('Buffet')
    end
  end

  describe 'qué sectores tiene cada sede según su tipo' do
    it 'una sede de PRODUCCIÓN no dispensa ni tiene buffet' do
      sede = sembrar('produccion')

      claves = depositos_de(club.sedes.last).map(&:clave_sistema)
      expect(claves).to match_array(%w[general cultivo otro])
    end

    it 'una sede SOCIAL no cultiva' do
      sembrar('social')

      claves = depositos_de(club.sedes.last).map(&:clave_sistema)
      expect(claves).to match_array(%w[general dispensacion salon otro])
    end

    it 'una sede MIXTA los tiene todos' do
      sembrar('mixta')

      claves = depositos_de(club.sedes.last).map(&:clave_sistema)
      expect(claves).to match_array(%w[general cultivo dispensacion salon otro])
    end
  end

  describe 'un depósito por sector y por sede' do
    it 'cada depósito sembrado apunta a un sector distinto' do
      sembrar('mixta')

      areas = depositos_de(club.sedes.last).map(&:unidad_negocio_id)
      expect(areas.compact.uniq.size).to eq(areas.size)
    end

    it 'no se puede crear un segundo depósito para el mismo sector en la misma sede' do
      sembrar('mixta')
      sede    = club.sedes.last
      ocupado = depositos_de(sede).first

      repetido = ActsAsTenant.with_tenant(club) do
        club.depositos.new(nombre: 'Cultivo 2', sede: sede,
                           unidad_negocio_id: ocupado.unidad_negocio_id)
      end

      expect(repetido).not_to be_valid
      expect(repetido.errors[:unidad_negocio_id].join).to match(/ya tiene un depósito/i)
    end

    # El mismo sector SÍ tiene su depósito en cada sede: son inventarios distintos.
    it 'pero sí uno por cada sede' do
      sembrar('mixta')
      sembrar('mixta')

      cultivo = ActsAsTenant.with_tenant(club) { club.depositos.where(clave_sistema: 'cultivo') }
      expect(cultivo.count).to eq(2)
      expect(cultivo.pluck(:sede_id).uniq.size).to eq(2)
    end

    # Correr la siembra de nuevo no puede duplicar nada.
    it 'sembrar dos veces no agrega depósitos' do
      sembrar('mixta')
      antes = ActsAsTenant.with_tenant(club) { club.depositos.count }

      Finanzas::SembrarDepositos.new(club).call

      expect(ActsAsTenant.with_tenant(club) { club.depositos.count }).to eq(antes)
    end
  end
end
