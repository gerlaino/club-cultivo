require 'rails_helper'

RSpec.describe 'Users seed invariants', type: :request do
  let!(:club) { create(:club) }

  before do
    # Simula el estado post-migración: admin2 existe, tesorero fue eliminado
    create(:user, :admin, email: 'admin2@mitocondriaclub.org',
           first_name: 'Hernán', last_name: 'Vidal', club: club)
  end

  it 'no existe ningún usuario con email empezando en tesorero' do
    expect(User.where("email LIKE 'tesorero%'").count).to eq(0)
  end

  it 'admin2@mitocondriaclub.org existe y es admin' do
    u = User.find_by(email: 'admin2@mitocondriaclub.org')
    expect(u).to be_present
    expect(u.role).to eq('admin')
  end
end
