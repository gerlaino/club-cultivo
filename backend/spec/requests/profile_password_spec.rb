require 'rails_helper'

# AC (Germán, 25-sep-2026): en «Mi perfil», cambiar la contraseña sin pedir la actual. Acordado
# con él (opción A) junto con lo que la reemplaza: al cambiarla se cierran las sesiones en los
# demás dispositivos y llega un mail avisando.
RSpec.describe 'PATCH /profile/password', type: :request do
  include AuthHelpers
  include ActiveJob::TestHelper

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club, email_personal: 'german@real.com') }

  def cambiar(password = 'NuevaClave2026!', confirmacion = password)
    patch '/profile/password', params: { user: { password: password, password_confirmation: confirmacion } }, as: :json
  end

  it 'cambia la contraseña sin pedir la actual' do
    sign_in_as(admin)

    cambiar

    expect(response).to have_http_status(:ok)
    expect(admin.reload.valid_password?('NuevaClave2026!')).to be(true)
  end

  it 'si la confirmación no coincide, no la cambia' do
    sign_in_as(admin)

    cambiar('NuevaClave2026!', 'OtraCosa2026!')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(admin.reload.valid_password?(AuthHelpers::DEFAULT_PASSWORD)).to be(true)
  end

  it 'quien la cambió sigue adentro' do
    sign_in_as(admin)

    cambiar
    get '/profile', as: :json

    expect(response).to have_http_status(:ok)
  end

  it 'la sesión abierta en otro dispositivo deja de valer' do
    otro_dispositivo = mobile_login_as(admin)
    expect(otro_dispositivo).to start_with('Bearer ')
    sign_in_as(admin)

    cambiar
    reset!
    get '/profile', headers: { 'Authorization' => otro_dispositivo, 'X-Mobile-Client' => 'true' }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'sin cambio de contraseña, la sesión del otro dispositivo sigue andando' do
    otro_dispositivo = mobile_login_as(admin)
    expect(otro_dispositivo).to start_with('Bearer ')

    get '/profile', headers: { 'Authorization' => otro_dispositivo, 'X-Mobile-Client' => 'true' }, as: :json

    expect(response).to have_http_status(:ok)
  end

  it 'manda un mail avisando al mail real, con cómo recuperarla si no fue él' do
    sign_in_as(admin)

    perform_enqueued_jobs { cambiar }

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq(['german@real.com'])
    expect(mail.subject).to include('Tu contraseña cambió')
    expect(mail.text_part.decoded).to include('/olvide-contrasena')
  end

  it 'sin mail real no intenta mandar nada' do
    # Login inventado de la organización (`rol@slug.com`) y sin mail personal: no hay a dónde escribir.
    sin_mail = create(:user, :cultivador, club: club, email: "cultivador@#{club.slug}.com", email_personal: nil)
    expect(sin_mail.email_real).to be_nil
    sign_in_as(sin_mail)
    ActionMailer::Base.deliveries.clear

    perform_enqueued_jobs { cambiar }

    expect(response).to have_http_status(:ok)
    expect(ActionMailer::Base.deliveries.select { |m| m.subject.to_s.include?('Tu contraseña cambió') }).to be_empty
  end
end
