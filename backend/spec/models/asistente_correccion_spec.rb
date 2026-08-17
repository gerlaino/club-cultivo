require 'rails_helper'

# AC: se puede saber, con un número, qué tan bien interpreta el dictado — y qué tuvo que corregir
# la gente, que es lo que después deja enseñarle el vocabulario de cada organización.
#
# Antes la corrección se tiraba: la única evidencia de que el asistente andaba bien era que nadie
# se quejaba.
RSpec.describe AsistenteCorreccion do
  let(:club)  { create(:club) }
  let(:user)  { create(:user, :cultivador, club: club) }

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  def propuesta(acciones, texto: 'regué el lote con EC uno ocho')
    described_class.create!(club: club, user: user, texto: texto,
                            propuesto: { 'acciones' => acciones })
  end

  let(:riego) { [{ 'tipo' => 'registro_ambiental', 'datos' => { 'ec' => 1.8 } }] }

  describe '#confirmar!' do
    it 'guardar sin tocar nada NO cuenta como corrección' do
      c = propuesta(riego)

      c.confirmar!(riego)

      expect(c.hubo_correccion).to be(false)
      expect(c.ejecutado_en).to be_present
    end

    it 'cambiar un dato cuenta como corrección' do
      c = propuesta(riego)

      c.confirmar!([{ 'tipo' => 'registro_ambiental', 'datos' => { 'ec' => 1.4 } }])

      expect(c.hubo_correccion).to be(true)
    end

    it 'quitar una acción cuenta como corrección' do
      c = propuesta(riego + [{ 'tipo' => 'nota_lote', 'datos' => { 'contenido' => 'x' } }])

      c.confirmar!(riego)

      expect(c.hubo_correccion).to be(true)
    end

    it 'destildar una tarea cuenta como corrección' do
      # El caso concreto que motivó todo: se propusieron tres tareas y se confirmó una.
      con_tareas = [{ 'tipo' => 'registro_ambiental',
                      'datos' => { 'ec' => 1.8, 'tareas_cerrar_ids' => [1, 2, 3] } }]
      c = propuesta(con_tareas)

      c.confirmar!([{ 'tipo' => 'registro_ambiental',
                      'datos' => { 'ec' => 1.8, 'tareas_cerrar_ids' => [1] } }])

      expect(c.hubo_correccion).to be(true)
    end

    it 'lo que agrega la pantalla y no decidió nadie no cuenta' do
      # `_expandido` es estado de la UI: que el panel esté abierto no es una corrección.
      c = propuesta(riego)

      c.confirmar!([{ 'tipo' => 'registro_ambiental', 'datos' => { 'ec' => 1.8, '_expandido' => true } }])

      expect(c.hubo_correccion).to be(false)
    end
  end

  describe '.precision_del_mes' do
    it 'mide sobre lo que se guardó, no sobre lo que se propuso' do
      propuesta(riego).confirmar!(riego)                                   # sin tocar
      propuesta(riego).confirmar!([{ 'tipo' => 'nota_lote', 'datos' => {} }]) # corregido
      propuesta(riego)                                                     # nunca se guardó

      r = described_class.precision_del_mes(club)

      # El dictado que nadie guardó queda afuera: no dice si interpretó bien, dice que la persona
      # cambió de idea. Meterlo ensuciaría justo la métrica que queremos mirar.
      expect(r[:dictados]).to eq(2)
      expect(r[:sin_tocar]).to eq(1)
      expect(r[:precision]).to eq(50.0)
    end

    it 'sin datos no inventa un número' do
      expect(described_class.precision_del_mes(club)).to be_nil
    end

    it 'no mezcla organizaciones' do
      otro_club = create(:club)
      ActsAsTenant.with_tenant(otro_club) do
        described_class.create!(club: otro_club, user: create(:user, :cultivador, club: otro_club),
                                texto: 'x', propuesto: { 'acciones' => riego })
                       .confirmar!(riego)
      end

      expect(described_class.precision_del_mes(club)).to be_nil
    end
  end
end
