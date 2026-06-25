require 'rails_helper'

RSpec.describe 'POST /salas/:sala_id/lotes (alta de lote)', type: :request do
  let(:club)  { create(:club) }
  let(:sede)  { create(:sede, club: club) }
  let(:sala)  { create(:sala, club: club, sede: sede, kind: 'vegetativo') }
  let(:admin) { create(:user, club: club, role: 'admin') }

  before { sign_in_as(admin) }

  def crear(params)
    post "/salas/#{sala.id}/lotes", params: { lote: params }, headers: auth_headers
  end

  context 'con datos válidos' do
    it 'crea el lote y sus plantas' do
      expect {
        crear(estado: 'vegetativo', plants_count: 5, start_date: Date.today)
      }.to change(Lote, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  context 'cantidad de plantas' do
    it 'rechaza plants_count 0' do
      crear(estado: 'vegetativo', plants_count: 0, start_date: Date.today)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].join).to match(/al menos 1/i)
    end
  end

  context 'estados no creables (post-stock / proceso)' do
    %w[curado finalizado en_manicura manicura_pendiente].each do |estado|
      it "rechaza crear en estado '#{estado}'" do
        crear(estado: estado, plants_count: 3, start_date: Date.today)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors'].join).to match(/no se puede crear/i)
      end
    end
  end

  context 'estado cosechado (heredado, pendiente de manicura)' do
    it 'permite crear en estado cosecha' do
      expect {
        crear(estado: 'cosecha', plants_count: 4, start_date: Date.today)
      }.to change(Lote, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  context 'lote cosechado sin sala (por sede)' do
    it 'crea el lote sin sala (sala_id nil) y con la sede directa' do
      expect {
        post '/lotes', params: {
          lote: { estado: 'cosecha', plants_count: 4 },
          heredado: true, sede_id: sede.id, dias_floracion: 60,
        }, headers: auth_headers
      }.to change(Lote, :count).by(1)
      expect(response).to have_http_status(:created)
      lote = Lote.last
      expect(lote.estado).to eq('cosecha')
      expect(lote.sala_id).to be_nil        # post-cosecha no usa sala
      expect(lote.sede_id).to eq(sede.id)   # sede directa
    end

    it 'rechaza si no hay sala ni sede' do
      post '/lotes', params: { lote: { estado: 'cosecha', plants_count: 4 }, heredado: true }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context 'lote de esquejes con varias plantas madre' do
    let(:madre_sala) { create(:sala, club: club, sede: sede, kind: 'vegetativo') }
    let(:madre_lote) { create(:lote, club: club, sala: madre_sala, estado: 'vegetativo') }
    let(:madres)     { 3.times.map { |i| Plant.create!(lote: madre_lote, club: club, nombre: "M#{i}", state: 'vegetativo') } }

    it 'guarda el array de madres y deja planta_madre_id = la primera' do
      ids = madres.map(&:id)
      crear(estado: 'esqueje', origen: 'esqueje', plants_count: 8, start_date: Date.today, planta_madre_ids: ids)
      expect(response).to have_http_status(:created)
      lote = Lote.last
      expect(lote.planta_madre_ids).to eq(ids)
      expect(lote.planta_madre_id).to eq(ids.first)
    end
  end

  context 'tamaño de maceta decimal' do
    it 'guarda 0.5L (vaso) sin truncar' do
      crear(estado: 'vegetativo', plants_count: 2, start_date: Date.today, tamanio_maceta: '0.5')
      expect(response).to have_http_status(:created)
      expect(Lote.last.tamanio_maceta).to eq(0.5)
    end
  end
end
