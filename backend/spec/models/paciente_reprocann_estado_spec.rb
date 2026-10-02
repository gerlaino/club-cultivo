require 'rails_helper'
require 'rake'

# AC (Germán, 2-oct-2026): «el REPROCANN es pendiente de aprobación, vigente, sin registro…
# activo e inactivo se refiere al estado del paciente dentro de la organización». El formulario
# ofrecía «Inactivo» como estado del REPROCANN y eso no existe.
RSpec.describe 'Paciente — estados del REPROCANN' do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  def paciente(**attrs) = create(:paciente, club: club, created_by: admin, **attrs)

  it 'acepta los tres estados reales: sin registro, pendiente y vigente (activo)' do
    %w[sin_registro pendiente activo].each do |e|
      expect(paciente(reprocann_estado: e)).to be_persisted
    end
  end

  it '«inactivo» ya no se puede guardar como estado del REPROCANN' do
    p = build(:paciente, club: club, created_by: admin, reprocann_estado: 'inactivo')
    expect(p).not_to be_valid
    expect(p.errors[:reprocann_estado]).to be_present
  end

  it 'vencido sale de la fecha, no se guarda' do
    p = paciente(reprocann_estado: 'activo', reprocann_numero: 'RP-1', reprocann_vencimiento: 3.days.ago.to_date)
    expect(p.reprocann_estado_efectivo).to eq('vencido')
  end

  it 'un paciente que ya tenía «inactivo» se puede seguir editando (hasta pasar el rake)' do
    p = paciente
    p.update_column(:reprocann_estado, 'inactivo')
    expect(p.reload.update(telefono: '1122334455')).to be(true)
  end

  describe 'rake reprocann:sin_inactivo' do
    before { Rails.application.load_tasks if Rake::Task.tasks.empty? }

    def correr(env = {})
      env.each { |k, v| ENV[k] = v }
      salida = StringIO.new
      viejo, $stdout = $stdout, salida
      Rake::Task['reprocann:sin_inactivo'].execute
      salida.string
    ensure
      $stdout = viejo
      env.each_key { |k| ENV.delete(k) }
    end

    it 'en seco sólo lista; con CONFIRMAR: con número → vigente, sin número → sin registro' do
      con_numero = paciente(reprocann_numero: 'RP-9').tap { |x| x.update_column(:reprocann_estado, 'inactivo') }
      sin_numero = paciente(dni: '30999888').tap { |x| x.update_columns(reprocann_estado: 'inactivo', reprocann_numero: nil) }

      expect(correr).to include("paciente ##{con_numero.id}", "paciente ##{sin_numero.id}")
      expect(con_numero.reload.reprocann_estado).to eq('inactivo')

      correr('CONFIRMAR' => '1')
      expect(con_numero.reload.reprocann_estado).to eq('activo')
      expect(sin_numero.reload.reprocann_estado).to eq('sin_registro')
    end

    it 'no toca el estado del paciente en la organización' do
      p = paciente(reprocann_numero: 'RP-9').tap { |x| x.update_columns(reprocann_estado: 'inactivo', es_paciente: false) }
      correr('CONFIRMAR' => '1')
      expect(p.reload.es_paciente).to be(false)
    end
  end
end
