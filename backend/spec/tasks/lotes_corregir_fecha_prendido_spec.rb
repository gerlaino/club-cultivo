require 'rails_helper'
require 'rake'

# AC (Germán): los lotes que ya se trasplantaron con fecha pasada tienen que quedar en vegetativo
# desde el día del trasplante, no desde el día en que se cargó.
RSpec.describe 'rake lotes:corregir_fecha_prendido' do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'lotes:corregir_fecha_prendido' } }

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }

  around do |ex|
    ActsAsTenant.with_tenant(club) do
      Current.user = admin
      ex.run
    ensure
      Current.user = nil
    end
  end

  def lote_enraizando
    lote = create(:lote, club: club, sala: sala, estado: 'enraizado')
    create(:plant, lote: lote, club: club, state: 'enraizado')
    lote.reload
  end

  # Como quedó con el código viejo: el trasplante con su fecha, el prendido con la de la carga.
  def lote_con_el_bug(dia)
    lote = lote_enraizando
    Lotes::RegistrarTrasplante.call(lote: lote, usuario: admin, destino: '0.335', fecha: dia.to_s)
    lote.lote_eventos.find_by(tipo: 'cambio_estado', estado_nuevo: 'vegetativo')
        .update_columns(registrado_en: Time.current)
    lote.reload
  end

  def correr(env = {})
    env.each { |k, v| ENV[k] = v }
    Rake::Task['lotes:corregir_fecha_prendido'].reenable
    expect { Rake::Task['lotes:corregir_fecha_prendido'].invoke }.to output.to_stdout
  ensure
    env.each_key { |k| ENV.delete(k) }
  end

  it 'con CONFIRMAR, el lote queda en vegetativo desde el día del trasplante' do
    dia  = 6.days.ago.to_date
    lote = lote_con_el_bug(dia)
    expect(lote.fecha_inicio_vegetativo).to eq(Time.zone.today)

    correr('CONFIRMAR' => '1')

    expect(lote.reload.fecha_inicio_vegetativo).to eq(dia)
  end

  it 'sin CONFIRMAR no cambia nada' do
    lote = lote_con_el_bug(6.days.ago.to_date)

    correr

    expect(lote.reload.fecha_inicio_vegetativo).to eq(Time.zone.today)
  end

  # Maceta puesta a mano desde la edición: no hay trasplante y la fecha de carga es la correcta.
  it 'no toca un lote que prendió editando la maceta' do
    lote = lote_enraizando
    lote.update!(tamanio_maceta: 1)
    antes = lote.lote_eventos.find_by(tipo: 'cambio_estado').registrado_en

    correr('CONFIRMAR' => '1')

    expect(lote.lote_eventos.find_by(tipo: 'cambio_estado').reload.registrado_en).to eq(antes)
  end

  # Un trasplante registrado más tarde, cuando el lote ya estaba en vegetativo, no es el que lo prendió.
  it 'no usa un trasplante posterior de otra operación' do
    lote = lote_enraizando
    lote.update!(tamanio_maceta: 1)
    prendido = lote.lote_eventos.find_by(tipo: 'cambio_estado')
    prendido.update_columns(created_at: 2.days.ago, registrado_en: 2.days.ago)
    Lotes::RegistrarTrasplante.call(lote: lote, usuario: admin, destino: '3', fecha: 10.days.ago.to_date.to_s)

    correr('CONFIRMAR' => '1')

    expect(prendido.reload.registrado_en.to_date).to eq(2.days.ago.to_date)
  end
end
