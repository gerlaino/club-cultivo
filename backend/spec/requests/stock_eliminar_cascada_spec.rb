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

  # AC (Germán, 16-oct-2026): con dispensas no se elimina; tampoco si las tiene un derivado.
  it 'bloquea todo el borrado si un derivado tiene una dispensa' do
    origen   = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3)
    derivado = producir_derivado(origen)
    Dispensacion.create!(paciente: paciente, user: admin, stock: derivado, sede: sede,
                         cantidad: 1, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today, aporte_socio_ars: 100)

    delete "/stocks/#{origen.id}", headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to include('derivado', derivado.numero_lote_producto, 'ya tiene dispensas')
    expect(Stock.where(id: [origen.id, derivado.id]).count).to eq(2) # nada se borró
  end

  it 'la ficha dice por qué no se puede eliminar, para apagar el botón' do
    stock = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3)
    get "/stocks/#{stock.id}", headers: auth_headers
    expect(JSON.parse(response.body)['data']['eliminar_bloqueo']).to be_nil

    Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                         cantidad: 1, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today, aporte_socio_ars: 100)
    get "/stocks/#{stock.id}", headers: auth_headers
    expect(JSON.parse(response.body)['data']['eliminar_bloqueo']).to include('ya tiene dispensas')
  end

  it 'borra un stock con una reserva ya entregada y sin dispensas (sin violar FK)' do
    stock = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3)
    # Reserva ya entregada (histórica): se crea saltando la validación "fecha ≥ mañana".
    Reserva.new(club: club, paciente: paciente, stock: stock, user: admin, cantidad: 10,
                estado: 'entregada', fecha_entrega_estimada: Date.yesterday).save(validate: false)

    delete "/stocks/#{stock.id}", headers: auth_headers, as: :json
    expect(response).to have_http_status(:no_content)
    expect(Stock.where(id: stock.id)).to be_empty
  end

  # AC (Germán, 16-oct-2026): «eliminar stock producido no debería reflejarse en el historial ya
  # que sería un error humano». El origen queda como antes de producir: saldo e historial.
  describe 'eliminar sólo el derivado' do
    let(:origen) { create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3) }

    it 'los gramos vuelven al origen y la producción no queda en su historial' do
      derivado = producir_derivado(origen)
      expect(origen.reload.cantidad).to eq(120)

      delete "/stocks/#{derivado.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:no_content)

      expect(origen.reload.cantidad).to eq(200)
      expect(origen.stock_movimientos).to be_empty
      get "/stocks/#{origen.id}/movimientos", headers: auth_headers
      expect(JSON.parse(response.body)).to be_empty
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

    it 'un derivado ya dispensado no se elimina: el origen no recupera nada' do
      derivado = producir_derivado(origen)
      Dispensacion.create!(paciente: paciente, user: admin, stock: derivado, sede: sede,
                           cantidad: 1, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today, aporte_socio_ars: 100)
      delete "/stocks/#{derivado.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('este stock ya tiene dispensas')
      expect(origen.reload.cantidad).to eq(120)
    end
  end
end
