require 'rails_helper'

# AC (29-oct-2026, seguridad tanda 2): cambiar el mail en «Mi perfil» pide la contraseña actual. El
# mail es a donde llega «Olvidé mi contraseña»: con una sesión ajena abierta alcanzaba poner uno
# propio, pedir el link y quedarse con la cuenta. Lo demás del perfil se edita como siempre.
RSpec.describe 'PATCH /profile (el mail)', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club, email_personal: 'german@real.com', phone: '111') }

  def guardar(datos)
    patch '/profile', params: { user: datos }, as: :json
  end

  before { sign_in_as(admin) }

  it 'cambiar el mail personal sin la contraseña no lo cambia' do
    guardar(email_personal: 'otro@atacante.com')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['errors']).to eq(['La contraseña actual no es correcta.'])
    expect(admin.reload.email_personal).to eq('german@real.com')
  end

  it 'cambiar el mail de entrada sin la contraseña tampoco' do
    viejo = admin.email
    guardar(email: 'nuevo@x.com')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(admin.reload.email).to eq(viejo)
  end

  it 'con la contraseña equivocada no lo cambia' do
    guardar(email_personal: 'otro@atacante.com', current_password: 'no-es')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(admin.reload.email_personal).to eq('german@real.com')
  end

  it 'con la contraseña correcta lo cambia' do
    guardar(email_personal: 'nuevo@real.com', current_password: AuthHelpers::DEFAULT_PASSWORD)

    expect(response).to have_http_status(:ok)
    expect(admin.reload.email_personal).to eq('nuevo@real.com')
  end

  it 'mandar el mismo mail (el formulario manda todo) no pide la contraseña' do
    guardar(email: admin.email, email_personal: 'German@Real.com ', phone: '222')

    expect(response).to have_http_status(:ok)
    expect(admin.reload.phone).to eq('222')
  end

  it 'el teléfono y el nombre se cambian sin pedirla' do
    guardar(phone: '333', first_name: 'Germán')

    expect(response).to have_http_status(:ok)
    expect(admin.reload.phone).to eq('333')
  end
end
