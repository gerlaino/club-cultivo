require 'rails_helper'

# AC (sep-2026): el Club Modelo y el clonado del cultivo existían como rake. Desde el panel:
# la demo se genera en segundo plano (tarda) y el clon es sincrónico y todo o nada.
RSpec.describe 'SuperAdmin: demo y clonar', type: :request do
  let(:super_admin) { create(:user, :super_admin) }

  before { sign_in_as(super_admin) }

  def json = JSON.parse(response.body)

  describe 'POST /super_admin/clubs/demo' do
    it 'encola la generación y devuelve el acceso para dictarlo' do
      expect {
        post '/api/super_admin/clubs/demo', params: { nombre: 'Club Modelo' }, as: :json
      }.to have_enqueued_job(SembrarDemoJob).with(hash_including(slug: 'club_modelo'))

      expect(response).to have_http_status(:accepted)
      expect(json['password_inicial']).to be_present
      expect(json['usuario']).to eq('admin@club-modelo.example.com')
    end

    it 'rebota si ya hay una organización con ese identificador' do
      create(:club, slug: 'club_modelo')

      post '/api/super_admin/clubs/demo', params: { nombre: 'Club Modelo' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].first).to include('club_modelo')
    end
  end

  describe 'POST /super_admin/clubs/:id/clonar' do
    let(:origen) { create(:club, name: 'Origen') }

    before do
      ActsAsTenant.with_tenant(origen) do
        sede = create(:sede, club: origen, tipo: 'mixta')
        create(:sala, club: origen, sede: sede)
      end
    end

    it 'crea la organización nueva con el cultivo y devuelve el acceso' do
      post "/api/super_admin/clubs/#{origen.id}/clonar", params: { nombre: 'Copia' }, as: :json

      expect(response).to have_http_status(:created)
      nuevo = Club.find(json['club']['id'])
      expect(nuevo.name).to eq('Copia')
      ActsAsTenant.with_tenant(nuevo) do
        expect(nuevo.sedes.count).to eq(1)
        expect(nuevo.salas.count).to eq(1)
      end
      expect(json['password_inicial']).to be_present
      expect(nuevo.users.find_by(role: 'admin').valid_password?(json['password_inicial'])).to be(true)
    end

    it 'sin nombre no clona' do
      post "/api/super_admin/clubs/#{origen.id}/clonar", params: { nombre: '' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'un slug repetido rebota con el motivo, sin dejar nada a medias' do
      create(:club, slug: 'copia')

      expect {
        post "/api/super_admin/clubs/#{origen.id}/clonar", params: { nombre: 'Copia' }, as: :json
      }.not_to change(Club.unscoped, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
