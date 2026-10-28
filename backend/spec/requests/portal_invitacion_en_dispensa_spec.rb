require 'rails_helper'

# AC (Germán, 27-oct-2026): «la invitación al portal le llega por mail en la PRÓXIMA DISPENSA», con
# un tilde en el modal por las dudas. El tilde aparece si el portal está abierto, el paciente
# tiene mail, no lo activó y no tiene un link vigente; viene marcado salvo que ya se lo haya
# invitado en los últimos 30 días. Mandarlo nunca hace fallar a la dispensa.
RSpec.describe 'La invitación al portal en la dispensa', type: :request do
  let(:club) do
    create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:email)    { 'ana@example.com' }
  let(:paciente) do
    ActsAsTenant.with_tenant(club) do
      create(:paciente, club: club, nombre: 'Ana', apellido: 'Díaz', email: email, aprobado_at: Time.current, created_by: admin)
    end
  end
  let!(:frasco) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 50, precio_sugerido_ars: 100) }

  before do
    ActsAsTenant.with_tenant(club) { lote.update_columns(estado: 'curado', sala_id: nil, sede_id: sede.id) }
    sign_in_as(admin)
  end

  def t(&) = ActsAsTenant.with_tenant(club, &)
  def json = JSON.parse(response.body)
  def invitacion
    get "/api/pacientes/#{paciente.id}/acceso/invitacion"
    expect(response).to have_http_status(:ok), response.body
    json['data']
  end

  def dispensar(extra = {})
    post "/api/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: frasco.id, cantidad: 2, medio_pago: 'efectivo',
                                   fecha_dispensacion: Time.zone.today.to_s }.merge(extra) }, as: :json
    expect(response).to have_http_status(:created), response.body
  end

  describe 'cuándo se ofrece el tilde' do
    it 'con mail y sin activar: se ofrece marcado' do
      expect(invitacion).to eq('ofrecer' => true, 'marcada' => true)
    end

    it 'sin mail en la ficha no se ofrece' do
      paciente.update_column(:email, nil)
      expect(invitacion['ofrecer']).to be(false)
    end

    it 'si ya activó su portal no se ofrece' do
      t { AccesoPortal.emitir!(paciente).acceso.usar! }
      expect(invitacion['ofrecer']).to be(false)
    end

    it 'si tiene un link vigente (ya le llegó uno que sirve) no se ofrece' do
      t { AccesoPortal.emitir!(paciente) }
      expect(invitacion['ofrecer']).to be(false)
    end

    it 'invitado hace menos de 30 días y el link ya venció: se ofrece SIN marcar' do
      t { AccesoPortal.emitir!(paciente).acceso.update_columns(created_at: 10.days.ago, expira_at: 7.days.ago) }
      expect(invitacion).to eq('ofrecer' => true, 'marcada' => false)
    end

    it 'invitado hace más de 30 días: vuelve a venir marcado' do
      t { AccesoPortal.emitir!(paciente).acceso.update_columns(created_at: 40.days.ago, expira_at: 37.days.ago) }
      expect(invitacion).to eq('ofrecer' => true, 'marcada' => true)
    end

    it 'con el portal cerrado por la organización no se ofrece' do
      club.update!(vista_paciente_activa: false)
      expect(invitacion['ofrecer']).to be(false)
    end

    it 'el dispensador también lo ve: es quien dispensa' do
      sign_in_as(create(:user, :dispensador, club: club))
      expect(invitacion['ofrecer']).to be(true)
    end
  end

  describe 'al dispensar' do
    it 'con el tilde, le manda el mail con el link y la respuesta lo dice' do
      expect { dispensar(invitar_portal: true) }.to have_enqueued_mail(AccesoMailer, :portal_link)

      expect(json['invitacion_portal']).to eq('mail_enviado' => true)
      expect(t { paciente.accesos_portal.where(motivo: 'invitacion').count }).to eq(1)
      expect(t { paciente.accesos_portal.last.creado_por_id }).to eq(admin.id)
    end

    it 'sin el tilde no manda nada' do
      expect { dispensar }.not_to have_enqueued_mail(AccesoMailer, :portal_link)
      expect(json).not_to have_key('invitacion_portal')
    end

    it 'con el tilde pero sin mail en la ficha (la pantalla vieja lo mandó igual), no manda y la dispensa entra' do
      paciente.update_column(:email, nil)
      expect { dispensar(invitar_portal: true) }.not_to have_enqueued_mail(AccesoMailer, :portal_link)
      expect(json['invitacion_portal']).to be_nil
      expect(t { paciente.dispensaciones.count }).to eq(1)
    end

    it 'si mandar la invitación revienta, la dispensa queda igual' do
      allow(PortalAcceso::Invitar).to receive(:call).and_raise(StandardError, 'SMTP caído')

      dispensar(invitar_portal: true)

      expect(json['invitacion_portal']).to eq('mail_enviado' => false)
      expect(t { paciente.dispensaciones.count }).to eq(1)
    end
  end

  describe 'aislamiento entre organizaciones' do
    it 'no se puede preguntar por un paciente de otra organización' do
      otra = create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
      paciente
      sign_in_as(create(:user, :admin, club: otra))

      get "/api/pacientes/#{paciente.id}/acceso/invitacion"
      expect(response).to have_http_status(:not_found)
    end
  end
end
