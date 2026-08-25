require 'rails_helper'

# AC: desde el panel de plataforma tiene que poder restablecerse la contraseña de cualquier
# usuario de cualquier organización.
#
# Es el caso que SIEMPRE termina acá: el único admin de una organización pierde su clave. La
# pantalla de login todavía no ofrece "olvidé mi contraseña", así que no tiene cómo resolverlo
# solo — y desde el panel no había ninguna salida. Había que crear un segundo admin para resetear
# desde adentro, o meter mano en la consola de Rails.
#
# No se RECUPERA nada: las contraseñas se guardan hasheadas y no hay forma de leerlas. Se genera
# una nueva y se devuelve en claro, a propósito, porque hay que poder dictarla por teléfono.
RSpec.describe 'SuperAdmin: restablecer contraseña', type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:club)        { create(:club) }
  let!(:admin)      { create(:user, :admin, club: club, password: 'ClaveVieja1', password_confirmation: 'ClaveVieja1') }

  before { sign_in_as(super_admin) }

  def resetear! = post("/api/super_admin/users/#{admin.id}/reset_password", as: :json)
  def json      = JSON.parse(response.body)

  it 'devuelve la contraseña nueva en claro, para poder dictarla' do
    resetear!

    expect(response).to have_http_status(:ok)
    expect(json['email']).to eq(admin.email)
    expect(json['password_inicial']).to be_present
  end

  it 'la contraseña nueva sirve para entrar' do
    resetear!

    expect(admin.reload.valid_password?(json['password_inicial'])).to be(true)
  end

  it 'la anterior deja de servir' do
    resetear!

    expect(admin.reload.valid_password?('ClaveVieja1')).to be(false)
  end

  # Dictable por teléfono: sin los caracteres que se confunden al deletrear (0/O, 1/l/I). Es la
  # misma que usa el alta, y por eso se genera con `User.password_temporal` y no a mano.
  it 'la genera dictable, no una cadena cualquiera' do
    resetear!

    expect(json['password_inicial']).to match(/\A[a-zA-Z]{8}\d{4}\z/)
    expect(json['password_inicial']).not_to match(/[0O1lI]/)
  end

  it 'cada reset da una distinta' do
    resetear!
    una = json['password_inicial']
    resetear!

    expect(json['password_inicial']).not_to eq(una)
  end

  # El mail es la vía cómoda, no la única: la mayoría de las organizaciones no tiene el correo
  # configurado, y ahí la contraseña en pantalla es TODO lo que hay.
  it 'avisa si el mail salió o no, sin romper cuando la organización no tiene correo' do
    resetear!

    expect(json['mail_enviado']).to be(false)
    expect(response).to have_http_status(:ok)
  end

  it 'funciona con un usuario de cualquier organización, no sólo del club en contexto' do
    otro_club  = create(:club)
    otro_admin = create(:user, :admin, club: otro_club)

    post "/api/super_admin/users/#{otro_admin.id}/reset_password", as: :json

    expect(response).to have_http_status(:ok)
    expect(otro_admin.reload.valid_password?(JSON.parse(response.body)['password_inicial'])).to be(true)
  end

  it 'sólo el super admin puede: un admin de club no resetea a nadie por acá' do
    otro = create(:user, :admin, club: club)
    sign_in_as(otro)

    post "/api/super_admin/users/#{admin.id}/reset_password", as: :json

    expect(response).to have_http_status(:forbidden)
    expect(admin.reload.valid_password?('ClaveVieja1')).to be(true)
  end
end
