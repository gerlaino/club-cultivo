require 'rails_helper'

RSpec.describe EventoBar, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:bar)   { club.bares.create!(sede: sede, nombre: 'La Terraza') }
  let(:evento) { bar.eventos_bar.create!(club: club, nombre: 'Cata', fecha: Date.current, presupuesto_ingresos: 500_000) }

  before { ActsAsTenant.current_tenant = club }
  after  { ActsAsTenant.current_tenant = nil }

  def costo(attrs = {})
    evento.costos.create!({ club: club, created_by: admin, concepto: 'DJ', monto_ars: 180_000 }.merge(attrs))
  end

  describe 'costo pagado ↔ egreso en el libro' do
    it 'no genera egreso si no está pagado' do
      expect { costo(pagado: false) }.not_to change { club.movimientos_contables.count }
    end

    it 'genera un egreso etiquetado con el evento y la sede al marcarlo pagado' do
      c = costo(pagado: false)
      expect { c.update!(pagado: true) }.to change { club.movimientos_contables.egresos.count }.by(1)
      mov = c.reload.movimiento_contable
      expect(mov.evento_bar_id).to eq(evento.id)
      expect(mov.sede_id).to eq(sede.id)
      expect(mov.monto_ars).to eq(180_000)
    end

    it 'saca el egreso al despagarlo' do
      c = costo(pagado: true)
      expect { c.update!(pagado: false) }.to change { club.movimientos_contables.egresos.count }.by(-1)
    end

    it 'saca el egreso al borrar el costo' do
      c = costo(pagado: true)
      expect { c.destroy }.to change { club.movimientos_contables.egresos.count }.by(-1)
    end
  end

  describe 'P&L del evento' do
    it 'resultado real = ingresos − egresos del libro etiquetados' do
      costo(pagado: true, monto_ars: 100_000)  # egreso
      club.movimientos_contables.create!(created_by: admin, tipo: 'ingreso', categoria: 'otro',
        sede: sede, evento_bar_id: evento.id, descripcion: 'Entradas', monto_ars: 300_000,
        fecha: Date.current, pagado: true)
      r = evento.reload.resultado
      expect(r[:ingresos]).to eq(300_000)
      expect(r[:egresos]).to eq(100_000)
      expect(r[:resultado]).to eq(200_000)
    end

    it 'resultado proyectado = presupuesto ingresos − costos comprometidos' do
      costo(pagado: false, monto_ars: 180_000)
      costo(pagado: false, concepto: 'Seguridad', monto_ars: 92_000)
      expect(evento.reload.resultado_proyectado).to eq(500_000 - 272_000)
    end

    it 'el resultado descuenta el costo de la mercadería consumida (COGS)' do
      club.movimientos_contables.create!(created_by: admin, tipo: 'ingreso', categoria: 'otro',
        sede: sede, evento_bar_id: evento.id, descripcion: 'Barra', monto_ars: 100_000,
        fecha: Date.current, pagado: true)
      prod = create(:bar_producto, club: club, bar: bar, costo_ars: 500)
      evento.provisiones.create!(club: club, provisionable: prod,
        cantidad_prevista: 30, cantidad_reservada: 30, cantidad_consumida: 20) # 20 × $500 = $10.000
      r = evento.reload.resultado
      expect(r[:cogs]).to eq(10_000)
      expect(r[:resultado]).to eq(90_000) # 100.000 ingreso − 10.000 COGS
    end
  end

  describe 'borrar y restaurar un evento' do
    it 'al restaurar vuelve con sus costos y re-crea los egresos pagados' do
      costo(pagado: true, monto_ars: 180_000)
      evento.destroy
      expect(club.movimientos_contables.egresos.count).to eq(0)

      res = Restore::Restorers::EventoBar.call(EventoBar.with_deleted.find(evento.id), usuario: admin)
      expect(res.ok?).to be(true)
      expect(club.movimientos_contables.egresos.where(evento_bar_id: evento.id).count).to eq(1)
    end
  end
end
