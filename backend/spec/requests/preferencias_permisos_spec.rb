require 'rails_helper'

# La configuración de la organización la LEE todo el equipo y la CAMBIA el admin. Barrido de
# seguridad, 13-oct-2026: cualquier rol podía hacer PUT /preferences y cambiar el nombre, prender
# el portal del paciente, subir el logo o mandar correos y WhatsApp de prueba.
RSpec.describe 'Preferencias de la organización: quién las cambia', type: :request do
  include AuthHelpers

  let(:club) { create(:club, name: 'Original') }

  %i[cultivador dispensador manicura medico].each do |rol|
    it "#{rol}: lee, pero no cambia nada" do
      sign_in_as(create(:user, rol, club: club))

      get '/preferences'
      expect(response).to have_http_status(:ok)

      patch '/preferences', params: { club: { name: 'Hackeada', vista_paciente_activa: true } }, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(club.reload.name).to eq('Original')

      post '/preferences/upload_logo', params: {}
      expect(response).to have_http_status(:forbidden)

      post '/preferences/test_twilio', as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'el admin la cambia' do
    sign_in_as(create(:user, :admin, club: club))
    patch '/preferences', params: { club: { name: 'Nueva' } }, as: :json
    expect(response).to have_http_status(:ok)
    expect(club.reload.name).to eq('Nueva')
  end

  it 'aislamiento: el admin cambia SU organización, nunca otra' do
    otra = create(:club, name: 'Otra')
    sign_in_as(create(:user, :admin, club: club))
    patch '/preferences', params: { club: { name: 'Cambiada', id: otra.id } }, as: :json
    expect(otra.reload.name).to eq('Otra')
    expect(club.reload.name).to eq('Cambiada')
  end
end
