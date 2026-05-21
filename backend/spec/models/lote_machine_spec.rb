require 'rails_helper'

RSpec.describe Lote, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }

  def lote_en(estado)
    create(:lote, club: club, sala: sala, estado: estado, start_date: 30.days.ago)
  end

  # ── avanzar_fase! ─────────────────────────────────────────────────────────

  describe '#avanzar_fase!' do
    context 'lote en vegetativo' do
      it 'avanza a floracion' do
        lote = lote_en('vegetativo')
        lote.avanzar_fase!
        expect(lote.reload.estado).to eq('floracion')
      end
    end

    context 'lote en cosecha' do
      it 'avanza a secado' do
        lote = lote_en('cosecha')
        lote.avanzar_fase!
        expect(lote.reload.estado).to eq('secado')
      end
    end

    context 'lote en floracion' do
      it 'avanza a cosecha (sin pesada, usa avanzar_fase! — la restricción de pesada la aplica el controller)' do
        lote = lote_en('floracion')
        lote.avanzar_fase!
        expect(lote.reload.estado).to eq('cosecha')
      end
    end

    context 'lote en finalizado' do
      it 'lanza error' do
        lote = lote_en('finalizado')
        expect { lote.avanzar_fase! }.to raise_error(ArgumentError)
      end
    end
  end

  # ── transicionar! ─────────────────────────────────────────────────────────

  describe '#transicionar!' do
    let(:lote_floracion) { lote_en('floracion') }

    it 'transiciona de floracion a cosecha creando una pesada' do
      expect {
        lote_floracion.transicionar!(
          'cosecha',
          pesada_attrs: { registrado_por: admin, peso_humedo_g: 1000 }
        )
      }.to change(Pesada, :count).by(1)

      expect(lote_floracion.reload.estado).to eq('cosecha')
    end

    it 'crea la pesada con los datos correctos' do
      lote_floracion.transicionar!(
        'cosecha',
        pesada_attrs: { registrado_por: admin, peso_humedo_g: 1500 }
      )
      pesada = lote_floracion.pesadas.last
      expect(pesada.fase_origen).to eq('floracion')
      expect(pesada.fase_destino).to eq('cosecha')
      expect(pesada.peso_humedo_g.to_f).to eq(1500.0)
    end

    it 'lanza error si se intenta saltar una fase' do
      lote = lote_en('vegetativo')
      expect {
        lote.transicionar!('cosecha', pesada_attrs: { registrado_por: admin })
      }.to raise_error(RuntimeError)
    end

    it 'lanza error si falta registrado_por' do
      expect {
        lote_floracion.transicionar!('cosecha', pesada_attrs: {})
      }.to raise_error(ArgumentError, /registrado_por/)
    end

    it 'es transaccional: si falla la pesada no cambia el estado' do
      allow_any_instance_of(Pesada).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
      expect {
        lote_floracion.transicionar!(
          'cosecha',
          pesada_attrs: { registrado_por: admin, peso_humedo_g: 100 }
        )
      }.to raise_error(ActiveRecord::RecordInvalid)
      expect(lote_floracion.reload.estado).to eq('floracion')
    end
  end

  # ── asignar_manicurador! ──────────────────────────────────────────────────

  describe '#asignar_manicurador!' do
    let(:manicurador) { create(:user, club: club, role: 'manicura') }
    let(:lote_cosecha) { lote_en('cosecha') }

    it 'transiciona de cosecha a en_manicura y asigna el manicurador' do
      lote_cosecha.asignar_manicurador!(manicurador: manicurador, asignado_por: admin)
      lote_cosecha.reload
      expect(lote_cosecha.estado).to eq('en_manicura')
      expect(lote_cosecha.manicurador_id).to eq(manicurador.id)
    end

    it 'crea una AlertaInterna de tipo manicura_asignada' do
      expect {
        lote_cosecha.asignar_manicurador!(manicurador: manicurador, asignado_por: admin)
      }.to change { club.alertas_internas.where(tipo: 'manicura_asignada').count }.by(1)
    end

    it 'lanza error si el lote no está en cosecha' do
      lote = lote_en('vegetativo')
      expect {
        lote.asignar_manicurador!(manicurador: manicurador, asignado_por: admin)
      }.to raise_error(ArgumentError, /cosecha/)
    end

    it 'lanza error si el usuario no tiene rol de manicura' do
      cultivador = create(:user, :cultivador, club: club)
      expect {
        lote_cosecha.asignar_manicurador!(manicurador: cultivador, asignado_por: admin)
      }.to raise_error(ArgumentError, /rol/)
    end
  end

  # ── aprobar_manicura! ─────────────────────────────────────────────────────

  describe '#aprobar_manicura!' do
    let(:manicurador) { create(:user, club: club, role: 'manicura') }

    let!(:lote_pendiente) do
      lote = lote_en('manicura_pendiente')
      lote.update_column(:manicurador_id, nil)
      lote.pesadas.create!(
        fase_origen:    'secado',
        fase_destino:   'manicura_pendiente',
        manicurado:     true,
        registrado_por: admin,
        registrado_at:  Time.current,
        peso_seco_g:    500,
      )
      lote
    end

    it 'transiciona a curado' do
      lote_pendiente.aprobar_manicura!(aprobado_por: admin)
      expect(lote_pendiente.reload.estado).to eq('curado')
    end

    it 'registra aprobada_at en la pesada' do
      lote_pendiente.aprobar_manicura!(aprobado_por: admin)
      pesada = lote_pendiente.pesadas.where(manicurado: true).last
      expect(pesada.aprobada_at).to be_present
    end

    it 'lanza error si el lote no está en manicura_pendiente' do
      lote = lote_en('secado')
      expect {
        lote.aprobar_manicura!(aprobado_por: admin)
      }.to raise_error(RuntimeError, /manicura_pendiente/)
    end
  end

  # ── rechazar_manicura! ────────────────────────────────────────────────────

  describe '#rechazar_manicura!' do
    let!(:lote_pendiente) do
      lote = lote_en('manicura_pendiente')
      lote.update_column(:manicurador_id, nil)
      lote.pesadas.create!(
        fase_origen:    'secado',
        fase_destino:   'manicura_pendiente',
        manicurado:     true,
        registrado_por: admin,
        registrado_at:  Time.current,
        peso_seco_g:    500,
      )
      lote
    end

    it 'vuelve a secado cuando no hay manicurador asignado (flujo legacy)' do
      lote_pendiente.rechazar_manicura!(rechazado_por: admin, motivo: 'Peso incorrecto')
      expect(lote_pendiente.reload.estado).to eq('secado')
    end

    it 'registra rechazada_at y el motivo en la pesada' do
      lote_pendiente.rechazar_manicura!(rechazado_por: admin, motivo: 'Peso incorrecto')
      pesada = lote_pendiente.pesadas.where(manicurado: true).last
      expect(pesada.rechazada_at).to be_present
      expect(pesada.motivo_rechazo).to eq('Peso incorrecto')
    end

    it 'lanza error si el motivo está vacío' do
      expect {
        lote_pendiente.rechazar_manicura!(rechazado_por: admin, motivo: '')
      }.to raise_error(ArgumentError, /motivo/)
    end
  end

  # ── aprobar_y_finalizar! ──────────────────────────────────────────────────

  describe '#aprobar_y_finalizar!' do
    let!(:lote_pendiente) do
      lote = lote_en('manicura_pendiente')
      manicurador = create(:user, club: club, role: 'manicura')
      lote.update_column(:manicurador_id, manicurador.id)
      lote.pesadas.create!(
        fase_origen:    'en_manicura',
        fase_destino:   'manicura_pendiente',
        manicurado:     true,
        registrado_por: admin,
        registrado_at:  Time.current,
        peso_seco_g:    400,
      )
      lote
    end

    it 'finaliza el lote y crea un Stock' do
      expect {
        lote_pendiente.aprobar_y_finalizar!(aprobado_por: admin)
      }.to change(Stock, :count).by(1)

      expect(lote_pendiente.reload.estado).to eq('finalizado')
    end

    it 'el stock creado tiene el peso correcto' do
      lote_pendiente.aprobar_y_finalizar!(aprobado_por: admin)
      stock = Stock.last
      expect(stock.cantidad.to_f).to eq(400.0)
      expect(stock.forma_producto).to eq('flor_seca')
    end

    it 'lanza error si el lote no está en manicura_pendiente' do
      lote = lote_en('en_manicura')
      expect {
        lote.aprobar_y_finalizar!(aprobado_por: admin)
      }.to raise_error(RuntimeError)
    end
  end

  # ── completar_manicura_directa! ───────────────────────────────────────────

  describe '#completar_manicura_directa!' do
    let!(:lote_en_manicura) do
      manicurador = create(:user, club: club, role: 'manicura')
      lote = lote_en('en_manicura')
      lote.update_column(:manicurador_id, manicurador.id)
      lote
    end

    it 'finaliza el lote, crea pesada y stock en un solo paso' do
      expect {
        lote_en_manicura.completar_manicura_directa!(
          registrado_por: admin,
          peso_seco_g:    350,
          sede_id:        sede.id,
        )
      }.to change(Stock, :count).by(1)
        .and change(Pesada, :count).by(1)

      expect(lote_en_manicura.reload.estado).to eq('finalizado')
    end

    it 'lanza error si el peso es 0' do
      expect {
        lote_en_manicura.completar_manicura_directa!(
          registrado_por: admin,
          peso_seco_g:    0,
          sede_id:        sede.id,
        )
      }.to raise_error(ArgumentError, /peso/)
    end
  end

  # ── cerrar_curado! ────────────────────────────────────────────────────────

  describe '#cerrar_curado!' do
    let!(:lote_curado) do
      lote = lote_en('curado')
      # peso_seco_g requerido por validación de Pesada; peso_curado_g requerido por cerrar_curado!
      lote.pesadas.create!(
        fase_origen:    'secado',
        fase_destino:   'curado',
        manicurado:     false,
        registrado_por: admin,
        registrado_at:  Time.current,
        peso_seco_g:    300,
        peso_curado_g:  300,
      )
      lote
    end

    it 'finaliza el lote y crea un Stock de flor_seca' do
      expect {
        lote_curado.cerrar_curado!(
          splitter:            { flor_seca: 270, descarte: 30 },
          sede_destino_id:     sede.id,
          costo_unitario_ars:  50,
          precio_sugerido_ars: 100,
          registrado_por:      admin,
        )
      }.to change(Stock, :count).by(1)

      expect(lote_curado.reload.estado).to eq('finalizado')
    end

    it 'lanza error si el splitter no coincide con el peso curado' do
      expect {
        lote_curado.cerrar_curado!(
          splitter:            { flor_seca: 200, descarte: 50 },
          sede_destino_id:     sede.id,
          costo_unitario_ars:  50,
          precio_sugerido_ars: 100,
          registrado_por:      admin,
        )
      }.to raise_error(RuntimeError, /splitter/)
    end

    it 'lanza error si el lote no está en curado' do
      lote = lote_en('secado')
      expect {
        lote.cerrar_curado!(
          splitter:            { flor_seca: 100, descarte: 0 },
          sede_destino_id:     sede.id,
          costo_unitario_ars:  50,
          precio_sugerido_ars: 100,
          registrado_por:      admin,
        )
      }.to raise_error(RuntimeError, /curado/)
    end
  end
end
