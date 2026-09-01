require 'rails_helper'

# QUÉ ES un producto se puede corregir.
#
# Un stock cargado como `prensado` porque todavía no existía `preroll` no puede quedar mal para
# siempre: la forma y su unidad son una etiqueta, y una etiqueta equivocada se arregla.
#
# LA SALVEDAD ES EL EJERCICIO CERRADO. Cambiar la unidad reinterpreta cantidades ya escritas —los
# 3 que salieron como gramos pasan a leerse como unidades— y esas salidas tienen su asiento. Si el
# período ya se cerró, eso es reescribir lo que se presentó.
RSpec.describe 'Corregir qué es un stock', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'social') }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: nil, forma_producto: 'prensado', unidad: 'g',
                     origen: 'compra_externa', proveedor: 'X', cantidad: 20, estado: 'asignado',
                     disponibilidad: 'ambas', precio_sugerido_ars: 8_500)
    end
  end

  def editar!(attrs)
    sign_in_as(admin)
    patch "/api/stocks/#{stock.id}", headers: auth_headers, params: { stock: attrs }
    JSON.parse(response.body)
  end

  def dispensar!(fecha)
    ActsAsTenant.with_tenant(club) do
      Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                           cantidad: 3, medio_pago: 'efectivo', aporte_socio_ars: 500,
                           fecha_dispensacion: fecha)
    end
  end

  it 'se corrige la forma y la unidad' do
    editar!(forma_producto: 'preroll', unidad: 'un')

    expect(response).to have_http_status(:ok)
    expect(stock.reload.forma_producto).to eq('preroll')
    expect(stock.unidad).to eq('un')
  end

  it 'y queda en el historial de quién lo cambió' do
    expect { editar!(forma_producto: 'preroll', unidad: 'un') }
      .to change { Auditoria.unscoped.where(auditable_type: 'Stock', auditable_id: stock.id).count }.by(1)
  end

  it 'una forma que no existe no se acepta' do
    body = editar!(forma_producto: 'jarabe')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(body['error']).to match(/no es una forma de producto válida/i)
    expect(stock.reload.forma_producto).to eq('prensado')
  end

  # Corregir es justamente lo que se hace mientras el período sigue abierto.
  it 'con dispensas en período ABIERTO se corrige igual' do
    dispensar!(Time.zone.today)
    club.update!(contabilidad_cerrada_hasta: 1.month.ago.to_date)

    editar!(forma_producto: 'preroll', unidad: 'un')

    expect(response).to have_http_status(:ok)
    expect(stock.reload.unidad).to eq('un')
  end

  describe 'con el ejercicio cerrado' do
    before do
      dispensar!(2.months.ago.to_date)
      club.update!(contabilidad_cerrada_hasta: 1.month.ago.to_date)
    end

    it 'no se cambia: reinterpretaría cantidades ya asentadas' do
      body = editar!(forma_producto: 'preroll', unidad: 'un')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/período contable cerrado/i)
      expect(body['error']).to match(/reabrí el período/i)
      expect(stock.reload.forma_producto).to eq('prensado')
    end

    it 'pero el resto del producto sí: no queda congelado entero' do
      editar!(precio_sugerido_ars: 9_000, descripcion: 'caja nueva')

      expect(response).to have_http_status(:ok)
      expect(stock.reload.precio_sugerido_ars.to_f).to eq(9_000.0)
    end

    it 'y la pantalla se entera antes de ofrecerlo' do
      sign_in_as(admin)
      get "/api/stocks/#{stock.id}", headers: auth_headers

      cuerpo = JSON.parse(response.body)['data']
      expect(cuerpo['puede_cambiar_forma']).to be(false)
      expect(cuerpo['dispensas_cerradas']).to eq(1)
    end

    # Reabrir el período es la puerta que existe para esto.
    it 'reabierto el período, se corrige' do
      club.update!(contabilidad_cerrada_hasta: nil)

      editar!(forma_producto: 'preroll', unidad: 'un')

      expect(response).to have_http_status(:ok)
      expect(stock.reload.unidad).to eq('un')
    end
  end

  # La dispensa multi-ítem no pasa por `dispensaciones.stock_id`: si sólo se mirara ahí, un stock
  # dispensado por el carrito se dejaría cambiar aunque estuviera dentro del período cerrado.
  it 'cuenta también las dispensas multi-ítem' do
    ActsAsTenant.with_tenant(club) do
      d = Dispensacion.new(paciente: paciente, user: admin, sede: sede, medio_pago: 'efectivo',
                           aporte_socio_ars: 500, fecha_dispensacion: 2.months.ago.to_date)
      d.items.build(stock: stock, cantidad: 2, precio_unitario_ars: 100)
      d.save!
    end
    club.update!(contabilidad_cerrada_hasta: 1.month.ago.to_date)

    body = editar!(forma_producto: 'preroll', unidad: 'un')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(body['error']).to match(/período contable cerrado/i)
  end
end
