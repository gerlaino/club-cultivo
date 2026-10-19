require 'rails_helper'

# AC (Germán, 18 y 19-oct-2026): tres ejes —vínculo, REPROCANN, paciente—. El REPROCANN del
# VINCULADO lo calcula el sistema: pendiente de entrevista (nuevo sin REPROCANN, a ≤30 días de vencer
# o vencido) → pendiente de aprobación → activo → vencido; «No indicado» y «Rechazado» lo sacan del
# ciclo. El del ADHERENTE es el que se cargó, y no pide entrevista.
RSpec.describe Pacientes::Situacion do
  let(:hoy) { Date.new(2026, 10, 19) }

  def rep(estado:, numero: nil, vencimiento: nil, vinculo: 'organizacion')
    described_class.reprocann(estado: estado, numero: numero, vencimiento: vencimiento, vinculo: vinculo, hoy: hoy)
  end

  def entrevista?(estado:, numero: nil, vencimiento: nil, vinculo: 'organizacion')
    r = rep(estado: estado, numero: numero, vencimiento: vencimiento, vinculo: vinculo)
    described_class.pendiente_entrevista?(r, vencimiento: vencimiento, vinculo: vinculo, hoy: hoy)
  end

  describe 'vinculado' do
    it 'nuevo sin REPROCANN: pendiente de entrevista' do
      expect(rep(estado: 'sin_registro')).to eq('pendiente_entrevista')
      expect(entrevista?(estado: 'sin_registro')).to be(true)
    end

    it '«activo» sin número ni vencimiento todavía no tiene REPROCANN: pendiente de entrevista' do
      expect(rep(estado: 'activo')).to eq('pendiente_entrevista')
    end

    it 'con fecha cargada lo tiene, aunque falte el número: vencido si la fecha pasó' do
      expect(rep(estado: 'sin_registro', vencimiento: hoy - 5)).to eq('vencido')
      expect(rep(estado: 'sin_registro', vencimiento: hoy + 200)).to eq('activo')
    end

    it 'con el trámite iniciado: pendiente de aprobación, sin pedir entrevista' do
      expect(rep(estado: 'pendiente')).to eq('pendiente_aprobacion')
      expect(entrevista?(estado: 'pendiente')).to be(false)
    end

    it 'en trámite de renovación con la fecha vencida sigue pendiente de aprobación' do
      expect(rep(estado: 'pendiente', numero: 'R1', vencimiento: hoy - 5)).to eq('pendiente_aprobacion')
    end

    it 'vigente lejos del vencimiento: activo y sin entrevista' do
      expect(rep(estado: 'activo', numero: 'R1', vencimiento: hoy + 31)).to eq('activo')
      expect(entrevista?(estado: 'activo', numero: 'R1', vencimiento: hoy + 31)).to be(false)
    end

    it 'a 30 días o menos: sigue activo, pero ya pide entrevista' do
      expect(rep(estado: 'activo', numero: 'R1', vencimiento: hoy + 30)).to eq('activo')
      expect(entrevista?(estado: 'activo', numero: 'R1', vencimiento: hoy + 30)).to be(true)
      expect(described_class.vence_en_dias(hoy + 30, hoy: hoy)).to eq(30)
    end

    it 'vencido muestra los dos: vencido y pendiente de entrevista' do
      expect(rep(estado: 'activo', numero: 'R1', vencimiento: hoy - 1)).to eq('vencido')
      expect(entrevista?(estado: 'activo', numero: 'R1', vencimiento: hoy - 1)).to be(true)
      expect(rep(estado: 'vencido')).to eq('vencido') # marcado a mano, sin fecha
    end

    it 'sin dato de vínculo cuenta como vinculado' do
      expect(rep(estado: 'sin_registro', vinculo: nil)).to eq('pendiente_entrevista')
    end

    it 'no indicado y rechazado salen del ciclo y no piden entrevista' do
      %w[no_indicado rechazado].each do |e|
        expect(rep(estado: e, numero: 'R1', vencimiento: hoy - 10)).to eq(e)
        expect(entrevista?(estado: e)).to be(false)
      end
    end
  end

  describe 'adherente' do
    it 'activo como se cargó, aunque no tengamos su número, y sin entrevista' do
      expect(rep(estado: 'activo', vinculo: 'otra_organizacion')).to eq('activo')
      expect(entrevista?(estado: 'activo', vinculo: 'otra_organizacion')).to be(false)
    end

    it 'vencido o por vencer tampoco le pide entrevista: lo tramita su organización' do
      expect(entrevista?(estado: 'activo', numero: 'X', vencimiento: hoy - 3, vinculo: 'otra_organizacion')).to be(false)
      expect(entrevista?(estado: 'activo', numero: 'X', vencimiento: hoy + 3, vinculo: 'otra_organizacion')).to be(false)
    end

    it 'sin estado cargado: sin dato' do
      expect(rep(estado: 'sin_registro', vinculo: 'otra_organizacion')).to eq('sin_dato')
    end
  end

  describe 'paciente' do
    it 'activo / suspendido (90 días) / inactivo / sin aprobar' do
      expect(described_class.paciente(es_paciente: true,  aprobado: true,  ultima_dispensacion: hoy - 10, hoy: hoy)).to eq('activo')
      expect(described_class.paciente(es_paciente: true,  aprobado: true,  ultima_dispensacion: hoy - 91, hoy: hoy)).to eq('suspendido')
      expect(described_class.paciente(es_paciente: false, aprobado: true,  ultima_dispensacion: nil, hoy: hoy)).to eq('inactivo')
      expect(described_class.paciente(es_paciente: true,  aprobado: false, ultima_dispensacion: nil, hoy: hoy)).to eq('sin_aprobar')
    end
  end
end
