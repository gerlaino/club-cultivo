require 'rails_helper'

# SUELO VIVO — las camas (Germán, 22/25-sep-2026; `docs/PLAN_SUELO_VIVO.md`). Los tests afirman
# lo que se decidió, no lo que quedó escrito:
# - la cama es una entidad con historia; su estado se calcula;
# - las camas tienen que entrar en el espacio, y los lotes en la cama (no se cuentan dos veces);
# - en la cama no hay trasplantes ni maceta: plantar en la cama es el último trasplante (prende);
# - la planta no se muda: para florar cambia la fase del ESPACIO;
# - cuando sale el ÚLTIMO lote, la cama descansa los días que puso el cultivador (sin número, sin
#   fecha); plantar en una cama que descansa avisa pero NO se bloquea;
# - se alimenta el suelo (top dress por m², mezcla por litro de suelo), con la unidad del insumo.
RSpec.describe 'Suelo vivo: camas', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo', m2: 2.88) }

  before { sign_in_as(admin) }

  def crear_cama(attrs = {}, mezcla = nil)
    post '/camas', params: { cama: { sala_id: sala.id, nombre: 'Cama A', largo_m: 1.2, ancho_m: 1.2, profundidad_cm: 30 }.merge(attrs),
                             mezcla: mezcla }.compact, headers: auth_headers, as: :json
    json
  end

  def cama_a = ActsAsTenant.with_tenant(club) { Cama.find_by!(nombre: 'Cama A') }

  describe 'alta y medidas' do
    it 'calcula los m² y los litros de suelo de las medidas, y sin cocción está lista' do
      c = crear_cama
      expect(response).to have_http_status(:created), response.body
      expect(c['m2']).to eq(1.44)
      expect(c['litros_suelo']).to eq(432.0)  # 1,44 m² × 30 cm
      expect(c['estado']).to eq('lista')
      expect(c['proximo_paso']).to be_nil
    end

    it 'con semanas de cocción queda cocinando y dice cuándo está lista (el número lo pone el cultivador)' do
      c = crear_cama({ armada_el: Time.zone.today.to_s, semanas_coccion: 4 })
      expect(c['estado']).to eq('cocinando')
      expect(c['proximo_paso']).to include('tipo' => 'lista', 'fecha' => (Time.zone.today + 28).to_s)

      post "/camas/#{c['id']}/terminar_coccion", headers: auth_headers
      expect(json['estado']).to eq('lista')
    end

    it 'la app no inventa días de descanso ni frecuencia de top dress' do
      c = crear_cama
      expect(c['dias_descanso']).to be_nil
      expect(c['frecuencia_top_dress_dias']).to be_nil
    end
  end

  describe 'coherencia de m²' do
    it 'una cama que no entra en el espacio no se guarda, y dice cuánto queda' do
      crear_cama
      post '/camas', params: { cama: { sala_id: sala.id, nombre: 'Cama B', largo_m: 1.5, ancho_m: 1.2 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].join).to include('quedan 1,44 m² libres')
    end

    it 'dos camas que entran justo se guardan (la rotación clásica: A y B en el mismo espacio)' do
      crear_cama
      post '/camas', params: { cama: { sala_id: sala.id, nombre: 'Cama B', largo_m: 1.2, ancho_m: 1.2 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
    end

    it 'sin m² del espacio no bloquea nada' do
      sala.update!(m2: nil)
      crear_cama({ largo_m: 10, ancho_m: 10 })
      expect(response).to have_http_status(:created)
    end

    it 'los lotes de una cama ocupan la CAMA, no el espacio (no se cuentan dos veces)' do
      c = crear_cama
      post "/salas/#{sala.id}/lotes", params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 4, start_date: Time.zone.today, m2_ocupados: 1.44 } },
                                      headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      # Queda 1,44 m² del espacio: un lote SIN cama de 1,4 entra.
      post "/salas/#{sala.id}/lotes", params: { lote: { estado: 'vegetativo', plants_count: 2, start_date: Time.zone.today, m2_ocupados: 1.4 } },
                                      headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
    end

    it 'la suma de los lotes de una cama no puede pasar la cama' do
      c = crear_cama
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 2, start_date: Time.zone.today, m2_ocupados: 1.0 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 2, start_date: Time.zone.today, m2_ocupados: 0.5 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].join).to include('quedan 0.44 m² libres')
    end

    it 'no se puede achicar el espacio por debajo de lo que ocupan sus camas' do
      crear_cama
      patch "/salas/#{sala.id}", params: { sala: { m2: 1.0 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'plantar en la cama' do
    it 'siembra directa: el lote nace en la cama, enraizando, con la sala de la cama y el ciclo 1 abierto' do
      c = crear_cama
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'enraizado', plants_count: 3, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      expect(json['estado']).to eq('enraizado')
      expect(json['sala_id']).to eq(sala.id)
      expect(json['metodo_cultivo']).to eq('suelo_vivo')
      expect(json['cama']).to include('nombre' => 'Cama A', 'ciclo_numero' => 1)

      # Al germinar prende SIN maceta: la tierra es la cama.
      post "/lotes/#{json['id']}/avanzar_fase", headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok), response.body
      expect(json['estado']).to eq('vegetativo')
    end

    it 'desde la bandeja: plantar en la cama PRENDE el lote (el último trasplante)' do
      c = crear_cama
      lote = create(:lote, club: club, sala: sala, estado: 'enraizado')
      create(:plant, lote: lote, state: 'enraizado')
      post "/lotes/#{lote.id}/plantar_en_cama", params: { cama_id: c['id'], fecha: 2.days.ago.to_date.to_s }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok), response.body
      lote.reload
      expect(lote.estado).to eq('vegetativo')
      expect(lote.fecha_inicio_vegetativo).to eq(2.days.ago.to_date)
      expect(lote.plants.first.state).to eq('vegetativo')
      expect(lote.lote_eventos.where(tipo: 'cambio_estado').last.descripcion).to eq('Prendió: se plantó en la Cama A')
    end

    it 'desde el vasito (ya en vegetativo): queda como trasplante a la cama en la historia' do
      c = crear_cama
      lote = create(:lote, club: club, sala: sala, estado: 'vegetativo', tamanio_maceta: 1)
      post "/lotes/#{lote.id}/plantar_en_cama", params: { cama_id: c['id'] }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok), response.body
      ev = lote.reload.lote_eventos.where(categoria: 'trasplante').last
      expect(ev.metadata).to include('destino' => 'cama', 'cama' => 'Cama A', 'maceta_origen_l' => 1.0)
    end

    it 'en la cama no hay más trasplantes: ni del lote ni de una planta' do
      c = crear_cama
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      lote_id = json['id']
      post "/lotes/#{lote_id}/registrar_trasplante", params: { maceta_destino_l: 10 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('en la cama no hay trasplantes')

      planta = ActsAsTenant.with_tenant(club) { Lote.find(lote_id).plants.first }
      post "/plants/#{planta.id}/plant_activities", params: { plant_activity: { activity_type: 'transplant' } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'la planta no se muda: ni moviéndola ni editándole la sala' do
      c = crear_cama
      otra = create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo')
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      lote_id = json['id']
      post '/lotes/mover', params: { lote_ids: [lote_id], sala_id: otra.id }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      # La edición del lote no cambia la sala (no está entre lo editable): sigue en la de la cama.
      patch "/lotes/#{lote_id}", params: { lote: { sala_id: otra.id } }, headers: auth_headers, as: :json
      expect(ActsAsTenant.with_tenant(club) { Lote.find(lote_id).sala_id }).to eq(sala.id)
    end

    it 'para florar cambia la fase del ESPACIO: el lote solo no avanza, y la ficha lo dice' do
      c = crear_cama
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      lote_id = json['id']
      expect(json['avanza_con_el_espacio']).to be(true)

      post "/lotes/#{lote_id}/avanzar_fase", headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('La luz es del espacio')

      post "/salas/#{sala.id}/cambiar_fase", params: { confirmar_cambio_fase: true }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok), response.body
      lote = ActsAsTenant.with_tenant(club) { Lote.find(lote_id) }
      expect(lote.estado).to eq('floracion')
      expect(lote.sala_id).to eq(sala.id)
    end

    it 'tampoco lo avanza administración por la otra puerta (transiciones): dice lo mismo' do
      c = crear_cama
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      post "/lotes/#{json['id']}/transiciones", params: { nueva_fase: 'floracion', pesada: {} }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('La luz es del espacio')
    end

    it 'en un espacio mixto el lote avanza solo y no se mueve' do
      sala.update!(kind: 'mixta')
      c = crear_cama
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      create(:sala, club: club, sede: sede, created_by: admin, kind: 'floracion') # la «única de floración» no se lo lleva
      post "/lotes/#{json['id']}/avanzar_fase", headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok), response.body
      expect(json['estado']).to eq('floracion')
      expect(json['sala_id']).to eq(sala.id)
    end
  end

  describe 'ciclo y descanso' do
    def cosechar(lote_id)
      lote = ActsAsTenant.with_tenant(club) { Lote.find(lote_id) }
      ActsAsTenant.with_tenant(club) { lote.update!(estado: 'floracion'); lote.plants.update_all(state: 'floracion') }
      post "/lotes/#{lote_id}/cosechar_plantas", params: { plantas_ids: lote.plants.pluck(:id), peso_total_g: 500 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
    end

    it 'con dos lotes, la cama descansa recién cuando sale el ÚLTIMO' do
      sala.update!(kind: 'mixta')
      c = crear_cama({ dias_descanso: 20 })
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      l1 = json['id']
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      l2 = json['id']
      expect(json['cama']['ciclo_numero']).to eq(1) # comparten ciclo

      cosechar(l1)
      expect(cama_a.estado).to eq('en_uso')

      cosechar(l2)
      cama = cama_a
      expect(cama.estado).to eq('descansando')
      expect(cama.descansa_hasta).to eq(Time.zone.today + 20)
      expect(cama.ciclos.first.hasta).to eq(Time.zone.today)
      # La historia se queda en el lote: la cama y el ciclo en que creció.
      expect(ActsAsTenant.with_tenant(club) { Lote.find(l2).cama_id }).to eq(cama.id)
    end

    it 'sin días de descanso cargados descansa sin fecha, hasta que el cultivador diga' do
      sala.update!(kind: 'mixta')
      c = crear_cama
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      cosechar(json['id'])
      expect(cama_a.estado).to eq('descansando')
      expect(cama_a.descansa_hasta).to be_nil

      post "/camas/#{c['id']}/descansar", params: { dias: 45 }, headers: auth_headers, as: :json
      expect(json['descansa_hasta']).to eq((Time.zone.today + 45).to_s)
      post "/camas/#{c['id']}/terminar_descanso", headers: auth_headers
      expect(json['estado']).to eq('lista')
    end

    it 'plantar en una cama que descansa NO se bloquea: corta el descanso y abre el ciclo 2' do
      sala.update!(kind: 'mixta')
      c = crear_cama({ dias_descanso: 30 })
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      cosechar(json['id'])
      expect(cama_a.estado).to eq('descansando')

      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      expect(json['cama']['ciclo_numero']).to eq(2)
      expect(cama_a.estado).to eq('en_uso')
    end

    it 'corregir la cama de un lote recién cargado no deja un ciclo fantasma ni pone a descansar la cama' do
      crear_cama
      post '/camas', params: { cama: { sala_id: sala.id, nombre: 'Cama B', largo_m: 1.2, ancho_m: 1.2 } }, headers: auth_headers, as: :json
      b = json['id']
      post '/lotes', params: { lote: { cama_id: cama_a.id, estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      lote_id = json['id']
      patch "/lotes/#{lote_id}", params: { lote: { cama_id: b } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok), response.body
      expect(cama_a.ciclos).to be_empty
      expect(cama_a.estado).to eq('lista')
      expect(json['cama']).to include('id' => b, 'ciclo_numero' => 1)
    end

    it 'con registros de suelo en el ciclo, la cama del lote ya no se corrige' do
      crear_cama
      post '/camas', params: { cama: { sala_id: sala.id, nombre: 'Cama B', largo_m: 1.2, ancho_m: 1.2 } }, headers: auth_headers, as: :json
      b = json['id']
      post '/lotes', params: { lote: { cama_id: cama_a.id, estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      lote_id = json['id']
      post "/camas/#{cama_a.id}/registros", params: { registro: { tipo: 'mulch', detalle: 'paja' } }, headers: auth_headers, as: :json
      patch "/lotes/#{lote_id}", params: { lote: { cama_id: b } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].join).to include('ya hay registros de suelo')
    end
  end

  describe 'alimentar el suelo' do
    let(:harina) do
      ActsAsTenant.with_tenant(club) do
        i = club.insumos.create!(nombre: 'Harina de kelp', unidad_medida: 'kilogramo', sede: sede)
        i.registrar_compra!(cantidad: 10, costo_total_ars: 50_000, created_by: admin, generar_egreso: false) # $5.000/kg
        i
      end
    end
    let(:humus) do
      ActsAsTenant.with_tenant(club) do
        i = club.insumos.create!(nombre: 'Humus', unidad_medida: 'litro', sede: sede)
        i.registrar_compra!(cantidad: 500, costo_total_ars: 100_000, created_by: admin, generar_egreso: false)
        i
      end
    end

    def receta(uso, items, extra = {})
      post '/recetas', params: { receta: { nombre: "R #{uso} #{rand(1000)}", uso: uso, receta_items_attributes: items }.merge(extra) }, headers: auth_headers, as: :json
      json
    end

    it 'el top dress va por m² y descuenta en la unidad del insumo (g/m² contra una bolsa en kg)' do
      r = receta('top_dress', [{ insumo_id: harina.id, dosis: 100, unidad: 'g_m2' }])
      expect(response).to have_http_status(:created), response.body
      c = crear_cama
      post "/camas/#{c['id']}/registros", params: { registro: { tipo: 'top_dress' }, nutricion: { receta_id: r['id'] } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      # 100 g/m² × 1,44 m² = 144 g = 0,144 kg (no 144 kg)
      expect(json['nutricion']['items'].first).to include('cantidad' => 0.144, 'descontado' => 0.144)
      expect(harina.reload.stock_actual.to_f).to eq(9.856)
      expect(json['nutricion']['base_unidad']).to eq('m²')
    end

    it 'con la cama vacía la plata queda en la cama; con dos lotes se reparte por sus m²' do
      r = receta('top_dress', [{ insumo_id: harina.id, dosis: 1000, unidad: 'g_m2' }]) # 1 kg/m² → 1,44 kg = $7.200
      c = crear_cama
      post "/camas/#{c['id']}/registros", params: { registro: { tipo: 'top_dress', recarga: true }, nutricion: { receta_id: r['id'] } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      consumos = ActsAsTenant.with_tenant(club) { InsumoConsumo.where(cama_id: c['id']).to_a }
      expect(consumos.map(&:lote_id)).to eq([nil])

      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today, m2_ocupados: 1.08 } }, headers: auth_headers, as: :json
      l1 = json['id']
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today, m2_ocupados: 0.36 } }, headers: auth_headers, as: :json
      l2 = json['id']
      post "/camas/#{c['id']}/registros", params: { registro: { tipo: 'top_dress' }, nutricion: { receta_id: r['id'] } }, headers: auth_headers, as: :json
      por_lote = ActsAsTenant.with_tenant(club) { InsumoConsumo.where(cama_registro_id: json['id']).to_h { |x| [x.lote_id, x.costo_imputado_ars.to_f] } }
      expect(por_lote[l1]).to eq(5400.0)  # 75 %
      expect(por_lote[l2]).to eq(1800.0)  # 25 %

      get "/camas/#{c['id']}", headers: auth_headers
      expect(json['invertido_ars']).to eq(14_400.0)
    end

    it 'la receta tiene que ser del uso que corresponde (un top dress no va con la receta del riego)' do
      r = receta('riego', [{ insumo_id: humus.id, dosis: 1, unidad: 'ml_l' }])
      c = crear_cama
      post "/camas/#{c['id']}/registros", params: { registro: { tipo: 'top_dress' }, nutricion: { receta_id: r['id'] } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('es de riego o té')
    end

    it 'cada uso admite sólo sus unidades, y pH/EC son sólo del agua' do
      receta('top_dress', [{ insumo_id: harina.id, dosis: 2, unidad: 'ml_l' }])
      expect(response).to have_http_status(:unprocessable_entity)
      receta('top_dress', [{ insumo_id: harina.id, dosis: 2, unidad: 'g_m2' }], ph_objetivo: 6.5)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'armar la cama con su mezcla descuenta por litro de suelo y no se le carga a ningún lote' do
      r = receta('mezcla', [{ insumo_id: humus.id, dosis: 0.33, unidad: 'l_l_suelo' }, { insumo_id: harina.id, dosis: 3, unidad: 'g_l_suelo' }])
      c = crear_cama({}, { receta_id: r['id'] })
      expect(response).to have_http_status(:created), response.body
      # 432 L de suelo: 142,56 L de humus y 1,296 kg de kelp
      expect(humus.reload.stock_actual.to_f).to eq(357.44)
      expect(harina.reload.stock_actual.to_f).to eq(8.704)
      expect(c['mezcla']['items'].map { |i| i['nombre'] }).to eq(['Humus', 'Harina de kelp'])
      expect(ActsAsTenant.with_tenant(club) { InsumoConsumo.where(cama_id: c['id']).where.not(lote_id: nil).count }).to eq(0)
    end

    it 'borrar un registro de la cama devuelve al depósito lo que descontó' do
      r = receta('top_dress', [{ insumo_id: harina.id, dosis: 100, unidad: 'g_m2' }])
      c = crear_cama
      post "/camas/#{c['id']}/registros", params: { registro: { tipo: 'top_dress' }, nutricion: { receta_id: r['id'] } }, headers: auth_headers, as: :json
      delete "/camas/#{c['id']}/registros/#{json['id']}", headers: auth_headers
      expect(response).to have_http_status(:no_content)
      expect(harina.reload.stock_actual.to_f).to eq(10.0)
    end

    it 'regar la cama: con plantas va a cada lote (con el agua); descansando va a la cama' do
      c = crear_cama
      post "/camas/#{c['id']}/regar", params: { litros: 30, agua: 'lluvia' }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      expect(json['en']).to eq('cama')

      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      lote_id = json['id']
      post "/camas/#{c['id']}/regar", params: { litros: 40, agua: 'declorada' }, headers: auth_headers, as: :json
      expect(json).to include('en' => 'lotes', 'lotes_afectados' => 1)
      r = ActsAsTenant.with_tenant(club) { RegistroAmbiental.where(lote_id: lote_id).last }
      expect(r.agua).to eq('declorada')
      expect(r.observaciones).to include('Riego de la Cama A: 40 L')

      # Con plantas, el riego no entra como registro de la cama (quedaría fuera de la historia del lote).
      post "/camas/#{c['id']}/registros", params: { registro: { tipo: 'riego', litros: 5 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'trazabilidad: ¿qué comió esta flor?' do
    it 'trae la historia de la cama hasta la cosecha, con lo de su ciclo marcado' do
      sala.update!(kind: 'mixta')
      c = crear_cama
      post "/camas/#{c['id']}/registros", params: { registro: { tipo: 'cobertura', detalle: 'trébol blanco', registrado_en: 10.days.ago.iso8601 } }, headers: auth_headers, as: :json
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: 5.days.ago.to_date } }, headers: auth_headers, as: :json
      lote_id = json['id']
      post "/camas/#{c['id']}/registros", params: { registro: { tipo: 'mulch', detalle: 'paja de alfalfa' } }, headers: auth_headers, as: :json

      get "/lotes/#{lote_id}/trazabilidad", headers: auth_headers
      suelo = json['suelo']
      expect(suelo['cama']['nombre']).to eq('Cama A')
      detalles = suelo['registros'].to_h { |r| [r['detalle'], r['del_ciclo']] }
      expect(detalles).to eq('trébol blanco' => false, 'paja de alfalfa' => true)
      expect(json['aplicaciones']['suelo']['detalles']).to eq(['paja de alfalfa'])
    end

    it 'un lote sin cama no tiene sección de suelo' do
      lote = create(:lote, club: club, sala: sala)
      get "/lotes/#{lote.id}/trazabilidad", headers: auth_headers
      expect(json['suelo']).to be_nil
    end
  end

  describe 'plan de trabajo en un lote de cama' do
    let(:plan) do
      ActsAsTenant.with_tenant(club) do
        p = PlanTrabajo.create!(club: club, creado_por: admin, titulo: 'Plan', estado: :publicado, periodo_tipo: :semanal,
                                fecha_inicio: Time.zone.today, fecha_fin: Time.zone.today + 20)
        %w[riego trasplante nutricion].each { |t| PlanTarea.create!(plan_trabajo: p, titulo: t, tipo: t, prioridad: 'normal') }
        p
      end
    end

    it 'saltea trasplantes y fertilizaciones en un lote de cama, y en uno sin cama no' do
      c = crear_cama
      post '/lotes', params: { lote: { cama_id: c['id'], estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      en_cama = json['id']
      sin_cama = create(:lote, club: club, sala: sala)

      post "/lotes/#{en_cama}/aplicar_plan", params: { plan_trabajo_id: plan.id }, headers: auth_headers, as: :json
      expect(json).to include('tareas_creadas' => 1, 'tareas_omitidas' => 2)
      post "/lotes/#{sin_cama.id}/aplicar_plan", params: { plan_trabajo_id: plan.id }, headers: auth_headers, as: :json
      expect(json).to include('tareas_creadas' => 3, 'tareas_omitidas' => 0)
    end
  end

  describe 'aislamiento' do
    let(:otro_club) { create(:club, features: { 'cultivo' => true }) }
    let(:otra_cama) do
      ActsAsTenant.with_tenant(otro_club) do
        admin2 = create(:user, :admin, club: otro_club)
        s = create(:sala, club: otro_club, created_by: admin2)
        Cama.create!(club: otro_club, sala: s, nombre: 'Ajena')
      end
    end

    it 'la cama de otra organización no se ve, ni se riega, ni se planta en ella' do
      get "/camas/#{otra_cama.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
      post "/camas/#{otra_cama.id}/regar", params: { litros: 5 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:not_found)
      post '/lotes', params: { lote: { cama_id: otra_cama.id, estado: 'vegetativo', plants_count: 1, start_date: Time.zone.today } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      get '/camas', headers: auth_headers
      expect(json.map { |c| c['id'] }).not_to include(otra_cama.id)
    end

    it 'un cultivador ve las camas de sus salas y no las de otras' do
      crear_cama
      otra_sede = create(:sede, club: club, created_by: admin)
      cultivador = create(:user, :cultivador, club: club)
      UserSede.create!(user: cultivador, sede: otra_sede) if defined?(UserSede)
      sign_in_as(cultivador)
      get "/camas/#{cama_a.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
