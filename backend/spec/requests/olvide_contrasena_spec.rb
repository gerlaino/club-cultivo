require 'rails_helper'

# AC (sep-2026): quien se olvidó la contraseña la recupera SOLO, sin escribirle al dueño de la
# plataforma. Pide el link por su usuario de ingreso O por su mail personal —el login puede ser
# `admin@slug.com`, que nadie recuerda—, el mail sale por la casilla de la plataforma, y el link
# lleva a la pantalla de la SPA para elegir la nueva.
RSpec.describe 'Olvidé mi contraseña', type: :request do
  let(:club) { create(:club) }
  let!(:admin) do
    create(:user, :admin, club: club, email: "admin@#{club.slug}.com", email_personal: 'juan@gmail.com',
                          password: 'ClaveVieja1', password_confirmation: 'ClaveVieja1')
  end

  def json = JSON.parse(response.body)

  describe 'pedir el link' do
    it 'por el usuario de ingreso' do
      expect {
        post '/api/password', params: { usuario: admin.email }, as: :json
      }.to have_enqueued_mail(AccesoMailer, :restablecer_contrasena)

      expect(response).to have_http_status(:ok)
      expect(json['enviado']).to be(true)
      expect(admin.reload.reset_password_token).to be_present
    end

    it 'por el mail personal, sin importar mayúsculas' do
      expect {
        post '/api/password', params: { usuario: 'Juan@Gmail.com' }, as: :json
      }.to have_enqueued_mail(AccesoMailer, :restablecer_contrasena)

      expect(json['enviado']).to be(true)
    end

    # No se regala el padrón: un usuario inexistente recibe la misma respuesta que uno real.
    it 'no revela si el usuario existe' do
      post '/api/password', params: { usuario: 'nadie@nada.com' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json['enviado']).to be(true)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    # La única distinción que se hace es la que la persona necesita para saber qué hacer.
    it 'si la cuenta existe pero no tiene casilla real, dice a quién pedirle la clave' do
      admin.update_columns(email_personal: nil)

      expect {
        post '/api/password', params: { usuario: admin.email }, as: :json
      }.not_to have_enqueued_mail

      expect(json['enviado']).to be(false)
      expect(json['sin_mail']).to be(true)
      expect(json['mensaje']).to include('administrador de tu organización')
    end

    it 'sin dato, rebota' do
      post '/api/password', params: { usuario: '' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'elegir la nueva' do
    def token_de(user)
      raw, enc = Devise.token_generator.generate(User, :reset_password_token)
      user.update_columns(reset_password_token: enc, reset_password_sent_at: Time.current)
      raw
    end

    it 'con el token del mail cambia la contraseña y la vieja deja de servir' do
      put '/api/password', params: { token: token_de(admin), password: 'ClaveNueva22', password_confirmation: 'ClaveNueva22' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(admin.reload.valid_password?('ClaveNueva22')).to be(true)
      expect(admin.valid_password?('ClaveVieja1')).to be(false)
      expect(admin.reset_password_token).to be_nil
    end

    it 'un token vencido no sirve, y lo dice' do
      raw = token_de(admin)
      admin.update_columns(reset_password_sent_at: 7.hours.ago)

      put '/api/password', params: { token: raw, password: 'ClaveNueva22', password_confirmation: 'ClaveNueva22' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['token_invalido']).to be(true)
      expect(admin.reload.valid_password?('ClaveVieja1')).to be(true)
    end

    it 'un token inventado no sirve' do
      put '/api/password', params: { token: 'cualquiera', password: 'ClaveNueva22', password_confirmation: 'ClaveNueva22' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['token_invalido']).to be(true)
    end

    it 'una contraseña floja rebota con el motivo' do
      put '/api/password', params: { token: token_de(admin), password: '1', password_confirmation: '1' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors']).to be_present
    end
  end

  describe 'el mail' do
    it 'va a la casilla real y lleva el link a la pantalla de la SPA' do
      mail = AccesoMailer.restablecer_contrasena(user: admin, token: 'abc123')

      expect(mail.to).to eq(['juan@gmail.com'])
      expect(mail.from).to eq([Club::PLATFORM_FROM])
      # `decoded`, no `encoded`: en quoted-printable el `=` del query string viaja como `=3D`.
      expect(mail.text_part.decoded).to include('/restablecer?token=abc123')
      expect(mail.html_part.decoded).to include('/restablecer?token=abc123')
    end
  end
end
