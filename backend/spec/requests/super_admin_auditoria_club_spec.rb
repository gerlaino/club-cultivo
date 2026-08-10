require 'rails_helper'

# AC: todo lo que el panel de plataforma le hace a un club queda registrado.
#
# Hasta ahora NADA lo registraba: `Club` no era auditable y ninguna acción de super_admin dejaba
# rastro. Cuando un club reclamaba "yo no pedí que me cambien el plan" o "¿por qué se me apagó
# el Buffet?", no había forma de saber quién ni cuándo. Con una sola persona operando era una
# molestia; con dos es una discusión sin árbitro.
RSpec.describe 'Auditoría de club', type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:club)        { create(:club, name: 'Club Auditado') }

  before { sign_in_as(super_admin) }

  def auditorias(accion: nil)
    scope = ActsAsTenant.without_tenant { Auditoria.where(auditable_type: 'Club', auditable_id: club.id) }
    accion ? scope.where(accion: accion) : scope
  end

  it 'registra quién cambió el plan y a qué' do
    patch "/api/super_admin/clubs/#{club.id}/cambiar_plan",
          params: { plan: 'total' }, as: :json

    a = auditorias(accion: 'actualizar').last
    expect(a.user_id).to eq(super_admin.id)
    expect(a.cambios['plan']).to eq(%w[basico total])
  end

  it 'registra el módulo que se prendió' do
    patch "/api/super_admin/clubs/#{club.id}",
          params: { club: { features: { 'cultivo' => true, 'produccion_dispensa' => true, 'ariccame' => true } } },
          as: :json

    a = auditorias(accion: 'actualizar').last
    expect(a.cambios).to have_key('features')
    expect(a.cambios['features'].last['ariccame']).to be(true)
  end

  it 'registra la suspensión y la reactivación' do
    patch "/api/super_admin/clubs/#{club.id}/suspender"
    patch "/api/super_admin/clubs/#{club.id}/reactivar"

    cambios = auditorias(accion: 'actualizar').map { |a| a.cambios['activo'] }.compact
    expect(cambios).to include([true, false], [false, true])
  end

  it 'registra la baja del club' do
    delete "/api/super_admin/clubs/#{club.id}"

    a = auditorias(accion: 'actualizar').last
    expect(a.cambios['deleted_at'].last).to be_present
  end

  it 'registra el alta' do
    post '/api/super_admin/clubs',
         params: { club: { name: 'Recién creado', email: 'nuevo@club.test' } }, as: :json

    id = JSON.parse(response.body)['club']['id']
    a  = ActsAsTenant.without_tenant { Auditoria.find_by(auditable_type: 'Club', auditable_id: id, accion: 'crear') }

    expect(a).to be_present
    expect(a.user_id).to eq(super_admin.id)
  end

  # Lo más importante de la allowlist: el rastro NO puede convertirse en un lugar donde queden
  # credenciales en claro.
  it 'nunca registra credenciales' do
    patch "/api/super_admin/clubs/#{club.id}/provisionar_whatsapp",
          params: { twilio_account_sid: 'AC123', twilio_auth_token: 'SECRETO_TWILIO',
                    twilio_whatsapp_from: '+5491100000000' }, as: :json
    patch "/api/super_admin/clubs/#{club.id}/provisionar_pulse",
          params: { pulse_api_key: 'SECRETO_PULSE' }, as: :json

    registrado = auditorias.map { |a| a.cambios.to_s }.join(' ')

    expect(registrado).not_to include('SECRETO_TWILIO', 'SECRETO_PULSE', 'AC123')
    Club::CAMPOS_NUNCA_AUDITADOS.each do |campo|
      expect(auditorias.map { |a| a.cambios.keys }.flatten).not_to include(campo)
    end
  end

  it 'el club puede ver su propio historial' do
    patch "/api/super_admin/clubs/#{club.id}/suspender"

    expect(auditorias.first.club_id).to eq(club.id)
  end
end
