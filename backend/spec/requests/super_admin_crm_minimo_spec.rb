require 'rails_helper'

# AC (sep-2026): la ficha dice CON QUIÉN hablo y QUÉ QUEDAMOS. Contacto y próxima acción con
# fecha en la organización; notas con autor y fecha que se crean y se borran, nunca se editan.
# La próxima acción, cuando llega su día, entra a la cola del panel.
RSpec.describe 'SuperAdmin: contacto, notas y próxima acción', type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:club)        { create(:club, name: 'Verde Norte') }

  before { sign_in_as(super_admin) }

  def json = JSON.parse(response.body)

  it 'guarda contacto y próxima acción desde la ficha' do
    put "/api/super_admin/clubs/#{club.id}",
        params: { club: { contacto_nombre: 'Juan Pérez', proxima_accion: 'Llamar por Delivery',
                          proxima_accion_el: (Time.zone.today + 2).to_s } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json['contacto_nombre']).to    eq('Juan Pérez')
    expect(json['proxima_accion']).to     eq('Llamar por Delivery')
    expect(json['proxima_accion_el']).to  eq((Time.zone.today + 2).to_s)
  end

  describe 'notas' do
    it 'se crean con autor y fecha y salen en la ficha, la más nueva primero' do
      post "/api/super_admin/clubs/#{club.id}/notas", params: { texto: 'Habló con Juan, quiere Delivery en octubre' }, as: :json
      expect(response).to have_http_status(:created)
      expect(json['usuario']['id']).to eq(super_admin.id)

      post "/api/super_admin/clubs/#{club.id}/notas", params: { texto: 'Segunda' }, as: :json

      get "/api/super_admin/clubs/#{club.id}"
      expect(json['notas'].map { |n| n['texto'] }).to eq(['Segunda', 'Habló con Juan, quiere Delivery en octubre'])
    end

    it 'una nota vacía rebota' do
      post "/api/super_admin/clubs/#{club.id}/notas", params: { texto: '  ' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'se borran' do
      nota = club.notas.create!(texto: 'x', user: super_admin)

      delete "/api/super_admin/clubs/#{club.id}/notas/#{nota.id}"

      expect(response).to have_http_status(:no_content)
      expect(club.notas.count).to eq(0)
    end

    it 'no se toca una nota de otra organización por la URL de ésta' do
      ajena = create(:club).notas.create!(texto: 'ajena', user: super_admin)

      delete "/api/super_admin/clubs/#{club.id}/notas/#{ajena.id}"

      expect(response).to have_http_status(:not_found)
      expect(ClubNota.exists?(ajena.id)).to be(true)
    end
  end

  describe 'la agenda del panel' do
    def agenda
      get '/api/super_admin/pulso'
      json['agenda']
    end

    it 'lista lo que vence en la semana y marca lo que ya pasó' do
      club.update!(proxima_accion: 'Llamar', proxima_accion_el: Time.zone.today - 1, contacto_nombre: 'Juan')
      proxima = create(:club, proxima_accion: 'Mandar propuesta', proxima_accion_el: Time.zone.today + 3)
      lejana  = create(:club, proxima_accion: 'Renovar', proxima_accion_el: Time.zone.today + 30)

      filas = agenda
      ids   = filas.map { |f| f['id'] }

      expect(ids).to include(club.id, proxima.id)
      expect(ids).not_to include(lejana.id)
      mia = filas.find { |f| f['id'] == club.id }
      expect(mia['vencida']).to  be(true)
      expect(mia['accion']).to   eq('Llamar')
      expect(mia['contacto']).to eq('Juan')
    end

    it 'sin fecha no hay nada agendado' do
      club.update!(proxima_accion: 'Algún día', proxima_accion_el: nil)

      expect(agenda.map { |f| f['id'] }).not_to include(club.id)
    end
  end
end
