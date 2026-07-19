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
      it 'no avanza por avanzar_fase! (cosecha es terminal del ciclo; pasa a manicura por asignación)' do
        lote = lote_en('cosecha')
        expect { lote.avanzar_fase! }.to raise_error(ArgumentError)
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

  # ── devolver_a_cosecha! ───────────────────────────────────────────────────

  describe '#devolver_a_cosecha!' do
    let(:manicurador) { create(:user, club: club, role: 'manicura') }

    def lote_en_manicura
      lote = lote_en('en_manicura')
      lote.update_column(:manicurador_id, manicurador.id)
      lote
    end

    it 'vuelve el lote a cosecha y lo desasigna' do
      lote = lote_en_manicura
      lote.devolver_a_cosecha!(devuelto_por: manicurador, motivo: 'sigue húmeda')
      lote.reload
      expect(lote.estado).to eq('cosecha')
      expect(lote.manicurador_id).to be_nil
    end

    it 'limpia el peso_seco del intento abortado (re-manicurado arranca limpio)' do
      lote   = lote_en_manicura
      planta = create(:plant, lote: lote, club: club, state: 'cosechado', peso_seco: 15)
      lote.devolver_a_cosecha!(devuelto_por: manicurador, motivo: 'sigue húmeda')
      expect(planta.reload.peso_seco).to be_nil
    end

    it 'crea una AlertaInterna manicura_devuelta dirigida al admin' do
      lote = lote_en_manicura
      expect {
        lote.devolver_a_cosecha!(devuelto_por: manicurador, motivo: 'sigue húmeda')
      }.to change { club.alertas_internas.where(tipo: 'manicura_devuelta', destinada_a_role: 'admin').count }.by(1)
    end

    it 'registra un lote_evento de cambio_estado con el motivo' do
      lote = lote_en_manicura
      lote.devolver_a_cosecha!(devuelto_por: manicurador, motivo: 'necesita más secado')
      evento = lote.lote_eventos.where(tipo: 'cambio_estado', estado_nuevo: 'cosecha').last
      expect(evento).to be_present
      expect(evento.descripcion).to include('necesita más secado')
    end

    it 'limpia las jornadas sin confirmar (borrador/enviado)' do
      lote = lote_en_manicura
      lote.pesajes_manicura.create!(club: club, manicurador: manicurador, fecha_pesaje: Date.current, estado: 'borrador')
      lote.devolver_a_cosecha!(devuelto_por: manicurador, motivo: 'sigue húmeda')
      expect(lote.pesajes_manicura.count).to eq(0)
    end

    it 'exige motivo' do
      lote = lote_en_manicura
      expect {
        lote.devolver_a_cosecha!(devuelto_por: manicurador, motivo: '  ')
      }.to raise_error(ArgumentError, /motivo/i)
    end

    it 'lanza error si el lote no está en manicura' do
      lote = lote_en('cosecha')
      expect {
        lote.devolver_a_cosecha!(devuelto_por: manicurador, motivo: 'x')
      }.to raise_error(ArgumentError, /manicura/)
    end

    it 'no permite devolver si ya hay un pesaje confirmado' do
      lote = lote_en_manicura
      create(:plant, lote: lote, club: club)
      pesaje = lote.pesajes_manicura.create!(club: club, manicurador: manicurador, fecha_pesaje: Date.current)
      pesaje.pesadas_plantas.create!(plant: lote.plants.first, peso_seco_g: 100)
      pesaje.enviar!
      pesaje.confirmar!(confirmado_por: admin, peso_confirmado_g: 100)
      # confirmar! sobre todas las plantas puede pasar el lote a curado; forzamos el estado
      # para probar la guarda de "pesaje confirmado" de devolver_a_cosecha! aisladamente.
      lote.update_column(:estado, 'en_manicura')
      expect {
        lote.devolver_a_cosecha!(devuelto_por: manicurador, motivo: 'sigue húmeda')
      }.to raise_error(RuntimeError, /confirmado/)
    end
  end

  # ── Flujo unificado de manicura (PesajeManicura → confirmar → finaliza) ──────

  describe 'flujo unificado de manicura' do
    let(:manicurador) { create(:user, club: club, role: 'manicura') }

    def lote_con_plantas(n)
      lote = lote_en('en_manicura')
      lote.update_column(:manicurador_id, manicurador.id)
      create_list(:plant, n, lote: lote, club: club)
      lote
    end

    def pesaje_por_qr(lote, plantas, peso_c_u)
      pesaje = lote.pesajes_manicura.create!(club: club, manicurador: manicurador, fecha_pesaje: Date.current)
      plantas.each { |pl| pesaje.pesadas_plantas.create!(plant: pl, peso_seco_g: peso_c_u) }
      pesaje
    end

    it 'confirmar un pesaje genera stock pendiente_asignacion (sin sede)' do
      lote = lote_con_plantas(2)
      pesaje = pesaje_por_qr(lote, lote.plants.to_a, 100)
      pesaje.enviar!
      expect {
        pesaje.confirmar!(confirmado_por: admin, peso_confirmado_g: 200)
      }.to change(Stock, :count).by(1)
      stock = Stock.last
      expect(stock.estado).to eq('pendiente_asignacion')
      expect(stock.sede_id).to be_nil
      expect(stock.cantidad.to_f).to eq(200.0)
      expect(stock.cantidad_inicial.to_f).to eq(200.0)
      expect(stock.forma_producto).to eq('flor_seca')
    end

    it 'al cubrir TODAS las plantas el lote pasa a curado' do
      lote = lote_con_plantas(2)
      pesaje = pesaje_por_qr(lote, lote.plants.to_a, 100)
      pesaje.enviar!
      pesaje.confirmar!(confirmado_por: admin, peso_confirmado_g: 200)
      expect(lote.reload.estado).to eq('curado')
    end

    it 'finaliza a curado aunque haya plantas descartadas (no cuentan en el total)' do
      lote = lote_con_plantas(4)
      # 2 descartadas (murieron): no se van a pesar nunca, no deben bloquear la finalización.
      lote.plants.first(2).each { |p| p.update!(state: 'descartada') }
      # Se pesan y confirman las 2 restantes.
      vivas  = lote.plants.where.not(state: 'descartada').to_a
      pesaje = pesaje_por_qr(lote, vivas, 100)
      pesaje.enviar!
      pesaje.confirmar!(confirmado_por: admin, peso_confirmado_g: 200)
      expect(lote.reload.estado).to eq('curado')
    end

    it 'un pesaje PARCIAL deja el lote en en_manicura' do
      lote = lote_con_plantas(4)
      pesaje = pesaje_por_qr(lote, lote.plants.first(2), 100)
      pesaje.enviar!
      pesaje.confirmar!(confirmado_por: admin, peso_confirmado_g: 200)
      expect(lote.reload.estado).to eq('en_manicura')
    end

    it 'dos pesajes parciales que cubren todo dejan el lote en curado' do
      lote = lote_con_plantas(4)
      p1 = pesaje_por_qr(lote, lote.plants.first(2), 100); p1.enviar!
      p1.confirmar!(confirmado_por: admin, peso_confirmado_g: 200)
      expect(lote.reload.estado).to eq('en_manicura')

      p2 = pesaje_por_qr(lote, lote.plants.last(2), 100); p2.enviar!
      p2.confirmar!(confirmado_por: admin, peso_confirmado_g: 200)
      expect(lote.reload.estado).to eq('curado')
    end

    it 'carga manual (sin QR) suma al stock y deja el lote en curado vía plantas_count' do
      lote = lote_con_plantas(3)
      pesaje = lote.pesajes_manicura.create!(club: club, manicurador: manicurador, fecha_pesaje: Date.current)
      pesaje.cargar_manual!(plantas: 3, peso: 300)
      pesaje.enviar!
      expect(pesaje.reload.estado).to eq('enviado')
      expect(pesaje.peso_total_g.to_f).to eq(300.0)
      expect {
        pesaje.confirmar!(confirmado_por: admin, peso_confirmado_g: 300)
      }.to change(Stock, :count).by(1)
      expect(lote.reload.estado).to eq('curado')
    end

    it 'enviar! sin plantas ni carga lanza error' do
      lote = lote_con_plantas(2)
      pesaje = lote.pesajes_manicura.create!(club: club, manicurador: manicurador, fecha_pesaje: Date.current)
      expect { pesaje.enviar! }.to raise_error(ArgumentError, /carga/)
    end

    it 'cargar_manual! sobre un pesaje con plantas por QR lanza error' do
      lote = lote_con_plantas(2)
      pesaje = pesaje_por_qr(lote, lote.plants.first(1), 100)
      expect { pesaje.cargar_manual!(plantas: 2, peso: 200) }.to raise_error(RuntimeError, /QR/)
    end
  end

end
