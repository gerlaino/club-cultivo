require 'rails_helper'

# Fase 3 del refactor multi-stock: una sola dispensación puede abarcar varios stocks (líneas).
RSpec.describe 'Dispensación multi-stock', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente)    { create(:paciente, club: club, created_by: admin) }
  let!(:stock_a) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }
  let!(:stock_b) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'hash',      unidad: 'g', cantidad: 50,  precio_sugerido_ars: 200) }

  before { sign_in_as(dispensador) }

  def crear(items, extra = {})
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { medio_pago: 'efectivo', items: items }.merge(extra) },
         headers: auth_headers
  end

  it 'crea UNA dispensa con varias líneas, descuenta cada stock y suma el total' do
    crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 5 }])

    expect(response).to have_http_status(:created)
    d = Dispensacion.last
    expect(d.items.count).to eq(2)
    expect(d.multi_stock?).to be true
    expect(d.cantidad_total).to eq(15)                       # 10 + 5
    expect(d.aporte_socio_ars).to eq(2000)                   # 10*100 + 5*200
    expect(stock_a.reload.cantidad).to eq(90)                # descontó su línea
    expect(stock_b.reload.cantidad).to eq(45)
  end

  it 'cada línea guarda su propio snapshot de trazabilidad' do
    crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 5 }])
    d = Dispensacion.last
    expect(d.items.map(&:lote_codigo).uniq).to eq([lote.codigo])
  end

  it 'bloquea si una línea excede el stock disponible y no descuenta nada' do
    crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 999 }])

    expect(response).to have_http_status(:unprocessable_entity)
    expect(stock_a.reload.cantidad).to eq(100)               # rollback total
    expect(stock_b.reload.cantidad).to eq(50)
  end

  it 'al borrar la dispensa multi-stock, revierte el stock de todas las líneas' do
    crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 5 }])
    d = Dispensacion.last
    d.destroy
    expect(stock_a.reload.cantidad).to eq(100)
    expect(stock_b.reload.cantidad).to eq(50)
  end

  # Precio manual para stock sin precio configurado.
  describe 'precio manual (stock sin precio)' do
    let!(:stock_sp) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: nil) }

    def crear_como(user, items)
      delete '/api/users/sign_out'
      sign_in_as(user)
      post "/pacientes/#{paciente.id}/dispensaciones",
           params: { dispensacion: { medio_pago: 'efectivo', items: items } },
           headers: auth_headers
    end

    it 'el admin fija el precio y con guardar_precio lo persiste en el stock' do
      crear_como(admin, [{ stock_id: stock_sp.id, cantidad: 10, precio_manual_ars: 150, guardar_precio: true }])
      expect(response).to have_http_status(:created)
      expect(Dispensacion.last.aporte_socio_ars).to eq(1500)      # 10 * 150
      expect(stock_sp.reload.precio_sugerido_ars).to eq(150)      # guardado en el producto
    end

    it 'sin guardar_precio usa el precio pero NO lo persiste en el stock' do
      crear_como(admin, [{ stock_id: stock_sp.id, cantidad: 10, precio_manual_ars: 150 }])
      expect(response).to have_http_status(:created)
      expect(Dispensacion.last.aporte_socio_ars).to eq(1500)
      expect(stock_sp.reload.precio_sugerido_ars).to be_nil
    end

    it 'el dispensador NO puede fijar precio manual (no toca el stock)' do
      crear_como(dispensador, [{ stock_id: stock_sp.id, cantidad: 10, precio_manual_ars: 150 }])
      expect(stock_sp.reload.precio_sugerido_ars).to be_nil
    end
  end

  # Fase 2: edición por ítem — reconstruye líneas y reconcilia stock/total.
  describe 'edición multi-ítem' do
    def editar(d, items)
      patch "/dispensaciones/#{d.id}",
            params: { dispensacion: { items: items } },
            headers: auth_headers
    end

    it 'reconstruye las líneas, reconcilia el stock y recalcula el total' do
      crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 5 }])
      d = Dispensacion.last                                   # a:90, b:45
      editar(d, [{ stock_id: stock_a.id, cantidad: 20 }, { stock_id: stock_b.id, cantidad: 5 }])
      expect(response).to have_http_status(:ok)
      expect(d.reload.items.count).to eq(2)
      expect(d.aporte_socio_ars).to eq(3000)                 # 20*100 + 5*200
      expect(stock_a.reload.cantidad).to eq(80)              # devolvió 10, descontó 20
      expect(stock_b.reload.cantidad).to eq(45)              # sin cambio neto
    end

    it 'puede quitar un ítem y devuelve su stock' do
      crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 5 }])
      d = Dispensacion.last
      editar(d, [{ stock_id: stock_a.id, cantidad: 10 }])
      expect(response).to have_http_status(:ok)
      expect(d.reload.items.count).to eq(1)
      expect(stock_a.reload.cantidad).to eq(90)
      expect(stock_b.reload.cantidad).to eq(50)              # devuelto completo
    end

    it 'bloquea si una línea nueva excede el stock y hace rollback total' do
      crear([{ stock_id: stock_a.id, cantidad: 10 }])
      d = Dispensacion.last                                   # a:90
      editar(d, [{ stock_id: stock_a.id, cantidad: 999 }])
      expect(response).to have_http_status(:unprocessable_entity)
      expect(stock_a.reload.cantidad).to eq(90)              # rollback: sin cambios
      expect(d.reload.items.first.cantidad).to eq(10)
    end
  end

  # EL TOTAL NO SE TIPEA (7-oct-2026). Reemplaza a «administración pisa el total» (5-oct): el
  # total es la suma del carrito menos los descuentos, y para cobrar menos hay descuento en %
  # o en PESOS. El caso real que lo originó sigue cubierto: cuatro productos que suman $171.000
  # en una dispensa de $80.000 → descuento de $91.000, y las líneas suman lo cobrado.
  describe 'descuento en pesos (el total no se pisa)' do
    before { sign_in_as(admin) }

    def suma_lineas(d) = d.items.reload.sum { |it| it.subtotal_ars }

    it 'un total escrito a mano se ignora: manda la suma del carrito' do
      crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 5 }],
            aporte_socio_ars: 1000)                          # lista: 10*100 + 5*200 = 2000
      d = Dispensacion.last
      expect(d.aporte_socio_ars).to eq(2000)
      expect(d.items.find_by(stock: stock_a).precio_unitario_ars).to eq(100)
    end

    it 'descuenta los pesos del total y los reparte en las líneas, en proporción a su precio' do
      crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 5 }],
            descuento_dispensa_ars: 1000)

      expect(response).to have_http_status(:created)
      d = Dispensacion.last
      expect(d.aporte_socio_ars).to eq(1000)
      expect(d.descuento_dispensa_ars).to eq(1000)
      expect(suma_lineas(d)).to eq(1000)
      expect(d.items.find_by(stock: stock_a).precio_unitario_ars).to eq(50)
      expect(d.items.find_by(stock: stock_b).precio_unitario_ars).to eq(100)
    end

    it 'con un solo producto, el precio por unidad es el que queda después del descuento' do
      crear([{ stock_id: stock_a.id, cantidad: 4 }], descuento_dispensa_ars: 100)
      d = Dispensacion.last
      expect(d.aporte_socio_ars).to eq(300)
      expect(d.items.first.precio_unitario_ars).to eq(75)
    end

    it 'se suma al descuento en %: primero el %, después los pesos' do
      crear([{ stock_id: stock_a.id, cantidad: 10 }], descuento_dispensa_pct: 10, descuento_dispensa_ars: 100)
      expect(Dispensacion.last.aporte_socio_ars).to eq(800)  # 1000 - 10% - $100
    end

    it 'un descuento que se come todo no se acepta: eso es un regalo' do
      crear([{ stock_id: stock_a.id, cantidad: 10 }], descuento_dispensa_ars: 1000)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('regalo')
      expect(stock_a.reload.cantidad).to eq(100)
    end

    it 'el dispensador también descuenta en pesos, como en %' do
      sign_in_as(dispensador)
      crear([{ stock_id: stock_a.id, cantidad: 10 }], descuento_dispensa_ars: 200)
      expect(Dispensacion.last.aporte_socio_ars).to eq(800)
    end

    # Al editar, las líneas viajan con el precio ya descontado: sin volverlas al bruto, cada
    # edición descontaba los mismos pesos otra vez.
    it 'editar sin tocar el descuento no lo aplica dos veces' do
      crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 5 }],
            descuento_dispensa_ars: 1000)
      d = Dispensacion.last
      lineas = d.items.map { |it| { stock_id: it.stock_id, cantidad: it.cantidad, precio_manual_ars: it.precio_unitario_ars } }
      patch "/dispensaciones/#{d.id}", params: { dispensacion: { items: lineas, observaciones: 'x' } }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(d.reload.aporte_socio_ars).to eq(1000)
      expect(d.descuento_dispensa_ars).to eq(1000)
    end

    it 'editar cambiando el descuento parte del bruto, no del total ya descontado' do
      crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 5 }],
            descuento_dispensa_ars: 1000)
      d = Dispensacion.last
      lineas = d.items.map { |it| { stock_id: it.stock_id, cantidad: it.cantidad, precio_manual_ars: it.precio_unitario_ars } }
      patch "/dispensaciones/#{d.id}", params: { dispensacion: { items: lineas, descuento_dispensa_ars: 500 } }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(d.reload.aporte_socio_ars).to eq(1500)
      expect(suma_lineas(d)).to eq(1500)
    end

    it 'editar sumando un producto: el descuento se mantiene sobre el total nuevo' do
      crear([{ stock_id: stock_a.id, cantidad: 10 }], descuento_dispensa_ars: 200)
      d = Dispensacion.last
      patch "/dispensaciones/#{d.id}",
            params: { dispensacion: { items: [{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 5 }] } },
            headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(d.reload.aporte_socio_ars).to eq(1800)          # 2000 - 200
      expect(suma_lineas(d)).to eq(1800)
    end
  end
end
