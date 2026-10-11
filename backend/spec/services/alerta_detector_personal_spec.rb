require 'rails_helper'

# AC (11-oct-2026, Germán): lo que es autocultivo tiene que estar hecho para ese uso, sin tocar lo
# de organizaciones. Los avisos (campana y teléfono) no hablan de lotes ni de códigos: nombran las
# plantas por su genética. En una organización el texto sigue igual, con el código del lote.
RSpec.describe AlertaDetectorService, '— textos del autocultivo' do
  let(:club)     { create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL) }
  let(:sala)     { create(:sala, club: club) }
  let(:user)     { create(:user, :admin, club: club) }
  let(:genetica) { create(:genetica, club: club, nombre: 'Gorilla Glue') }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  def mensajes = club.alertas_internas.reload.pluck(:mensaje)

  it 'el hito de vegetativo nombra la genética y no el código del lote' do
    lote = create(:lote, club: club, sala: sala, genetica: genetica, estado: 'vegetativo',
                         start_date: 28.days.ago, dias_vegetativo_objetivo: 30)

    described_class.new(club).detectar!

    hito = club.alertas_internas.find_by(tipo: 'hito_cultivo')
    expect(hito.mensaje).to start_with('Tus plantas de Gorilla Glue llegan a los 30 días')
    expect(hito.mensaje).not_to include(lote.codigo)
  end

  it 'el ambiente sin anotar habla de la fase con su nombre, sin el estado crudo' do
    lote = create(:lote, club: club, sala: sala, genetica: genetica, estado: 'floracion', start_date: 60.days.ago)

    described_class.new(club).detectar!

    aviso = club.alertas_internas.find_by(tipo: 'sin_registro_ambiental')
    expect(aviso.mensaje).to include('tus plantas de Gorilla Glue').and include('en floración')
    expect(aviso.mensaje).not_to include(lote.codigo)
    expect(aviso.mensaje).not_to include('999')
  end

  it 'ningún aviso del autocultivo menciona un lote' do
    create(:lote, club: club, sala: sala, genetica: genetica, estado: 'vegetativo',
                  start_date: 28.days.ago, dias_vegetativo_objetivo: 30)

    described_class.new(club).detectar!

    expect(mensajes).not_to be_empty
    mensajes.each { |m| expect(m).not_to match(/\blote\b|L-\d/i) }
  end

  it 'en una organización el aviso sigue con el código del lote' do
    org = create(:club, plan: 'basico', features: { 'cultivo' => true })
    ActsAsTenant.with_tenant(org) do
      lote = create(:lote, club: org, sala: create(:sala, club: org), estado: 'floracion', start_date: 60.days.ago)

      described_class.new(org).detectar!

      expect(org.alertas_internas.find_by(tipo: 'sin_registro_ambiental').mensaje).to start_with(lote.codigo)
    end
  end
end
