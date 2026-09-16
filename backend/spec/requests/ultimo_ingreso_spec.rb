require 'rails_helper'

# AC (sep-2026): el panel de plataforma tiene que poder contestar «¿cuándo entró alguien de
# esta organización por última vez?». Con JWT no hay login que marcar —la PWA instalada no
# vuelve a loguearse en semanas—, así que se marca la ACTIVIDAD, una vez por hora como mucho.
RSpec.describe 'Último ingreso', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  describe 'la marca' do
    it 'un request autenticado deja la hora' do
      sign_in_as(admin)
      admin.update_column(:visto_at, nil)

      get '/api/me'

      expect(admin.reload.visto_at).to be_within(5.seconds).of(Time.current)
    end

    it 'no vuelve a escribir dentro de la misma hora' do
      sign_in_as(admin)
      hace_poco = 20.minutes.ago
      admin.update_column(:visto_at, hace_poco)

      get '/api/me'

      expect(admin.reload.visto_at).to be_within(1.second).of(hace_poco)
    end

    it 'sí escribe pasada la hora' do
      sign_in_as(admin)
      admin.update_column(:visto_at, 2.hours.ago)

      get '/api/me'

      expect(admin.reload.visto_at).to be_within(5.seconds).of(Time.current)
    end
  end

  describe 'Club#ultimo_ingreso' do
    it 'es la última marca de alguien del EQUIPO; el paciente que mira su portal no cuenta' do
      ayer = 1.day.ago
      admin.update_column(:visto_at, ayer)
      create(:user, club: club, role: 'paciente', visto_at: Time.current)

      expect(club.ultimo_ingreso).to be_within(1.second).of(ayer)
    end
  end

  describe 'en el panel' do
    let(:super_admin) { create(:user, :super_admin) }

    before { sign_in_as(super_admin) }

    it 'una organización sólo-Cultivo que entra todos los días NO está en silencio aunque no cree lotes' do
      admin.update_column(:visto_at, 1.day.ago)

      get '/api/super_admin/pulso'
      ids = JSON.parse(response.body)['sin_actividad'].map { |c| c['id'] }

      expect(ids).not_to include(club.id)
    end

    it 'una organización en la que nadie entra hace un mes SÍ, con la fecha' do
      admin.update_column(:visto_at, 40.days.ago)

      get '/api/super_admin/pulso'
      fila = JSON.parse(response.body)['sin_actividad'].find { |c| c['id'] == club.id }

      expect(fila).to be_present
      expect(fila['dias_en_silencio']).to eq(40)
    end

    it 'la lista y la ficha llevan el último ingreso' do
      admin.update_column(:visto_at, 1.day.ago)

      get '/api/super_admin/clubs'
      fila = JSON.parse(response.body).find { |c| c['id'] == club.id }
      expect(fila['ultimo_ingreso']).to be_present

      get "/api/super_admin/clubs/#{club.id}"
      expect(JSON.parse(response.body)['ultimo_ingreso']).to be_present
    end
  end
end
