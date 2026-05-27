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
      fecha_dispensacion: Date.today,
      medio_pago: 'efectivo',
    }.merge(attrs))
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
      expect(d.fecha_dispensacion).to eq(Date.today)
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

    it 'rechaza si el aporte supera el margen total (saldo + límite)' do
      d = nueva_dispensacion(medio_pago: 'cuenta_corriente', aporte_socio_ars: 500)
      expect(d).not_to be_valid
      expect(d.errors[:base]).to be_present
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
end
