require 'rails_helper'

RSpec.describe Dispensacion, type: :model do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  let!(:stock) do
    Stock.create!(
      sede: sede, lote: lote,
      origen: 'lote', forma_producto: 'flor_seca',
      unidad: 'g', cantidad: 100
    )
  end

  def nueva_dispensacion(attrs = {})
    Dispensacion.new({
      paciente: paciente,
      user:     admin,
      stock:    stock,
      cantidad: 10,
      fecha_dispensacion: Time.zone.today,
      medio_pago: 'efectivo',
    }.merge(attrs))
  end

  describe 'movimiento de stock vinculado' do
    it 'crea el movimiento con dispensacion_id y lo borra al eliminar la dispensación' do
      d = nueva_dispensacion(cantidad: 10)
      d.save!
      mov = stock.stock_movimientos.where(tipo: 'dispensacion', dispensacion_id: d.id)
      expect(mov.count).to eq(1)
      expect(stock.reload.cantidad).to eq(90)

      d.destroy
      expect(stock.stock_movimientos.where(dispensacion_id: d.id)).to be_empty
      expect(stock.reload.cantidad).to eq(100)
    end
  end

  # ── validaciones ──────────────────────────────────────────────────────────

  describe 'validaciones' do
    it 'es válida con datos correctos' do
      expect(nueva_dispensacion).to be_valid
    end

    it 'requiere cantidad > 0' do
      expect(nueva_dispensacion(cantidad: 0)).not_to be_valid
    end

    it 'asigna fecha_dispensacion automáticamente si es nil (before_validation)' do
      d = nueva_dispensacion(fecha_dispensacion: nil)
      d.valid?
      # Date.current (no Time.zone.today) para coincidir con la zona horaria del modelo
      expect(d.fecha_dispensacion).to eq(Date.current)
    end

    it 'no permite fecha futura' do
      d = nueva_dispensacion(fecha_dispensacion: 2.days.from_now)
      expect(d).not_to be_valid
      expect(d.errors[:fecha_dispensacion]).to be_present
    end
  end

  # ── stock_disponible ──────────────────────────────────────────────────────

  describe 'validación stock_disponible' do
    it 'rechaza cantidad mayor al stock disponible' do
      d = nueva_dispensacion(cantidad: 999)
      expect(d).not_to be_valid
      expect(d.errors[:cantidad]).to be_present
    end

    it 'acepta cantidad exactamente igual al stock' do
      expect(nueva_dispensacion(cantidad: 100)).to be_valid
    end

    it 'acepta cantidad menor al stock' do
      expect(nueva_dispensacion(cantidad: 50)).to be_valid
    end
  end

  # ── credito_suficiente ────────────────────────────────────────────────────

  describe 'validación credito_suficiente (medio_pago: cuenta_corriente)' do
    before do
      CuentaCorriente.create!(
        paciente: paciente, club: club,
        saldo_disponible: 200, limite_credito: 200
      )
    end

    it 'acepta si el aporte está dentro del crédito disponible' do
      d = nueva_dispensacion(medio_pago: 'cuenta_corriente', aporte_socio_ars: 300)
      expect(d).to be_valid
    end

    it 'ya NO rechaza por exceder el crédito: la diferencia se cobra ahora (split)' do
      # El reparto crédito/efectivo lo resuelve el controller (monto_credito_ars);
      # el modelo solo exige aporte > 0 para cuenta corriente.
      d = nueva_dispensacion(medio_pago: 'cuenta_corriente', aporte_socio_ars: 500)
      expect(d).to be_valid
    end

    it 'no valida crédito si medio_pago es efectivo' do
      d = nueva_dispensacion(medio_pago: 'efectivo', aporte_socio_ars: 9999)
      expect(d).to be_valid
    end
  end

  # ── decrementar_stock / incrementar_stock ─────────────────────────────────

  describe 'callbacks de stock' do
    it 'decrementa el stock al crear la dispensación' do
      expect {
        nueva_dispensacion(cantidad: 15).save!
      }.to change { stock.reload.cantidad.to_f }.from(100.0).to(85.0)
    end

    it 'restaura el stock al destruir la dispensación' do
      d = nueva_dispensacion(cantidad: 20)
      d.save!
      expect {
        d.destroy
      }.to change { stock.reload.cantidad.to_f }.from(80.0).to(100.0)
    end
  end

  # ── delivery fields ───────────────────────────────────────────────────────

  describe 'validaciones de delivery' do
    it 'requiere dirección y contacto cuando con_envio es true' do
      d = nueva_dispensacion(con_envio: true)
      expect(d).not_to be_valid
      expect(d.errors[:direccion_envio]).to be_present
      expect(d.errors[:contacto_nombre]).to be_present
    end

    it 'NO requiere delivery_id al crear — se asigna después por el admin' do
      d = nueva_dispensacion(
        con_envio:       true,
        direccion_envio: 'Calle 123',
        contacto_nombre: 'Juan Pérez',
      )
      expect(d).to be_valid
    end

    it 'es válida con todos los campos de envío incluyendo delivery_id' do
      delivery = create(:user, :delivery, club: club)
      d = nueva_dispensacion(
        con_envio:       true,
        direccion_envio: 'Calle 123',
        contacto_nombre: 'Juan Pérez',
        delivery_id:     delivery.id,
      )
      expect(d).to be_valid
    end
  end

  # ── limite_mensual_no_superado ────────────────────────────────────────────

  describe 'validación limite_mensual_no_superado' do
    context 'paciente con límite mensual configurado' do
      before { paciente.update!(limite_dispensacion_mensual_g: 30) }

      it 'acepta si la cantidad está dentro del límite' do
        expect(nueva_dispensacion(cantidad: 25)).to be_valid
      end

      it 'acepta exactamente el límite completo' do
        expect(nueva_dispensacion(cantidad: 30)).to be_valid
      end

      it 'rechaza si la cantidad supera el límite' do
        d = nueva_dispensacion(cantidad: 31)
        expect(d).not_to be_valid
        expect(d.errors[:cantidad]).to be_present
      end

      it 'acumula lo ya dispensado en el mes al calcular el restante' do
        nueva_dispensacion(cantidad: 20).save!
        d = nueva_dispensacion(cantidad: 15)
        expect(d).not_to be_valid
        expect(d.errors[:cantidad].first).to include('10.0 g disponibles')
      end

      it 'no bloquea si la dispensa del mes es de otro mes' do
        nueva_dispensacion(cantidad: 20, fecha_dispensacion: 1.month.ago.to_date).save!
        expect(nueva_dispensacion(cantidad: 25)).to be_valid
      end
    end

    context 'paciente sin límite mensual configurado' do
      it 'no aplica restricción cuando limite_dispensacion_mensual_g es nil' do
        paciente.update!(limite_dispensacion_mensual_g: nil)
        expect(nueva_dispensacion(cantidad: 99)).to be_valid
      end

      it 'no aplica restricción cuando limite_dispensacion_mensual_g es 0' do
        paciente.update!(limite_dispensacion_mensual_g: 0)
        expect(nueva_dispensacion(cantidad: 99)).to be_valid
      end
    end
  end

  # ── stock_pertenece_al_club ───────────────────────────────────────────────

  describe 'validación stock_pertenece_al_club' do
    let(:otro_club) { create(:club) }
    let(:otro_admin) { create(:user, :admin, club: otro_club) }
    let(:otra_sede) { create(:sede, club: otro_club, created_by: otro_admin) }
    let(:otra_sala) { create(:sala, club: otro_club, sede: otra_sede, created_by: otro_admin) }
    let(:otro_lote) { create(:lote, club: otro_club, sala: otra_sala) }
    let!(:stock_ajeno) do
      ActsAsTenant.with_tenant(otro_club) do
        Stock.create!(
          sede: otra_sede, lote: otro_lote,
          origen: 'lote', forma_producto: 'flor_seca',
          unidad: 'g', cantidad: 50
        )
      end
    end

    it 'rechaza stock de otro club' do
      d = nueva_dispensacion(stock: stock_ajeno)
      expect(d).not_to be_valid
      expect(d.errors[:stock]).to be_present
    end

    it 'acepta stock del mismo club' do
      expect(nueva_dispensacion(stock: stock)).to be_valid
    end
  end

  # ── carrito multi-item: fallo parcial ─────────────────────────────────────
  # El frontend procesa items del carrito con requests independientes (no hay
  # transacción HTTP cross-request). Si el segundo item falla, el primero ya
  # está persistido. Este spec documenta ese comportamiento conocido.

  describe 'carrito multi-item con fallo parcial' do
    it 'el primer item se persiste aunque el segundo falle por stock insuficiente' do
      stock.update!(cantidad: 10)

      primera = nueva_dispensacion(cantidad: 7)
      primera.save!
      expect(primera).to be_persisted
      expect(stock.reload.cantidad.to_f).to eq(3.0)

      segunda = nueva_dispensacion(cantidad: 5)  # supera los 3g restantes
      expect(segunda).not_to be_valid
      expect(segunda.errors[:cantidad]).to be_present

      # El primer item NO se revierte — comportamiento esperado y documentado
      expect(Dispensacion.count).to eq(1)
      expect(stock.reload.cantidad.to_f).to eq(3.0)
    end
  end

  # ── paciente_activo_como_socio ────────────────────────────────────────────

  describe 'validación paciente_activo_como_socio' do
    it 'acepta dispensar a un paciente activo' do
      expect(nueva_dispensacion).to be_valid
    end

    it 'rechaza dispensar a un paciente dado de baja (es_paciente: false)' do
      paciente.update!(es_paciente: false)
      d = nueva_dispensacion
      expect(d).not_to be_valid
      expect(d.errors[:base]).to include('El socio no está activo en la organización')
    end

    it 'solo aplica on: :create (no bloquea update de dispensa existente)' do
      d = nueva_dispensacion
      d.save!
      paciente.update!(es_paciente: false)
      d.aporte_socio_ars = 50
      expect(d).to be_valid
    end
  end

  # ── scopes ────────────────────────────────────────────────────────────────

  describe 'scopes' do
    let!(:dispensa_este_mes) { nueva_dispensacion(cantidad: 5, fecha_dispensacion: Time.zone.today).tap(&:save!) }
    let!(:dispensa_mes_pasado) do
      nueva_dispensacion(cantidad: 3, fecha_dispensacion: 1.month.ago.to_date).tap(&:save!)
    end

    describe '.del_mes' do
      it 'incluye dispensaciones del mes actual' do
        expect(Dispensacion.del_mes).to include(dispensa_este_mes)
      end

      it 'excluye dispensaciones de otros meses' do
        expect(Dispensacion.del_mes).not_to include(dispensa_mes_pasado)
      end

      it 'acepta fecha explícita para consultar otro mes' do
        fecha = 1.month.ago.to_date
        expect(Dispensacion.del_mes(fecha)).to include(dispensa_mes_pasado)
        expect(Dispensacion.del_mes(fecha)).not_to include(dispensa_este_mes)
      end
    end

    describe '.con_envio' do
      let!(:con_env) do
        nueva_dispensacion(
          cantidad: 2,
          con_envio: true,
          direccion_envio: 'Av. Siempreviva 742',
          contacto_nombre: 'Homero',
        ).tap(&:save!)
      end

      it 'devuelve solo dispensaciones con envío' do
        expect(Dispensacion.con_envio).to include(con_env)
        expect(Dispensacion.con_envio).not_to include(dispensa_este_mes)
      end
    end

    describe '.pendientes_envio' do
      let!(:pendiente) do
        nueva_dispensacion(
          cantidad: 2,
          con_envio: true,
          direccion_envio: 'Calle 1',
          contacto_nombre: 'Alguien',
        ).tap(&:save!)
      end
      let!(:entregada) do
        d = nueva_dispensacion(
          cantidad: 2,
          con_envio: true,
          direccion_envio: 'Calle 2',
          contacto_nombre: 'Otro',
        )
        d.save!
        d.update_column(:estado_envio, 'entregado')
        d
      end

      it 'incluye solo los con estado_envio pendiente' do
        expect(Dispensacion.pendientes_envio).to include(pendiente)
        expect(Dispensacion.pendientes_envio).not_to include(entregada)
        expect(Dispensacion.pendientes_envio).not_to include(dispensa_este_mes)
      end
    end
  end

  # ── gramos_suficientes ────────────────────────────────────────────────────

  describe 'validación gramos_suficientes (medio_pago: credito_gramos)' do
    before do
      CuentaCorriente.create!(
        paciente: paciente, club: club,
        credito_gramos_activo: true,
        saldo_disponible_g:    50,
        limite_credito_g:      50,
      )
    end

    it 'acepta si la cantidad está dentro del saldo en gramos' do
      d = nueva_dispensacion(medio_pago: 'credito_gramos', cantidad: 30)
      expect(d).to be_valid
    end

    it 'rechaza si la cantidad supera el saldo disponible en gramos' do
      d = nueva_dispensacion(medio_pago: 'credito_gramos', cantidad: 60)
      expect(d).not_to be_valid
      expect(d.errors[:cantidad]).to be_present
    end

    it 'rechaza cuando el saldo en gramos es 0' do
      paciente.cuenta_corriente.update!(saldo_disponible_g: 0)
      d = nueva_dispensacion(medio_pago: 'credito_gramos', cantidad: 5)
      expect(d).not_to be_valid
      expect(d.errors[:base]).to be_present
    end

    it 'no aplica si medio_pago no es credito_gramos' do
      d = nueva_dispensacion(medio_pago: 'efectivo', cantidad: 99)
      expect(d).to be_valid
    end
  end

  # ── generar_codigo_paquete ────────────────────────────────────────────────

  describe 'callback generar_codigo_paquete' do
    it 'genera código de paquete al crear con con_envio: true' do
      d = nueva_dispensacion(
        con_envio: true,
        direccion_envio: 'Av. 9 de Julio 100',
        contacto_nombre: 'Contacto',
      )
      d.save!
      expect(d.codigo_paquete).to match(/\APKG-\d{8}-[A-F0-9]{6}\z/)
    end

    it 'asigna estado_envio pendiente al crear con con_envio: true' do
      d = nueva_dispensacion(
        con_envio: true,
        direccion_envio: 'Av. 9 de Julio 100',
        contacto_nombre: 'Contacto',
      )
      d.save!
      expect(d.estado_envio).to eq('pendiente')
    end

    it 'no genera código de paquete cuando con_envio es false' do
      d = nueva_dispensacion
      d.save!
      expect(d.codigo_paquete).to be_nil
    end
  end

  # ── encolar_reporte_ariccame ──────────────────────────────────────────────

  describe 'callback encolar_reporte_ariccame' do
    context 'club con feature ariccame activa' do
      before { allow(paciente.club).to receive(:feature?).with(:ariccame).and_return(true) }

      it 'encola ReportarAriccameJob al crear la dispensación' do
        expect {
          nueva_dispensacion.save!
        }.to have_enqueued_job(ReportarAriccameJob)
      end
    end

    context 'club sin feature ariccame' do
      before { allow(paciente.club).to receive(:feature?).with(:ariccame).and_return(false) }

      it 'no encola ningún job' do
        expect {
          nueva_dispensacion.save!
        }.not_to have_enqueued_job(ReportarAriccameJob)
      end
    end
  end
end
