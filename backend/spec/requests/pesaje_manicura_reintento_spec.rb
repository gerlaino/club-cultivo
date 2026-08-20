require 'rails_helper'

# AC: el pesaje que se cargó SIN SEÑAL y se reintenta al volver no puede terminar en dos jornadas
# ni en un aviso de falla inventado.
#
# El escenario real: la manicura pesa en un galpón sin datos. El POST sale igual, llega al servidor
# y la respuesta se pierde en el camino. Para el teléfono eso es indistinguible de "no llegó", así
# que lo encola y lo reintenta cuando vuelve la señal.
#
# Lo que salva el dato es que **la PLANTA es la clave de idempotencia natural**: `distribuir_resto!`
# sólo toca las que no tienen peso, así que el reintento no puede duplicar nada — no hace falta
# ninguna columna de idempotencia. Lo que faltaba era DECIRLO: el 422 genérico era idéntico a un
# error de validación, la cola lo marcaba FALLIDO y la manicura leía "no pudo sincronizarse" cuando
# su pesaje había entrado. Si a partir de ahí lo volvía a cargar, ahí sí quedaban dos jornadas.
RSpec.describe 'Pesaje de manicura reintentado sin señal', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:manicura) { create(:user, :manicura, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin, kind: 'manicura') }
  let(:lote)     { create(:lote, club: club, sala: sala, estado: 'en_manicura', manicurador: manicura) }
  let!(:p1)      { create(:plant, lote: lote, club: club, state: 'cosechado') }
  let!(:p2)      { create(:plant, lote: lote, club: club, state: 'cosechado') }

  before { sign_in_as(manicura) }

  # `force_new: true` es lo que manda la cola offline: sin eso, una jornada previa enviada sin
  # confirmar devuelve 409 `needs_choice` ("¿seguir la anterior o empezar una nueva?"), una pregunta
  # que no se le puede hacer a nadie desde una cola que corre sola — y como el 409 trae `response`,
  # se marcaría fallido y el pesaje se perdería.
  def pesar!(ids = [p1.id, p2.id], gramos: 100)
    post "/lotes/#{lote.id}/pesajes_manicura",
         params: { plant_ids: ids, peso_total_g: gramos, enviar: true, force_new: true },
         headers: auth_headers
  end

  it 'la primera vez registra y envía a confirmar' do
    expect { pesar! }.to change { lote.pesajes_manicura.count }.by(1)

    expect(response).to have_http_status(:created)
    expect(p1.reload.peso_seco).to eq(50)
    expect(p2.reload.peso_seco).to eq(50)
  end

  describe 'el reintento de algo que ya había entrado' do
    before { pesar! }

    it 'no crea una segunda jornada' do
      expect { pesar! }.not_to change { lote.pesajes_manicura.count }
    end

    # Lo que lee la cola para saber que no es una falla. Sin esta bandera es un 422 igual a
    # cualquier otro.
    it 'lo marca como ya registrado, no como error de validación' do
      pesar!

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['ya_registrado']).to be(true)
    end

    it 'no toca los pesos que ya estaban' do
      pesar!([p1.id, p2.id], gramos: 999)

      expect(p1.reload.peso_seco).to eq(50)
      expect(p2.reload.peso_seco).to eq(50)
    end

    # El `raise` va dentro de la transacción. Si se escapara, cada reintento dejaría una jornada
    # vacía colgada esperando que el admin la confirme.
    it 'no deja jornadas vacías dando vueltas' do
      pesar!

      expect(lote.pesajes_manicura.count).to eq(1)
      expect(lote.pesajes_manicura.first.pesadas_plantas.count).to eq(2)
    end
  end

  describe 'lo que NO es un reintento' do
    # Sólo una de las dos ya está pesada: la otra sigue pendiente, así que esto es trabajo nuevo.
    it 'con una planta libre, registra normal', :aggregate_failures do
      pesar!([p1.id], gramos: 40)
      expect(response).to have_http_status(:created)

      pesar!([p1.id, p2.id], gramos: 60)

      expect(response).to have_http_status(:created)
      expect(p2.reload.peso_seco).to eq(60)
    end

    # Una id que no es del lote no es un pesaje repetido, es un pedido inválido: tiene que fallar
    # de verdad, no colarse como "ya registrado" y desaparecer de la cola.
    it 'con una planta de otro lote, falla como error y sin la bandera' do
      otro  = create(:lote, club: club, sala: sala, estado: 'en_manicura', manicurador: manicura)
      ajena = create(:plant, lote: otro, club: club, state: 'cosechado')
      pesar!([p1.id, p2.id])

      pesar!([p1.id, p2.id, ajena.id])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['ya_registrado']).to be_nil
    end
  end
end
