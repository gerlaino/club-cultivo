require 'rails_helper'
require 'rake'

# AC (20-oct-2026): el código de un lote es único dentro de la organización. La mudanza conserva el
# código; si el destino ya tiene ese código, no muda nada y dice cuáles chocan.
RSpec.describe 'rake cultivo:mudar — códigos de lote' do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'cultivo:mudar' } }

  let(:origen)  { create(:club, features: { 'cultivo' => true }) }
  let(:destino) { create(:club, features: { 'cultivo' => true }) }
  let(:admin_o) { create(:user, :admin, club: origen) }
  let(:admin_d) { create(:user, :admin, club: destino) }
  let!(:sede_d) { ActsAsTenant.with_tenant(destino) { create(:sede, club: destino, created_by: admin_d, tipo: 'produccion') } }
  let!(:lote) do
    ActsAsTenant.with_tenant(origen) do
      create(:lote, club: origen, codigo: 'L-26-001', sala: create(:sala, club: origen, created_by: admin_o))
    end
  end

  def correr
    ENV['ORIGEN'] = origen.id.to_s
    ENV['DESTINO'] = destino.id.to_s
    ENV['SEDE_DESTINO'] = sede_d.id.to_s
    ENV['SIMULAR'] = '1'
    Rake::Task['cultivo:mudar'].reenable
    salida = StringIO.new
    $stdout = salida
    begin
      Rake::Task['cultivo:mudar'].invoke
    rescue SystemExit
      # `abort` es la forma en que el rake frena
    ensure
      $stdout = STDOUT
    end
    salida.string
  ensure
    %w[ORIGEN DESTINO SEDE_DESTINO SIMULAR].each { |k| ENV.delete(k) }
  end

  it 'si el destino ya tiene ese código, frena y lo nombra' do
    ActsAsTenant.with_tenant(destino) do
      create(:lote, club: destino, codigo: 'L-26-001', sala: create(:sala, club: destino, created_by: admin_d, sede: sede_d))
    end

    expect(correr).to include('ya existen en el destino: L-26-001')
    expect(lote.reload.club_id).to eq(origen.id)
  end

  it 'si el código está libre en el destino, no lo menciona' do
    expect(correr).not_to include('ya existen en el destino')
  end
end
