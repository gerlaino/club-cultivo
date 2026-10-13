require 'rails_helper'

# AC (Germán, 12-oct-2026): cobro recurrente con Mercado Pago.
#   · super admin genera un link POR ORGANIZACIÓN con un monto propio de esa organización;
#   · el autocultivo se suscribe solo, con un precio FIJO que se carga en super admin;
#   · la verdad vive en nuestra base y la alimenta el webhook de MP (firmado, idempotente, y
#     volviendo a pedirle el dato a MP): cada cobro aprobado extiende el plan y despausa.
RSpec.describe 'Suscripciones con Mercado Pago', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  # Mercado Pago de mentira: guarda lo que se le pidió y contesta lo que se le diga.
  let(:mp_falso) do
    Class.new do
      attr_reader :pedidos
      attr_accessor :preapprovals, :pagos

      def initialize = (@pedidos = []; @preapprovals = {}; @pagos = {}; @n = 0)

      def crear_preapproval(cuerpo)
        @pedidos << [:crear, cuerpo]
        @n += 1
        { 'id' => "pre_#{@n}", 'status' => 'pending', 'init_point' => "https://mp.test/sub/pre_#{@n}" }
      end
      def actualizar_preapproval(id, c) = (@pedidos << [:actualizar, id, c]; { 'id' => id })
      def preapproval(id) = @preapprovals.fetch(id)
      def authorized_payment(id) = @pagos.fetch(id)
    end
  end

  let(:mp) { mp_falso.new }
  let(:super_admin) { create(:user, :super_admin, club: nil) }
  let(:club) { create(:club, name: 'Mitocondria') }

  before do
    allow(Pagos::MercadoPago).to receive(:new).and_return(mp)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('MP_ACCESS_TOKEN').and_return('TEST-token')
    allow(ENV).to receive(:[]).with('MP_WEBHOOK_SECRET').and_return('secreto')
  end

  describe 'super admin: link por organización con su monto' do
    before { sign_in_as(super_admin) }

    it 'arma la suscripción en pesos, a nombre de la organización, y devuelve el link' do
      post "/api/super_admin/clubs/#{club.id}/suscripcion", params: { monto_ars: 350_000, payer_email: 'Pagos@Mito.org' }, as: :json

      expect(response).to have_http_status(:created), response.body
      expect(json).to include('estado' => 'pendiente', 'monto_ars' => 350_000.0, 'link' => 'https://mp.test/sub/pre_1',
                              'payer_email' => 'pagos@mito.org')
      cuerpo = mp.pedidos.first[1]
      expect(cuerpo[:external_reference]).to eq("club-#{club.id}")
      expect(cuerpo[:auto_recurring]).to include(transaction_amount: 350_000.0, currency_id: 'ARS', frequency_type: 'months')
    end

    it 'generar otro link cancela el anterior: no cobran dos a la vez' do
      post "/api/super_admin/clubs/#{club.id}/suscripcion", params: { monto_ars: 300_000, payer_email: 'a@b.org' }, as: :json
      post "/api/super_admin/clubs/#{club.id}/suscripcion", params: { monto_ars: 350_000, payer_email: 'a@b.org' }, as: :json

      expect(club.suscripciones.vivas.count).to eq(1)
      expect(mp.pedidos).to include([:actualizar, 'pre_1', { status: 'cancelled' }])
    end

    it 'sin Mercado Pago configurado no arma nada y lo dice' do
      allow(ENV).to receive(:[]).with('MP_ACCESS_TOKEN').and_return(nil)
      post "/api/super_admin/clubs/#{club.id}/suscripcion", params: { monto_ars: 1000, payer_email: 'a@b.org' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].join).to include('no está configurado')
    end

    it 'el precio del autocultivo lo carga super admin' do
      put '/api/super_admin/precio_autocultivo', params: { monto_ars: 9_900 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(AjustePlataforma.precio_autocultivo_ars).to eq(9_900)
    end
  end

  it 'nadie más que super admin genera links ni toca el precio' do
    sign_in_as(create(:user, :admin, club: club))

    post "/api/super_admin/clubs/#{club.id}/suscripcion", params: { monto_ars: 1, payer_email: 'a@b.org' }, as: :json
    expect(response).to have_http_status(:forbidden)
    put '/api/super_admin/precio_autocultivo', params: { monto_ars: 1 }, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  describe 'el webhook' do
    let!(:sus) { club.suscripciones.create!(mp_preapproval_id: 'pre_9', estado: 'pendiente', origen: 'organizacion', monto_ars: 1000, payer_email: 'a@b.org', motivo: 'x') }

    def avisar(tipo, id, secreto: 'secreto')
      ts = '1700000000'
      v1 = OpenSSL::HMAC.hexdigest('SHA256', secreto, "id:#{id};request-id:req-1;ts:#{ts};")
      post "/webhooks/mercado_pago?type=#{tipo}&data.id=#{id}",
           params: { type: tipo, data: { id: id } }.to_json,
           headers: { 'Content-Type' => 'application/json', 'x-signature' => "ts=#{ts},v1=#{v1}", 'x-request-id' => 'req-1' }
    end

    it 'sin firma válida no toca nada' do
      mp.preapprovals['pre_9'] = { 'id' => 'pre_9', 'status' => 'authorized' }
      avisar('subscription_preapproval', 'pre_9', secreto: 'otro')

      expect(response).to have_http_status(:unauthorized)
      expect(sus.reload.estado).to eq('pendiente')
    end

    it 'la suscripción autorizada queda activa, según lo que dice MP y no el aviso' do
      mp.preapprovals['pre_9'] = { 'id' => 'pre_9', 'status' => 'authorized' }
      avisar('subscription_preapproval', 'pre_9')

      expect(response).to have_http_status(:ok)
      expect(sus.reload.estado).to eq('activa')
    end

    describe 'un cobro mensual' do
      let(:hoy) { Time.zone.today }

      before do
        club.update!(plan_trial: true, plan_activo_hasta: hoy - 2)
        club.suspender!(motivo: 'prueba_terminada')
        mp.pagos['777'] = { 'id' => 777, 'preapproval_id' => 'pre_9', 'transaction_amount' => 1000,
                            'date_created' => Time.current.iso8601, 'payment' => { 'id' => 1, 'status' => 'approved' } }
      end

      it 'aprobado: extiende el plan un mes (con 3 días de gracia), deja de ser prueba y despausa' do
        avisar('subscription_authorized_payment', '777')

        expect(response).to have_http_status(:ok)
        club.reload
        expect(club.plan_activo_hasta).to eq(hoy + 1.month + 3)
        expect(club.plan_trial).to be(false)
        expect(club.activo).to be(true)
        expect(sus.reload.estado).to eq('activa')
      end

      it 'el mismo aviso dos veces cuenta una sola' do
        2.times { avisar('subscription_authorized_payment', '777') }

        expect(sus.cobros.count).to eq(1)
        expect(club.reload.plan_activo_hasta).to eq(hoy + 1.month + 3)
      end

      it 'el mes siguiente se cuenta desde lo pagado, no desde la gracia' do
        avisar('subscription_authorized_payment', '777')
        mp.pagos['778'] = mp.pagos['777'].merge('id' => 778)
        avisar('subscription_authorized_payment', '778')

        expect(club.reload.plan_activo_hasta).to eq(hoy + 2.months + 3)
      end

      it 'rechazado: queda anotado y no extiende ni despausa' do
        mp.pagos['777']['payment']['status'] = 'rejected'
        avisar('subscription_authorized_payment', '777')

        expect(sus.cobros.first.estado).to eq('rejected')
        expect(club.reload.activo).to be(false)
        expect(club.plan_activo_hasta).to eq(hoy - 2)
      end
    end
  end

  describe 'autocultivo: se suscribe solo, al precio fijo' do
    let(:casa)  { create(:club, plan: 'personal', features: { 'cultivo' => true }) }
    let(:dueño) { create(:user, :admin, club: casa, email: 'yo@casa.com') }

    before do
      AjustePlataforma.escribir!(AjustePlataforma::PRECIO_AUTOCULTIVO, { 'monto' => '9900' })
      sign_in_as(dueño)
    end

    it 'con la prueba terminada (cuenta pausada) igual puede ver y suscribirse' do
      casa.suspender!(motivo: 'prueba_terminada')

      get '/api/suscripcion'
      expect(response).to have_http_status(:ok)
      expect(json).to include('precio_ars' => 9900.0, 'mp_configurado' => true)

      post '/api/suscripcion', params: { payer_email: 'mi.mp@gmail.com' }, as: :json
      expect(response).to have_http_status(:created), response.body
      expect(mp.pedidos.first[1][:auto_recurring][:transaction_amount]).to eq(9900.0)
    end

    it 'el monto no lo elige la persona' do
      post '/api/suscripcion', params: { payer_email: 'mi.mp@gmail.com', monto_ars: 1 }, as: :json

      expect(json['monto_ars']).to eq(9900.0)
    end

    it 'pausada por otra cosa (no confirmó el mail), no' do
      casa.suspender!(motivo: 'mail_sin_confirmar')
      get '/api/suscripcion'

      expect(response).to have_http_status(:forbidden)
    end

    it 'una organización no se suscribe sola: su link lo genera super admin' do
      sign_in_as(create(:user, :admin, club: club))
      post '/api/suscripcion', params: { payer_email: 'a@b.org' }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
