require 'rails_helper'

RSpec.describe 'DELETE /stocks/:id — cascada a derivados', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  before { sign_in_as(admin) }

  def producir_derivado(origen, gramos: 80, cantidad: 8)
    post "/stocks/#{origen.id}/producir",
         params: { gramos_usados: gramos, forma_producto: 'prensado', cantidad_producida: cantidad, unidad: 'un', precio_sugerido_ars: 100 },
         headers: auth_headers, as: :json
    Stock.find(JSON.parse(response.body)['id'])
  end

  it 'borra el stock y sus derivados en cascada' do
    origen   = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3)
    derivado = producir_derivado(origen)

    delete "/stocks/#{origen.id}", headers: auth_headers, as: :json
    expect(response).to have_http_status(:no_content)
    expect(Stock.where(id: origen.id)).to be_empty
    expect(Stock.where(id: derivado.id)).to be_empty   # derivado borrado también
  end

  it 'bloquea todo el borrado si un derivado tiene un despacho entregado' do
    origen   = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3)
    derivado = producir_derivado(origen)

    disp = Dispensacion.create!(
      paciente: paciente, user: admin, stock: derivado, sede: sede,
      cantidad: 1, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today, aporte_socio_ars: 100,
    )
    disp.update_column(:estado_envio, 'entregado')

    delete "/stocks/#{origen.id}", headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to include('entregados')
    expect(Stock.where(id: origen.id)).to exist     # nada se borró
    expect(Stock.where(id: derivado.id)).to exist
  end

  it 'borra un stock con reservas no-pendientes y dispensaciones canceladas (sin violar FK)' do
    stock = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3)
    # Reserva ya entregada (histórica): se crea saltando la validación "fecha ≥ mañana"
    # (que aplica a reservas nuevas pendientes, no a una entregada con fecha pasada).
    Reserva.new(club: club, paciente: paciente, stock: stock, user: admin, cantidad: 10,
                estado: 'entregada', fecha_entrega_estimada: Date.yesterday).save(validate: false)
    disp = Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                                cantidad: 1, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today, aporte_socio_ars: 100)
    disp.update_column(:estado_envio, 'cancelada')

    delete "/stocks/#{stock.id}", headers: auth_headers, as: :json
    expect(response).to have_http_status(:no_content)
    expect(Stock.where(id: stock.id)).to be_empty
  end

  it 'bloquea si un derivado tiene un despacho EN CAMINO (en_viaje)' do
    origen   = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3)
    derivado = producir_derivado(origen)

    disp = Dispensacion.create!(
      paciente: paciente, user: admin, stock: derivado, sede: sede,
      cantidad: 1, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today, aporte_socio_ars: 100,
    )
    disp.update_column(:estado_envio, 'en_viaje')

    delete "/stocks/#{origen.id}", headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to include('en camino')
    expect(Stock.where(id: derivado.id)).to exist
  end

  # AC (Germán, 15-oct-2026): eliminar un derivado devolvía los gramos al origen sin dejar
  # movimiento y borraba el de producción: el saldo subía sin explicación. Ahora queda escrito.
  describe 'eliminar sólo el derivado' do
    let(:origen) { create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3) }

    it 'los gramos vuelven al origen con su movimiento, y la producción sigue en el historial' do
      derivado = producir_derivado(origen)
      expect(origen.reload.cantidad).to eq(120)

      delete "/stocks/#{derivado.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:no_content)

      expect(origen.reload.cantidad).to eq(200)
      movs = origen.stock_movimientos.order(:created_at)
      expect(movs.map { |m| m.gramos.to_f }).to eq([-80.0, 80.0])
      expect(movs.last.notas).to include(derivado.numero_lote_producto, 'eliminado')
      expect(movs.last.usuario_id).to eq(admin.id)
    end

    it 'el informe de stock del origen cierra, sin nada «sin explicar»' do
      origen.update_columns(created_at: 2.months.ago, cantidad_inicial: 200)
      derivado = producir_derivado(origen)
      delete "/stocks/#{derivado.id}", headers: auth_headers, as: :json

      d = ActsAsTenant.with_tenant(club) do
        Informes::Inventario.new(club: club, desde: Time.zone.today.beginning_of_month, hasta: Time.zone.today).call
      end
      f = d[:stocks].find { |x| x[:id] == origen.id }
      expect(f).to include(habia: 200.0, ingreso: 0.0, otras_salidas: 0.0, quedaba: 200.0)
      expect(f[:descuadre]).to be_nil
    end
  end
end
