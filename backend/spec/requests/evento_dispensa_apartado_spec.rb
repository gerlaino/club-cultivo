require 'rails_helper'

# Ciclo completo de lo apartado para un evento, con el caso real: se apartan 100 prerolls y 250 g,
# durante el evento se dispensa parte a socios, algo se consume sin dispensar y el resto vuelve.
#
#   apartado = dispensado (durante el evento) + consumo interno (al cerrar) + liberado
#
# Lo dispensado sale por su canal (con socio y trazabilidad) y NO cuesta al evento: su costo e
# ingreso viven en la dispensación. Lo consumido internamente sí es COGS del evento.
RSpec.describe 'Dispensar desde lo apartado para un evento', type: :request do
  let(:club)   { create(:club, features: { 'bar' => true }) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:sede)   { create(:sede, club: club, tipo: 'social') }
  let(:bar)    { create(:barra, club: club, sede: sede) }
  let(:evento) { bar.eventos_bar.create!(club: club, nombre: 'Aniversario', estado: 'planificado') }
  let(:paciente) { create(:paciente, club: club) }

  let(:lote) { create(:lote, club: club) }
  let!(:flor) do
    create(:stock, club: club, sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                   cantidad: 400, costo_unitario_ars: 50, precio_sugerido_ars: 3000, descripcion: 'Kush')
  end

  before { sign_in_as(admin) }

  def prov_path(extra = '') = "/bares/#{bar.id}/eventos/#{evento.id}/provisiones#{extra}"

  # Aparta `cantidad` de flor y pone el evento en curso.
  def apartar!(cantidad, en_curso: true)
    post prov_path, params: { provisionable_type: 'Stock', provisionable_id: flor.id, cantidad_prevista: cantidad },
         headers: auth_headers, as: :json
    post prov_path('/reservar'), headers: auth_headers, as: :json
    evento.update!(estado: 'en_venta') if en_curso
    evento.update!(estado: 'en_curso') if en_curso
    evento.provisiones.first
  end

  def dispensar(cantidad, desde_evento: nil)
    linea = { stock_id: flor.id, cantidad: cantidad, evento_bar_id: desde_evento }.compact
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { medio_pago: 'efectivo', items: [linea] } },
         headers: auth_headers
  end

  describe 'durante el evento' do
    it 'el listado de stock informa lo apartado por el evento en curso' do
      apartar!(250)
      get '/stocks', params: { para_dispensa: true }, headers: auth_headers

      fila = JSON.parse(response.body).find { |s| s['id'] == flor.id }
      apartado = fila['apartados_evento'].first
      expect(apartado['evento_nombre']).to eq('Aniversario')
      expect(apartado['cantidad']).to eq(250.0)
      expect(fila['cantidad_disponible_real']).to eq(150.0) # 400 − 250 apartados
    end

    it 'dispensa desde lo apartado sin descontar dos veces' do
      prov = apartar!(250)
      dispensar(30, desde_evento: evento.id)
      expect(response).to have_http_status(:created)

      flor.reload
      expect(flor.cantidad).to eq(370)                  # 400 − 30 dispensados
      expect(prov.reload.cantidad_consumida).to eq(30)  # imputado al apartado
      expect(prov.saldo_apartado).to eq(220)            # 250 − 30 sigue bloqueado
      expect(flor.cantidad_disponible_real).to eq(150)  # el libre NO se movió: salió del apartado
    end

    it 'deja dispensar del apartado aunque el libre no alcance' do
      apartar!(380) # quedan 20 libres de 400
      expect(flor.reload.cantidad_disponible_real).to eq(20)

      dispensar(100, desde_evento: evento.id)
      expect(response).to have_http_status(:created)
      expect(flor.reload.cantidad).to eq(300)
    end

    it 'la línea guarda de qué evento salió (trazabilidad)' do
      apartar!(250)
      dispensar(30, desde_evento: evento.id)

      item = DispensacionItem.last
      expect(item.evento_bar).to eq(evento)
      expect(flor.stock_movimientos.last.notas).to include('Aniversario')
    end

    it 'una dispensa NO marcada como del evento no toca lo apartado' do
      prov = apartar!(250)
      dispensar(30) # sin evento_bar_id → sale del libre
      expect(response).to have_http_status(:created)

      expect(prov.reload.cantidad_consumida).to eq(0)
      expect(flor.reload.cantidad_disponible_real).to eq(120) # 150 libres − 30
    end

    it 'no deja dispensar del libre más de lo que hay (lo apartado no se pisa)' do
      apartar!(380) # 20 libres
      dispensar(100) # sin marcar el evento
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('Stock insuficiente')
      expect(flor.reload.cantidad).to eq(400)
    end

    it 'no se puede reclamar el apartado de un evento que todavía no empezó' do
      prov = apartar!(250, en_curso: false) # queda en 'planificado'
      dispensar(200, desde_evento: evento.id)

      expect(response).to have_http_status(:unprocessable_entity) # solo 150 libres
      expect(prov.reload.cantidad_consumida).to eq(0)
    end
  end

  describe 'al cerrar el evento' do
    it 'reparte lo apartado en dispensado + consumo interno + liberado' do
      prov = apartar!(250)
      dispensar(100, desde_evento: evento.id) # dispensado a socios durante el evento

      # De los 150 que quedaban apartados, 25 se consumieron sin dispensar y 125 vuelven.
      post prov_path('/cerrar'), params: { consumos: [{ id: prov.id, consumo_interno: 25 }], finalizar: true },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)

      flor.reload
      expect(flor.cantidad).to eq(275)                 # 400 − 100 dispensados − 25 consumidos
      expect(flor.apartado_para_eventos).to eq(0)      # nada queda bloqueado
      expect(flor.cantidad_disponible_real).to eq(275) # los 125 restantes volvieron al pozo

      prov.reload
      expect(prov.cantidad_consumida).to eq(100)       # dispensado
      expect(prov.cantidad_consumo_interno).to eq(25)  # consumido sin dispensar

      # El consumo interno deja rastro propio, distinto de una merma.
      mov = flor.stock_movimientos.where(tipo: 'consumo_evento').last
      expect(mov.gramos).to eq(-25)
      expect(mov.notas).to include('Aniversario')
    end

    it 'al evento le cuesta lo consumido internamente, no lo dispensado' do
      prov = apartar!(250)
      dispensar(100, desde_evento: evento.id)
      post prov_path('/cerrar'), params: { consumos: [{ id: prov.id, consumo_interno: 25 }] },
           headers: auth_headers, as: :json

      # 25 × $50 de costo. Los 100 dispensados NO: su costo e ingreso están en la dispensación.
      expect(evento.reload.costo_mercaderia).to eq(25 * 50)
    end

    it 'no deja declarar más consumo interno que lo que quedaba apartado' do
      prov = apartar!(250)
      dispensar(100, desde_evento: evento.id)

      post prov_path('/cerrar'), params: { consumos: [{ id: prov.id, consumo_interno: 999 }] },
           headers: auth_headers, as: :json

      # Se recorta a los 150 que quedaban apartados: nunca descuenta de más.
      expect(prov.reload.cantidad_consumo_interno).to eq(150)
      expect(flor.reload.cantidad).to eq(150) # 400 − 100 − 150
    end

    it 'sin consumo interno, todo lo no dispensado vuelve' do
      prov = apartar!(250)
      dispensar(100, desde_evento: evento.id)
      post prov_path('/cerrar'), params: { consumos: [{ id: prov.id, consumo_interno: 0 }], finalizar: true },
           headers: auth_headers, as: :json

      flor.reload
      expect(flor.cantidad).to eq(300)                 # solo salió lo dispensado
      expect(flor.cantidad_disponible_real).to eq(300)
      expect(prov.reload.saldo_apartado).to eq(0)
    end
  end
end
