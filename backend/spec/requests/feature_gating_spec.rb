require 'rails_helper'

# AC: un módulo apagado devuelve 403 EN LA API. Esconder el botón no es gating: hasta ahora
# 10 de las 13 banderas no bloqueaban nada y el club entraba igual por la API.
RSpec.describe 'Gating por módulo', type: :request do
  let(:club)   { create(:club) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:medico) { create(:user, :medico, club: club) }

  def features!(hash)
    club.update_columns(features: hash)
  end

  describe 'módulo médico apagado' do
    before do
      features!('cultivo' => true, 'produccion_dispensa' => true, 'medico' => false)
      sign_in_as(medico)
    end

    it 'rechaza la lista de pacientes del médico con 403 y explica por qué' do
      get '/api/medico/pacientes'

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body['requiere_modulo']).to be(true)
      expect(body['modulo']).to eq('medico')
      expect(body['error']).to match(/Módulo médico/i)
    end
  end

  describe 'módulo médico prendido' do
    it 'deja pasar' do
      features!('cultivo' => true, 'produccion_dispensa' => true, 'medico' => true)
      sign_in_as(medico)

      get '/api/medico/pacientes'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'módulos incompletos' do
    # ARICCAME simula el envío a ANMAT y la web pública no está deployada: vienen APAGADOS y
    # el panel advierte qué les falta, pero se pueden prender a conciencia.
    it 'no vienen activados por defecto en un club nuevo' do
      expect(Club::FEATURES_POR_DEFECTO).not_to have_key('ariccame')
      expect(Club::FEATURES_POR_DEFECTO).not_to have_key('web_publica')
    end

    it 'quedan marcados como incompletos, con el motivo a la vista' do
      expect(club.addon_incompleto?(:ariccame)).to be(true)
      expect(club.addon_incompleto?(:web_publica)).to be(true)
      expect(Club::ADDONS['ariccame'][:requiere]).to match(/INCOMPLETO/)
    end

    it 'el que está terminado no aparece como incompleto' do
      expect(club.addon_incompleto?(:bar)).to be(false)
    end
  end

  describe 'compatibilidad con las banderas viejas' do
    it 'un club con ia_voz sigue teniendo el asistente' do
      features!('cultivo' => true, 'ia_voz' => true)

      expect(club.reload.feature?(:ia)).to be(true)
    end

    it 'cuenta_corriente vieja equivale a la suite de dispensa' do
      features!('cuenta_corriente' => true)

      expect(club.reload.feature?(:cuenta_corriente)).to be(true)
    end
  end

  describe 'un club sin nada habilitado' do
    it 'no habilita ningún add-on' do
      features!({})

      club.reload
      Club::ADDONS.each_key do |addon|
        expect(club.addon_disponible?(addon)).to be(false), "#{addon} no debería estar disponible"
      end
    end
  end
end
