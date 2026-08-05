require 'rails_helper'

# El AC de este spec es la regla de negocio acordada, no el callback:
# la duración del tratamiento PROPONE el vencimiento, pero una fecha escrita a mano GANA.
RSpec.describe IndicacionMedica, type: :model do
  let(:club)   { create(:club) }
  let(:medico) { create(:user, :admin, club: club) }
  let(:pac)    { create(:paciente, club: club, created_by: medico) }

  def nueva(attrs = {})
    described_class.new({
      paciente: pac, user: medico,
      patologia: 'Dolor crónico', dosificacion: '0,5 ml cada 12 h',
      via_administracion: 'sublingual',
    }.merge(attrs))
  end

  describe 'alta' do
    it 'deriva el vencimiento de la duración cuando no se indica fecha' do
      ind = nueva(fecha_emision: Date.new(2026, 1, 10), duracion_dias: 90)
      ind.save!

      expect(ind.fecha_vencimiento).to eq(Date.new(2026, 4, 10))
      expect(ind).to be_vencimiento_calculado
    end

    it 'respeta la fecha escrita a mano aunque haya duración' do
      ind = nueva(fecha_emision: Date.new(2026, 1, 10), duracion_dias: 90,
                  fecha_vencimiento: Date.new(2026, 12, 31))
      ind.save!

      expect(ind.fecha_vencimiento).to eq(Date.new(2026, 12, 31))
      expect(ind).not_to be_vencimiento_calculado
    end

    it 'deja la indicación sin vencimiento si no hay duración ni fecha' do
      ind = nueva(fecha_emision: Date.new(2026, 1, 10))
      ind.save!

      expect(ind.fecha_vencimiento).to be_nil
      expect(ind).not_to be_vencimiento_calculado
    end
  end

  describe 'edición' do
    it 'recalcula el vencimiento cuando cambia la duración' do
      ind = nueva(fecha_emision: Date.new(2026, 1, 10), duracion_dias: 90)
      ind.save!

      ind.update!(duracion_dias: 30)

      expect(ind.fecha_vencimiento).to eq(Date.new(2026, 2, 9))
    end

    it 'NO pisa el vencimiento al editar cualquier otro campo' do
      ind = nueva(fecha_emision: Date.new(2026, 1, 10), duracion_dias: 90,
                  fecha_vencimiento: Date.new(2026, 12, 31))
      ind.save!

      ind.update!(dosificacion: '1 ml cada 12 h')

      expect(ind.fecha_vencimiento).to eq(Date.new(2026, 12, 31))
    end

    it 'deja ganar a la fecha escrita a mano por sobre la duración vigente' do
      ind = nueva(fecha_emision: Date.new(2026, 1, 10), duracion_dias: 90)
      ind.save!
      expect(ind.fecha_vencimiento).to eq(Date.new(2026, 4, 10))

      ind.update!(fecha_vencimiento: Date.new(2026, 6, 30))

      expect(ind.fecha_vencimiento).to eq(Date.new(2026, 6, 30))
      expect(ind.duracion_dias).to eq(90)
    end
  end

  describe 'estado según el vencimiento' do
    it 'marca vencida la que quedó atrás y por vencer la que entra en 30 días' do
      vencida    = nueva(fecha_emision: 120.days.ago.to_date, duracion_dias: 90).tap(&:save!)
      por_vencer = nueva(fecha_emision: Date.today, duracion_dias: 10).tap(&:save!)

      expect(vencida).to be_vencida
      expect(por_vencer).to be_por_vencer
      expect(por_vencer.dias_hasta_vencimiento).to eq(10)
    end

    it 'no considera vencida ni por vencer a la que no tiene fecha' do
      sin_fecha = nueva.tap(&:save!)

      expect(sin_fecha).not_to be_vencida
      expect(sin_fecha).not_to be_por_vencer
    end
  end
end
