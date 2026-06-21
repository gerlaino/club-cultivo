require 'rails_helper'

RSpec.describe 'Jornadas laborales', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:manicura) { create(:user, :manicura, club: club) }

  describe 'modelo: cálculo de horas' do
    it 'calcula horas de entrada/salida' do
      j = JornadaLaboral.new(hora_entrada: '09:00', hora_salida: '17:30')
      expect(j.horas).to eq(8.5)
    end
    it 'soporta turno que cruza medianoche' do
      j = JornadaLaboral.new(hora_entrada: '22:00', hora_salida: '02:00')
      expect(j.horas).to eq(4.0)
    end
  end

  describe 'como manicura' do
    before { sign_in_as(manicura) }

    it 'carga su jornada y devuelve las horas' do
      post '/api/jornadas', params: { jornada: { fecha: Date.current.to_s, hora_entrada: '09:00', hora_salida: '13:00' } }, as: :json
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['horas']).to eq(4.0)
      expect(JornadaLaboral.last.user_id).to eq(manicura.id)
    end

    it 'lista las del mes con total' do
      JornadaLaboral.create!(club: club, user: manicura, fecha: Date.current, hora_entrada: '09:00', hora_salida: '13:00')
      get '/api/jornadas', params: { anio: Date.current.year, mes: Date.current.month }
      body = JSON.parse(response.body)
      expect(body['total_horas']).to eq(4.0)
      expect(body['jornadas'].size).to eq(1)
    end

    it 'no puede cargar fecha futura' do
      post '/api/jornadas', params: { jornada: { fecha: (Date.current + 2).to_s, hora_entrada: '09:00', hora_salida: '13:00' } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'corrección por admin' do
    it 'el admin puede editar la jornada de un usuario' do
      j = JornadaLaboral.create!(club: club, user: manicura, fecha: Date.current, hora_entrada: '09:00', hora_salida: '13:00')
      sign_in_as(admin)
      patch "/api/jornadas/#{j.id}", params: { jornada: { hora_salida: '15:00' } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(j.reload.hora_salida).to eq('15:00')
      expect(j.horas).to eq(6.0)
    end
  end

  describe 'permisos' do
    it 'un dispensador no accede' do
      disp = create(:user, :dispensador, club: club)
      sign_in_as(disp)
      get '/api/jornadas'
      expect(response).to have_http_status(:forbidden)
    end

    it 'no se ven jornadas de otro club' do
      otro = create(:club); otro_admin = create(:user, :admin, club: otro)
      otro_mani = create(:user, :manicura, club: otro)
      JornadaLaboral.create!(club: otro, user: otro_mani, fecha: Date.current, hora_entrada: '09:00', hora_salida: '18:00')
      sign_in_as(manicura)
      get '/api/jornadas'
      expect(JSON.parse(response.body)['jornadas']).to eq([])
    end
  end
end
