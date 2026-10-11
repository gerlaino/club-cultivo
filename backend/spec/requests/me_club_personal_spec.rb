require 'rails_helper'

# AC (11-oct-2026, Germán): «cada vez que entro a la app se ve una vista vieja y después la de uso
# personal». Lo personal se sabía recién con las preferencias del club, que cargan en segundo
# plano; /me —que el router espera antes de mostrar nada— no lo decía.
RSpec.describe 'GET /me — uso personal', type: :request do
  include AuthHelpers

  def personal_segun_me(user)
    sign_in_as(user)
    get '/me', headers: auth_headers
    JSON.parse(response.body)['club_personal']
  end

  it 'dice true para el admin de un autocultivo' do
    club = create(:club, plan: 'personal')
    expect(personal_segun_me(create(:user, :admin, club: club))).to be(true)
  end

  it 'dice false en una organización, para cualquier rol' do
    club = create(:club, plan: 'basico')
    expect(personal_segun_me(create(:user, :admin, club: club))).to be(false)
    expect(personal_segun_me(create(:user, :cultivador, club: club))).to be(false)
  end
end
