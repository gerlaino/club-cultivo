require 'rails_helper'

# Un clonador es un domo DENTRO de una sala, con su propio microclima: el cuarto marca 60% de humedad
# y adentro hay 90%. Sin él, a los lotes enraizando se les grababa el clima de la sala, que no es el
# suyo.
RSpec.describe 'Clonadores', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:vege)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }
  let(:flora) { create(:sala, club: club, sede: sede, created_by: admin, kind: 'floracion') }

  before { sign_in_as(admin) }

  def crear(sala, attrs = {})
    post "/api/salas/#{sala.id}/clonadores",
         params: { clonador: { nombre: 'Clonador 1', capacidad: 128 }.merge(attrs) }
  end

  describe 'dónde puede vivir' do
    it 'entra en una sala de vegetativo: comparte el 18/6' do
      crear(vege)
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)).to include('nombre' => 'Clonador 1', 'capacidad' => 128)
    end

    # Un esqueje sin raíz necesita luz casi continua; 12/12 no lo deja prender. Es un error de
    # cultivo, no una preferencia: por eso es validación dura y no advertencia.
    it 'NO entra en una sala de floración' do
      crear(flora)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].join).to match(/floración/i)
    end

    # El guard de creación no alcanza: la sala puede darse vuelta debajo del clonador.
    it 'y la sala no puede pasarse a floración con clonadores adentro' do
      create(:clonador, club: club, sala: vege, nombre: 'C1')
      create(:lote, club: club, sala: vege, estado: 'vegetativo')

      post "/api/salas/#{vege.id}/cambiar_fase"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/clonadores/i)
      expect(vege.reload.kind).to eq('vegetativo')
    end
  end

  describe 'registro ambiental del domo' do
    let(:clonador) { create(:clonador, club: club, sala: vege, nombre: 'C1') }

    it 'registra en el lote que tiene adentro, etiquetado con el clonador' do
      adentro = create(:lote, club: club, sala: vege, estado: 'enraizado', clonador: clonador)
      # Otro lote enraizando en la MISMA sala pero fuera del domo: tiene su propio microclima
      # (o el de la sala), así que no le toca el registro de este domo.
      otro_domo = create(:clonador, club: club, sala: vege, nombre: 'C2')
      vecino    = create(:lote, club: club, sala: vege, estado: 'enraizado', clonador: otro_domo)
      fuera     = create(:lote, club: club, sala: vege, estado: 'vegetativo')

      post "/api/clonadores/#{clonador.id}/registrar",
           params: { registro_ambiental: { temperatura: 24, humedad: 92, temperatura_sustrato: 25,
                                           producto_enraizante: 'gel' } }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['lotes_afectados']).to eq(1)
      expect(adentro.registros_ambientales.last.clonador_id).to eq(clonador.id)
      expect(adentro.registros_ambientales.last.humedad.to_f).to eq(92.0)
      expect(vecino.registros_ambientales.count).to eq(0)
      # El lote de la sala que no está en el domo tampoco recibe el clima del domo.
      expect(fuera.registros_ambientales.count).to eq(0)
    end

    it 'el ambiente del domo es el suyo, no el de la sala' do
      create(:lote, club: club, sala: vege, estado: 'enraizado', clonador: clonador)
      post "/api/clonadores/#{clonador.id}/registrar",
           params: { registro_ambiental: { temperatura: 24, humedad: 92 } }

      get "/api/salas/#{vege.id}/clonadores"
      amb = JSON.parse(response.body).first['ambiente_actual']
      expect(amb['humedad']).to eq(92.0)
      expect(amb['registrado_en']).to be_present
    end

    it 'sin lotes adentro avisa en vez de romper' do
      post "/api/clonadores/#{clonador.id}/registrar",
           params: { registro_ambiental: { temperatura: 24, humedad: 92 } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rechaza un enraizante inventado' do
      create(:lote, club: club, sala: vege, estado: 'enraizado', clonador: clonador)
      post "/api/clonadores/#{clonador.id}/registrar",
           params: { registro_ambiental: { temperatura: 24, humedad: 92, producto_enraizante: 'magia' } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # El lote es del clonador SOLO mientras enraíza. Estar adentro no es un flag que haya que
  # mantener: se deriva del estado, así que no se puede desincronizar.
  describe 'entrar y salir del domo' do
    let(:clonador) { create(:clonador, club: club, sala: vege, nombre: 'C1', capacidad: 100) }

    # El lote puede nacer ya metido en el domo: es el caso normal —se hacen los esquejes y van
    # directo al clonador—, así que no hay que crearlo y después asignarlo en dos pasos.
    it 'un lote puede nacer adentro del domo' do
      post "/api/salas/#{vege.id}/lotes",
           params: { lote: { start_date: Date.today.to_s, estado: 'enraizado', origen: 'esqueje',
                             plants_count: 10, clonador_id: clonador.id } }

      expect(response).to have_http_status(:created)
      lote = Lote.find(JSON.parse(response.body)['id'])
      expect(lote.estado).to eq('enraizado')
      expect(lote.clonador_id).to eq(clonador.id)
      expect(lote.en_clonador?).to be true
    end

    it 'asigna un lote que está enraizando en la misma sala' do
      lote = create(:lote, club: club, sala: vege, estado: 'enraizado')

      post "/api/clonadores/#{clonador.id}/asignar", params: { lote_id: lote.id }

      expect(response).to have_http_status(:ok)
      expect(lote.reload.clonador_id).to eq(clonador.id)
    end

    # En el domo real conviven esquejes de varias genéticas, pero en la app se abstrae igual que el
    # lote: tantos clonadores como agrupaciones homogéneas haya.
    it 'un clonador aloja UN SOLO lote a la vez' do
      primero = create(:lote, club: club, sala: vege, estado: 'enraizado', clonador: clonador)
      segundo = create(:lote, club: club, sala: vege, estado: 'enraizado')

      post "/api/clonadores/#{clonador.id}/asignar", params: { lote_id: segundo.id }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].join).to match(/#{primero.codigo}.*un solo lote/i)
      expect(segundo.reload.clonador_id).to be_nil
    end

    # Pero a lo largo del tiempo sí aloja muchos: uno prende, sale, y entra el siguiente.
    it 'y acepta el siguiente lote cuando el anterior prendió' do
      anterior = create(:lote, club: club, sala: vege, estado: 'enraizado', clonador: clonador,
                               tamanio_maceta: 3)
      anterior.update!(estado: 'vegetativo')
      nuevo = create(:lote, club: club, sala: vege, estado: 'enraizado')

      post "/api/clonadores/#{clonador.id}/asignar", params: { lote_id: nuevo.id }

      expect(response).to have_http_status(:ok)
      expect(nuevo.reload.clonador_id).to eq(clonador.id)
      expect(anterior.reload.clonador_id).to eq(clonador.id)  # su historia no se pisa
    end

    it 'no entra un lote que ya prendió: el domo es solo para enraizar' do
      ya_prendio = create(:lote, club: club, sala: vege, estado: 'vegetativo')

      post "/api/clonadores/#{clonador.id}/asignar", params: { lote_id: ya_prendio.id }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/ya prendió/i)
      expect(ya_prendio.reload.clonador_id).to be_nil
    end

    it 'no entra un lote de otra sala: el domo está adentro de un cuarto' do
      otra_sala = create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo')
      ajeno = create(:lote, club: club, sala: otra_sala, estado: 'enraizado')

      post "/api/clonadores/#{clonador.id}/asignar", params: { lote_id: ajeno.id }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].join).to match(/otra sala/i)
      expect(ajeno.reload.clonador_id).to be_nil
    end

    # Cuando prende, el lote sale al cuarto: deja de ocupar alvéolos y deja de recibir el clima del
    # domo. Pero DÓNDE enraizó no se borra — es lo que permite el prendimiento por clonador.
    it 'al prender deja de estar adentro, pero el clonador queda como historia' do
      lote = create(:lote, club: club, sala: vege, estado: 'enraizado', clonador: clonador)
      create(:plant, lote: lote, state: 'enraizado', nombre: 'P1')

      post "/api/lotes/#{lote.id}/avanzar_fase", params: { tamanio_maceta: 3 }
      expect(response).to have_http_status(:success)

      expect(lote.reload.estado).to eq('vegetativo')
      expect(lote.clonador_id).to eq(clonador.id)   # historia: dónde enraizó
      expect(lote.en_clonador?).to be false          # pero ya no está adentro

      get "/api/salas/#{vege.id}/clonadores"
      expect(JSON.parse(response.body).first['ocupados']).to eq(0)
    end

    it 'y al prender ya no recibe el clima del domo' do
      lote = create(:lote, club: club, sala: vege, estado: 'enraizado', clonador: clonador)
      lote.update!(estado: 'vegetativo', tamanio_maceta: 3)

      post "/api/clonadores/#{clonador.id}/registrar",
           params: { registro_ambiental: { temperatura: 24, humedad: 92 } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(lote.registros_ambientales.count).to eq(0)
    end

    # El domo VIAJA con el lote: un esqueje sin raíz no puede vivir fuera del domo, así que mudarlo
    # de cuarto no lo saca. Lo que se muda es el clonador entero. Del domo se sale al prender.
    it 'mudarlo de cuarto se lleva el domo con él' do
      otra_sala = create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo')
      lote = create(:lote, club: club, sala: vege, estado: 'enraizado', clonador: clonador)

      post '/api/lotes/mover', params: { lote_ids: [lote.id], sala_id: otra_sala.id }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['clonadores_mudados']).to eq(['C1'])
      expect(lote.reload.sala_id).to eq(otra_sala.id)
      expect(lote.clonador_id).to eq(clonador.id)          # sigue en su domo
      expect(clonador.reload.sala_id).to eq(otra_sala.id)  # y el domo, en el cuarto nuevo
      expect(lote.estado).to eq('enraizado')               # mover NO lo saca del enraizado
    end

    # El domo no puede entrar a un cuarto 12/12: los esquejes necesitan luz casi continua. Se avisa
    # el motivo en vez de mover el lote a una sala donde su domo no puede estar.
    it 'pero no lo lleva a una sala de floración' do
      lote = create(:lote, club: club, sala: vege, estado: 'enraizado', clonador: clonador)

      post '/api/lotes/mover', params: { lote_ids: [lote.id], sala_id: flora.id }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/clonador/i)
      expect(lote.reload.sala_id).to eq(vege.id)
      expect(clonador.reload.sala_id).to eq(vege.id)
    end

    it 'rechaza un clonador de otra sala al editar el lote a mano' do
      otra_sala = create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo')
      lote = create(:lote, club: club, sala: otra_sala, estado: 'enraizado')

      patch "/api/lotes/#{lote.id}", params: { lote: { clonador_id: clonador.id } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(lote.reload.clonador_id).to be_nil
    end
  end

  # El esqueje que prendió va a maceta. Sin ese dato el lote entra a vegetativo sin saber en qué
  # volumen crece, que es lo que gobierna riego, frecuencia y cuándo toca trasplante. Aplica a todo
  # lote que prende, venga o no de un domo.
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

      post "/api/lotes/#{lote.id}/avanzar_fase", params: { tamanio_maceta: 7 }

      expect(response).to have_http_status(:success)
      expect(lote.reload.estado).to eq('vegetativo')
      expect(lote.tamanio_maceta.to_f).to eq(7.0)
      # La primera maceta también queda como la inicial: es la que deja reconstruir los trasplantes.
      expect(lote.tamanio_maceta_inicial.to_f).to eq(7.0)
    end

    it 'no pisa la maceta inicial si el lote ya tenía uno registrado' do
      lote = create(:lote, club: club, sala: vege, estado: 'enraizado',
                           tamanio_maceta_inicial: 1, tamanio_maceta: nil)

      post "/api/lotes/#{lote.id}/avanzar_fase", params: { tamanio_maceta: 7 }

      expect(response).to have_http_status(:success)
      expect(lote.reload.tamanio_maceta_inicial.to_f).to eq(1.0)
      expect(lote.tamanio_maceta.to_f).to eq(7.0)
    end

    # De floración en adelante no se pide: la maceta ya está puesta desde que prendió.
    it 'no la pide en los avances posteriores' do
      lote = create(:lote, club: club, sala: vege, estado: 'vegetativo', tamanio_maceta: nil)

      post "/api/lotes/#{lote.id}/avanzar_fase"

      expect(response).to have_http_status(:success)
      expect(lote.reload.estado).to eq('floracion')
    end
  end

  # El domo tiene su propio microclima: si el lote de adentro recibiera TAMBIÉN el registro de la
  # sala, quedarían dos lecturas contradictorias del mismo momento (60% y 90%) y las alertas y la
  # analítica promediarían un ambiente que no existió.
  describe 'el registro de la sala no pisa el del domo' do
    it 'saltea los lotes que están adentro de un clonador' do
      clonador = create(:clonador, club: club, sala: vege, nombre: 'C1')
      adentro  = create(:lote, club: club, sala: vege, estado: 'enraizado', clonador: clonador)
      afuera   = create(:lote, club: club, sala: vege, estado: 'vegetativo')

      post "/api/salas/#{vege.id}/registrar_sala",
           params: { registro_ambiental: { temperatura: 22, humedad: 60 } }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['lotes_afectados']).to eq(1)
      expect(afuera.registros_ambientales.count).to eq(1)
      expect(adentro.registros_ambientales.count).to eq(0)
    end

    # Ya prendió: está en el cuarto y respira el aire de la sala, aunque conserve su clonador.
    it 'pero sí incluye al que ya prendió y conserva su clonador de origen' do
      clonador = create(:clonador, club: club, sala: vege, nombre: 'C1')
      lote = create(:lote, club: club, sala: vege, estado: 'enraizado', clonador: clonador)
      lote.update!(estado: 'vegetativo', tamanio_maceta: 3)

      post "/api/salas/#{vege.id}/registrar_sala",
           params: { registro_ambiental: { temperatura: 22, humedad: 60 } }

      expect(JSON.parse(response.body)['lotes_afectados']).to eq(1)
      expect(lote.registros_ambientales.count).to eq(1)
    end
  end

  describe 'capacidad' do
    it 'cuenta ocupados y disponibles por las plantas que tiene adentro' do
      clonador = create(:clonador, club: club, sala: vege, nombre: 'C1', capacidad: 100)
      lote = create(:lote, club: club, sala: vege, estado: 'enraizado', clonador: clonador)
      3.times { |i| create(:plant, lote: lote, state: 'enraizado', nombre: "P#{i}") }

      get "/api/salas/#{vege.id}/clonadores"
      body = JSON.parse(response.body).first
      expect(body['ocupados']).to eq(3)
      expect(body['disponibles']).to eq(97)
    end
  end

  describe 'aislamiento' do
    it 'no lista clonadores de otro club' do
      otro = create(:club)
      otro_admin = create(:user, :admin, club: otro)
      ActsAsTenant.with_tenant(otro) do
        s = create(:sede, club: otro, created_by: otro_admin)
        sa = create(:sala, club: otro, sede: s, created_by: otro_admin, kind: 'vegetativo')
        create(:clonador, club: otro, sala: sa, nombre: 'Ajeno')
      end
      create(:clonador, club: club, sala: vege, nombre: 'Mío')

      get '/api/clonadores'
      expect(JSON.parse(response.body).map { |c| c['nombre'] }).to eq(['Mío'])
    end
  end
end
