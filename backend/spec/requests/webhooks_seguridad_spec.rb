require 'rails_helper'

# Un webhook es el servidor saliendo a pedirle algo a la dirección que escribió un admin. Y admin
# es cualquiera: el autoregistro de autocultivo nace con ese rol. Barrido de seguridad, 13-oct-2026:
# alguien se registraba, apuntaba un webhook a un servicio interno y leía lo que contestaba.
RSpec.describe 'Webhooks salientes: a dónde sale el servidor', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:params_webhook) { { webhook: { nombre: 'ERP', url: 'https://hooks.example/recibir', events: ['lote.avanzado'] } } }

  before do
    allow(Seguridad::DestinoPublico).to receive(:direcciones).and_call_original
    allow(Seguridad::DestinoPublico).to receive(:direcciones).with('hooks.example').and_return(%w[93.184.215.14])
    allow(Seguridad::DestinoPublico).to receive(:direcciones).with('interno.example').and_return(%w[10.0.0.7])
  end

  def crear_webhook(club, url: 'https://hooks.example/recibir')
    ActsAsTenant.with_tenant(club) do
      Webhook.create!(club: club, created_by: create(:user, :admin, club: club), nombre: 'ERP', url: url,
                      secret: 'x' * 64, events: ['lote.avanzado'].to_json)
    end
  end

  describe 'alta' do
    it 'una organización da de alta un webhook a una dirección pública' do
      sign_in_as(admin)
      post '/webhooks', params: params_webhook, as: :json
      expect(response).to have_http_status(:created)
    end

    it 'no acepta una IP interna ni un dominio que resuelve a la red privada' do
      sign_in_as(admin)
      ['http://10.0.0.5:6379/', 'http://169.254.169.254/latest/meta-data', 'https://interno.example/x',
       'http://localhost:3001/api/me'].each do |url|
        post '/webhooks', params: { webhook: params_webhook[:webhook].merge(url: url) }, as: :json
        expect(response).to have_http_status(:unprocessable_entity), "aceptó #{url}"
      end
      expect(Webhook.unscoped.count).to eq(0)
    end

    it 'el autocultivo no tiene webhooks: su admin nace del autoregistro' do
      personal = create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL)
      sign_in_as(create(:user, :admin, club: personal))
      post '/webhooks', params: params_webhook, as: :json
      expect(response).to have_http_status(:forbidden)
      get '/webhooks'
      expect(response).to have_http_status(:forbidden)
    end

    it 'un rol que no es admin no los ve' do
      sign_in_as(create(:user, :cultivador, club: club))
      get '/webhooks'
      expect(response).to have_http_status(:forbidden)
    end

    it 'aislamiento: el admin de otra organización no ve ni toca el webhook ajeno' do
      ajeno = crear_webhook(create(:club))
      sign_in_as(admin)
      get '/webhooks'
      expect(JSON.parse(response.body).map { |w| w['id'] }).not_to include(ajeno.id)
      get "/webhooks/#{ajeno.id}"
      expect(response).to have_http_status(:not_found)
      delete "/webhooks/#{ajeno.id}"
      expect(Webhook.unscoped.exists?(ajeno.id)).to be true
    end
  end

  describe 'envío' do
    it 'si el dominio pasó a resolver a la red privada, no se conecta y no reintenta' do
      webhook = crear_webhook(club)
      allow(Seguridad::DestinoPublico).to receive(:direcciones).with('hooks.example').and_return(%w[127.0.0.1])
      expect(Net::HTTP).not_to receive(:new)

      ActsAsTenant.with_tenant(club) do
        expect { OutgoingWebhookService.new(webhook, 'lote.avanzado', { id: 1 }).call }.not_to raise_error
        entrega = webhook.webhook_deliveries.last
        expect(entrega.status).to eq('failed')
        expect(entrega.error_message).to include('no es una dirección pública')
      end
    end

    it 'se conecta a la IP validada y no guarda el cuerpo de la respuesta' do
      webhook = crear_webhook(club)
      http = Net::HTTP.new('hooks.example', 443)
      allow(Net::HTTP).to receive(:new).with('hooks.example', 443).and_return(http)
      respuesta = Net::HTTPInternalServerError.new('1.1', '500', 'Error')
      allow(respuesta).to receive(:body).and_return('SECRETO DEL SERVICIO INTERNO')
      allow(http).to receive(:request).and_return(respuesta)

      ActsAsTenant.with_tenant(club) do
        expect { OutgoingWebhookService.new(webhook, 'lote.avanzado', { id: 1 }).call }.to raise_error(/500/)
        entrega = webhook.webhook_deliveries.last
        expect(entrega.error_message).to eq('HTTP 500')
        expect(entrega.error_message).not_to include('SECRETO')
      end
      expect(http.ipaddr).to eq('93.184.215.14')
    end

    it 'el autocultivo no dispara webhooks aunque tenga alguno de antes' do
      personal = create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL)
      crear_webhook(personal)
      expect(OutgoingWebhookJob).not_to receive(:perform_later)
      WebhookDispatcher.dispatch(personal, 'lote.avanzado', { id: 1 })
    end

    it 'una organización sí los dispara' do
      webhook = crear_webhook(club)
      expect(OutgoingWebhookJob).to receive(:perform_later).with(webhook.id, 'lote.avanzado', { id: 1 })
      WebhookDispatcher.dispatch(club, 'lote.avanzado', { id: 1 })
    end
  end
end
