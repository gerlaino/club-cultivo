require 'rails_helper'

# Se podía MARCAR una compra como pendiente de pago, pero no había ninguna forma de decir
# después que se pagó: el gasto quedaba pendiente para siempre y el total por pagar del club
# no bajaba nunca.
#
# No genera un movimiento nuevo: el egreso ya está asentado desde que se compró. Lo que cambia
# es su estado de pago — y con eso sale del "a crédito".
RSpec.describe 'Registrar el pago de un movimiento pendiente', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  def movimiento(pagado:, tipo: 'egreso', fecha: Time.zone.today)
    club.movimientos_contables.create!(
      sede: sede, created_by: admin, tipo: tipo, categoria: 'insumo',
      descripcion: 'Compra de fertilizante', monto_ars: 15_000,
      fecha: fecha, pagado: pagado, medio_pago: 'efectivo',
    )
  end

  before { sign_in_as(admin) }

  it 'marca el gasto como pagado' do
    mov = movimiento(pagado: false)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago", as: :json

    expect(response).to have_http_status(:ok), response.body
    expect(mov.reload.pagado).to be(true)
  end

  it 'deja registrado con qué se pagó, si se informa' do
    mov = movimiento(pagado: false)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago",
          params: { medio_pago: 'transferencia' }, as: :json

    expect(mov.reload.medio_pago).to eq('transferencia')
  end

  # El egreso ya estaba en el libro desde la compra: pagarlo no lo duplica.
  it 'NO crea un movimiento nuevo' do
    mov = movimiento(pagado: false)

    expect {
      patch "/api/movimientos_contables/#{mov.id}/registrar_pago", as: :json
    }.not_to change(MovimientoContable, :count)
  end

  it 'el monto no se toca' do
    mov = movimiento(pagado: false)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago", as: :json

    expect(mov.reload.monto_ars.to_f).to eq(15_000.0)
  end

  it 'rechaza pagar algo que ya estaba pagado' do
    mov = movimiento(pagado: true)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago", as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to match(/ya figura como pagado/i)
  end

  it 'no toca un período cerrado' do
    mov = movimiento(pagado: false, fecha: Time.zone.today - 40)
    club.update!(contabilidad_cerrada_hasta: Time.zone.today - 10)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago", as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(mov.reload.pagado).to be(false)
  end

  it 'un rol sin permiso de escritura no puede' do
    mov = movimiento(pagado: false)
    dispensador = create(:user, :dispensador, club: club)
    sign_in_as(dispensador)

    patch "/api/movimientos_contables/#{mov.id}/registrar_pago", as: :json

    expect(response).to have_http_status(:forbidden)
    expect(mov.reload.pagado).to be(false)
  end
end
