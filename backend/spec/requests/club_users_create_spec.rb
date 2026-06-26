require 'rails_helper'

RSpec.describe 'POST /usuarios (alta de usuarios del club)', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, club: club, role: 'admin') }

  before { sign_in_as(admin) }

  def crear(role)
    post '/usuarios', params: {
      user: { email: "nuevo-#{role}@test.com", first_name: 'N', last_name: 'N', role: role, password: '123456Aa' }
    }, headers: auth_headers
  end

  context 'club sin ninguna sede' do
    it 'bloquea el alta de un usuario operativo (cultivador)' do
      crear('cultivador')
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].join).to match(/sede/i)
    end

    it 'permite crear otro admin (arma el club)' do
      expect { crear('admin') }.to change(User, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  context 'club con al menos una sede' do
    before { create(:sede, club: club) }

    it 'permite el alta de un usuario operativo' do
      expect { crear('cultivador') }.to change(User, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end
end

RSpec.describe 'Usuario: email de ingreso vs email personal', type: :request do
  include AuthHelpers
  let(:club)  { create(:club) }
  let(:admin) { create(:user, club: club, role: 'admin') }
  before { sign_in_as(admin) }

  it 'guarda el email_personal separado del email de login' do
    post '/usuarios', params: {
      user: { email: 'cultivador@miclub.com', email_personal: 'juan@gmail.com',
              first_name: 'Juan', last_name: 'P', role: 'admin', password: '123456Aa' }
    }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)['data']
    expect(body['email']).to eq('cultivador@miclub.com')
    expect(body['email_personal']).to eq('juan@gmail.com')
  end
end
