require 'rails_helper'

# Fase 2 del audit log: Paciente / User / Reserva. Lo crítico es la privacidad — que los campos
# cifrados y clínicos del paciente NUNCA lleguen al rastro (se auditan por allowlist).
RSpec.describe 'Auditable — Fase 2 (Paciente / User / Reserva)', type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  describe 'allowlists de privacidad' do
    it 'Paciente audita solo campos administrativos; nunca cifrados ni clínicos' do
      solo = Paciente.campos_auditables_solo
      expect(solo).to contain_exactly('nombre', 'apellido', 'fecha_nacimiento', 'reprocann_vencimiento', 'reprocann_estado')
      %w[dni reprocann_numero email telefono anamnesis notas_clinicas diagnostico_principal medicacion_habitual grupo_sanguineo].each do |prohibido|
        expect(solo).not_to include(prohibido)
      end
    end

    it 'User audita rol/identidad; nunca Devise ni campos cifrados' do
      solo = User.campos_auditables_solo
      expect(solo).to include('role')
      expect(solo).not_to include('dni', 'phone', 'encrypted_password', 'sign_in_count', 'last_sign_in_at', 'jti')
    end

    it 'Reserva se audita completa (sin allowlist)' do
      expect(Reserva.campos_auditables_solo).to be_nil
    end
  end

  describe 'wiring end-to-end' do
    it 'editar un Paciente audita el vencimiento REPROCANN pero NO la anamnesis (clínica)' do
      paciente = ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin) }
      Current.user = admin
      ActsAsTenant.with_tenant(club) do
        paciente.update!(reprocann_vencimiento: Date.new(2027, 1, 1), anamnesis: 'dato clínico sensible')
      end
      a = ActsAsTenant.with_tenant(club) { Auditoria.de(paciente).recientes.first }
      expect(a).to be_present
      expect(a.cambios.keys).to include('reprocann_vencimiento')
      expect(a.cambios.keys).not_to include('anamnesis')
    ensure
      Current.user = nil
    end

    it 'cambiar el rol de un User queda registrado' do
      otro = create(:user, :cultivador, club: club)
      Current.user = admin
      ActsAsTenant.with_tenant(club) { otro.update!(role: 'supervisor') }
      a = ActsAsTenant.with_tenant(club) { Auditoria.de(otro).recientes.first }
      expect(a.cambios['role']).to eq(%w[cultivador supervisor])
    ensure
      Current.user = nil
    end
  end
end
