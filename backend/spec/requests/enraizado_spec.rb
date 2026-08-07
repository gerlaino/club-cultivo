require 'rails_helper'

# El lote que ENRAÍZA vive en un propagador: la sala marca 60% de humedad y adentro hay 90%. La app
# no modela el domo como entidad —no aportaba ninguna decisión que el estado del lote no diera ya—,
# así que "tiene otro clima" se deriva del estado y el registro entra por su propia puerta.
RSpec.describe 'Lotes enraizando', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:vege)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }

  before { sign_in_as(admin) }

  describe 'el ambiente del propagador' do
    it 'registra solo en los lotes que están enraizando' do
      enraizando = create(:lote, club: club, sala: vege, estado: 'enraizado')
      creciendo  = create(:lote, club: club, sala: vege, estado: 'vegetativo', tamanio_maceta: 3)

      post "/api/salas/#{vege.id}/registrar_enraizado",
           params: { registro_ambiental: { temperatura: 24, humedad: 92, temperatura_sustrato: 25,
                                           producto_enraizante: 'gel' } }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['lotes_afectados']).to eq(1)
      expect(enraizando.registros_ambientales.last.humedad.to_f).to eq(92.0)
      expect(enraizando.registros_ambientales.last.producto_enraizante).to eq('gel')
      expect(creciendo.registros_ambientales.count).to eq(0)
    end

    it 'avisa en vez de romper si no hay ninguno enraizando' do
      create(:lote, club: club, sala: vege, estado: 'vegetativo', tamanio_maceta: 3)

      post "/api/salas/#{vege.id}/registrar_enraizado",
           params: { registro_ambiental: { temperatura: 24, humedad: 92 } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rechaza un enraizante inventado' do
      create(:lote, club: club, sala: vege, estado: 'enraizado')

      post "/api/salas/#{vege.id}/registrar_enraizado",
           params: { registro_ambiental: { temperatura: 24, humedad: 92, producto_enraizante: 'magia' } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # Sin esta exclusión el lote enraizando acumulaba dos lecturas contradictorias del mismo momento
  # (60% y 90%) y las alertas y la analítica promediaban un ambiente que no existió.
  describe 'el registro de la sala' do
    it 'saltea a los que están enraizando' do
      enraizando = create(:lote, club: club, sala: vege, estado: 'enraizado')
      creciendo  = create(:lote, club: club, sala: vege, estado: 'vegetativo', tamanio_maceta: 3)

      post "/api/salas/#{vege.id}/registrar_sala",
           params: { registro_ambiental: { temperatura: 22, humedad: 60 } }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['lotes_afectados']).to eq(1)
      expect(creciendo.registros_ambientales.count).to eq(1)
      expect(enraizando.registros_ambientales.count).to eq(0)
    end
  end

  # La regla protege A LA PLANTA, no al equipamiento: 12/12 le daría 12 horas de oscuridad a
  # esquejes que necesitan luz casi continua.
  describe 'pasar la sala a floración' do
    it 'se frena si hay lotes enraizando adentro' do
      create(:lote, club: club, sala: vege, estado: 'enraizado')

      post "/api/salas/#{vege.id}/cambiar_fase"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/enraizando/i)
      expect(vege.reload.kind).to eq('vegetativo')
    end

    it 'y se deja hacer cuando no hay ninguno' do
      create(:lote, club: club, sala: vege, estado: 'vegetativo', tamanio_maceta: 3)

      post "/api/salas/#{vege.id}/cambiar_fase"

      expect(response).to have_http_status(:success)
      expect(vege.reload.kind).to eq('floracion')
    end
  end

  describe 'el lote nuevo' do
    it 'nace enraizando, venga de semilla o de esqueje' do
      %w[semilla esqueje].each do |origen|
        post "/api/salas/#{vege.id}/lotes",
             params: { lote: { start_date: Time.zone.today.to_s, estado: 'enraizado',
                               origen: origen, plants_count: 5 } }

        expect(response).to have_http_status(:created)
        expect(Lote.find(JSON.parse(response.body)['id']).estado).to eq('enraizado')
      end
    end
  end

  # CUÁNTAS PRENDIERON, declarado como número al salir del enraizado. Es la única forma en que el
  # dato va a existir: nadie descarta 18 esquejes de 128 uno por uno, y sin esto el % de
  # prendimiento da 100% siempre — una métrica que miente es peor que una que falta.
  describe 'el prendimiento' do
    def lote_con(plantas)
      lote = create(:lote, club: club, sala: vege, estado: 'enraizado')
      plantas.times { |i| create(:plant, lote: lote, club: club, state: 'enraizado', nombre: "P#{i}") }
      lote.update_column(:plants_count, plantas)
      lote
    end

    it 'descarta como "no prendió" las que faltan' do
      lote = lote_con(20)

      post "/api/lotes/#{lote.id}/avanzar_fase", params: { tamanio_maceta: 3, prendieron: 17 }

      expect(response).to have_http_status(:success)
      expect(lote.reload.plants.where.not(state: 'descartada').count).to eq(17)
      expect(lote.plants.where(motivo_descarte: 'no_prendio').count).to eq(3)
      expect(lote.plants_count).to eq(17)
    end

    # Descartadas, NO borradas: si se borraran saldrían del denominador además del numerador y el
    # porcentaje volvería a dar 100%.
    it 'las que no prendieron siguen contando en el total' do
      lote = lote_con(20)

      post "/api/lotes/#{lote.id}/avanzar_fase", params: { tamanio_maceta: 3, prendieron: 17 }

      expect(lote.plants.count).to eq(20)   # las 20 siguen existiendo

      get '/api/analytics/prendimiento'
      global = JSON.parse(response.body)['global']
      expect(global['intentos']).to eq(20)
      expect(global['prendidas']).to eq(17)
      expect(global['porcentaje']).to eq(85.0)
    end

    it 'si prendieron todas no descarta ninguna' do
      lote = lote_con(10)

      post "/api/lotes/#{lote.id}/avanzar_fase", params: { tamanio_maceta: 3, prendieron: 10 }

      expect(lote.reload.plants.where(state: 'descartada').count).to eq(0)
    end

    # Si ya se descartaron algunas a mano por QR, el número viene contra las VIVAS: no las pisa ni
    # las cuenta dos veces.
    it 'no vuelve a descartar las que ya se habían marcado a mano' do
      lote = lote_con(20)
      lote.plants.limit(4).each { |p| p.update_columns(state: 'descartada', motivo_descarte: 'no_prendio') }
      lote.update_column(:plants_count, 16)

      post "/api/lotes/#{lote.id}/avanzar_fase", params: { tamanio_maceta: 3, prendieron: 14 }

      # 16 vivas − 14 que prendieron = 2 nuevas descartadas, no 6.
      expect(lote.reload.plants.where(state: 'descartada').count).to eq(6)
      expect(lote.plants.where.not(state: 'descartada').count).to eq(14)
    end

    it 'no acepta que prendan más de las que hay' do
      lote = lote_con(10)

      post "/api/lotes/#{lote.id}/avanzar_fase", params: { tamanio_maceta: 3, prendieron: 15 }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(lote.reload.estado).to eq('enraizado')
    end

    it 'deja el dato en el historial del lote' do
      lote = lote_con(20)

      post "/api/lotes/#{lote.id}/avanzar_fase", params: { tamanio_maceta: 3, prendieron: 17 }

      evento = lote.lote_eventos.where(tipo: 'actividad').last
      expect(evento.descripcion).to match(/17 de 20.*85\.0%/)
    end
  end

  # El esqueje que prendió va a maceta. Sin ese dato el lote entra a vegetativo sin saber en qué
  # volumen crece, que es lo que gobierna riego, frecuencia y cuándo toca el próximo trasplante.
  describe 'la maceta al prender' do
    it 'no deja avanzar a vegetativo sin el tamaño de maceta' do
      lote = create(:lote, club: club, sala: vege, estado: 'enraizado', tamanio_maceta: nil)

      post "/api/lotes/#{lote.id}/avanzar_fase"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to match(/maceta/i)
      expect(lote.reload.estado).to eq('enraizado')
    end

    it 'avanza y guarda la maceta cuando se indica' do
      lote = create(:lote, club: club, sala: vege, estado: 'enraizado', tamanio_maceta: nil)

      post "/api/lotes/#{lote.id}/avanzar_fase", params: { tamanio_maceta: 0.335 }

      expect(response).to have_http_status(:success)
      expect(lote.reload.estado).to eq('vegetativo')
      # 0,335 entra tal cual: la columna guarda tres decimales para que los tacos y macetitas de
      # propagación no se redondeen (ver la migración MacetaConTresDecimales).
      expect(lote.tamanio_maceta.to_f).to eq(0.335)
      # La primera maceta también queda como la inicial: es la que deja reconstruir los trasplantes.
      expect(lote.tamanio_maceta_inicial.to_f).to eq(0.335)
    end

    # De floración en adelante no se pide: la maceta ya está puesta desde que prendió.
    # La sala es mixta porque avanzar a floración exige una sala que la admita (la planta
    # florece por el fotoperiodo de la sala, no por apretar un botón).
    it 'no la pide en los avances posteriores' do
      mixta = create(:sala, club: club, sede: sede, created_by: admin, kind: 'mixta')
      lote = create(:lote, club: club, sala: mixta, estado: 'vegetativo', tamanio_maceta: nil)

      post "/api/lotes/#{lote.id}/avanzar_fase"

      expect(response).to have_http_status(:success)
      expect(lote.reload.estado).to eq('floracion')
    end
  end
end
