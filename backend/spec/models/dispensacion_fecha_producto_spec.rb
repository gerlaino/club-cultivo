require 'rails_helper'

# NO SE PUEDE ENTREGAR ALGO QUE TODAVÍA NO EXISTÍA.
#
# Cargando historia vieja es fácil poner el 10 de agosto en una dispensa cuyo producto se elaboró
# el 15, y eso rompe todo lo que se apoya en la línea de tiempo: la trazabilidad, el balance de
# producido − dispensado − merma, los informes de producción y lo que se le presenta a ARICCAME.
RSpec.describe 'La fecha de una dispensa contra la del producto', type: :model do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'social') }
  let(:lote)     { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  def stock_elaborado(fecha)
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas',
                     precio_sugerido_ars: 100, fecha_elaboracion: fecha)
    end
  end

  def dispensar(stock, fecha)
    ActsAsTenant.with_tenant(club) do
      Dispensacion.new(paciente: paciente, user: admin, stock: stock, sede: sede, cantidad: 10,
                       medio_pago: 'efectivo', aporte_socio_ars: 1_000, fecha_dispensacion: fecha)
    end
  end

  it 'rechaza una dispensa anterior a la elaboración, y dice las dos fechas' do
    stock = stock_elaborado(Time.zone.today - 5)
    d     = dispensar(stock, Time.zone.today - 20)

    expect(d).not_to be_valid
    expect(d.errors.full_messages.join(' ')).to include('recién existe desde el')
  end

  it 'acepta el mismo día que se elaboró' do
    stock = stock_elaborado(Time.zone.today - 5)

    expect(dispensar(stock, Time.zone.today - 5)).to be_valid
  end

  it 'acepta cualquier fecha posterior' do
    stock = stock_elaborado(Time.zone.today - 5)

    expect(dispensar(stock, Time.zone.today)).to be_valid
  end

  # Cuándo se cargó al sistema es otra cosa: una carga retroactiva es legítima, y validar contra
  # `created_at` dejaría afuera justo el trabajo de poner la historia al día.
  it 'sin fecha de elaboración no hay contra qué comparar: no bloquea' do
    stock = stock_elaborado(nil)

    expect(dispensar(stock, Time.zone.today - 30)).to be_valid
  end

  # Con varias líneas alcanza con que UNA no cierre: el producto de esa línea no existía.
  it 'en una dispensa multi-producto, mira todas las líneas' do
    viejo = stock_elaborado(Time.zone.today - 30)
    nuevo = stock_elaborado(Time.zone.today - 2)

    d = ActsAsTenant.with_tenant(club) do
      disp = Dispensacion.new(paciente: paciente, user: admin, stock: viejo, sede: sede,
                              cantidad: 20, medio_pago: 'efectivo', aporte_socio_ars: 2_000,
                              fecha_dispensacion: Time.zone.today - 10)
      disp.items.build(stock: viejo, cantidad: 10)
      disp.items.build(stock: nuevo, cantidad: 10)
      disp
    end

    expect(d).not_to be_valid
    expect(d.errors.full_messages.join(' ')).to include('recién existe desde el')
  end
end
