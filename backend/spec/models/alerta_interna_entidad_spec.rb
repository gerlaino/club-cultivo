require 'rails_helper'

# El deep-link del panel de notificaciones usa AlertaInterna#entidad = { tipo:, id: },
# derivado de `tipo` + `contexto` (+ lote_id). Un caso de cada familia de entidad.
RSpec.describe AlertaInterna, '#entidad' do
  # require_tenant=true: instanciar el modelo necesita un tenant fijado (lo pone el hook
  # global de spec/support/tenant.rb al ver este let). `entidad` no consulta la DB.
  let(:club) { create(:club) }

  def entidad(tipo, contexto: {}, lote_id: nil)
    described_class.new(tipo: tipo, contexto: contexto, lote_id: lote_id).entidad
  end

  it 'cosecha pendiente → lote (por lote_id)' do
    expect(entidad('cosecha_pendiente', lote_id: 7)).to eq(tipo: 'lote', id: 7)
  end

  it 'umbral ambiental fuera de rango → lote' do
    expect(entidad('ph_fuera_rango', lote_id: 3)).to eq(tipo: 'lote', id: 3)
  end

  it 'tarea vencida → tarea (por contexto)' do
    expect(entidad('tarea_vencida_cultivo', contexto: { 'tarea_id' => 12 })).to eq(tipo: 'tarea', id: 12)
  end

  it 'reserva por entregar → reserva' do
    expect(entidad('reserva_por_entregar', contexto: { 'reserva_id' => 44, 'paciente_id' => 9 }))
      .to eq(tipo: 'reserva', id: 44)
  end

  it 'reprocann vencido → paciente' do
    expect(entidad('reprocann_vencido', contexto: { 'paciente_id' => 21 })).to eq(tipo: 'paciente', id: 21)
  end

  it 'stock bajo → stock (por sede)' do
    expect(entidad('stock_bajo', contexto: { 'sede_id' => 5 })).to eq(tipo: 'stock', id: 5)
  end

  it 'manicura pendiente de aprobación → manicura (por lote_id)' do
    expect(entidad('manicura_aprobacion_pendiente', lote_id: 8, contexto: { 'lote_id' => 8 }))
      .to eq(tipo: 'manicura', id: 8)
  end

  it 'delivery fallido → delivery' do
    expect(entidad('delivery_fallido', contexto: { 'dispensacion_id' => 33 })).to eq(tipo: 'delivery', id: 33)
  end

  it 'tipo sin entidad navegable → nil' do
    expect(entidad('otro')).to be_nil
  end
end
