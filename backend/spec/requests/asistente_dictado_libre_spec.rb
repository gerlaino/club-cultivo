require 'rails_helper'

# AC (7-oct-2026, Germán): con el micrófono abierto sin elegir nada se puede dictar sobre
# cualquier lote o espacio nombrándolo como en la app («la Ananda», «la carpa»), y cada evento
# se guarda por separado donde corresponde. Una tarea dictada («mañana revisar plagas en la
# Ananda») queda para ese día, en ese lote y con su tipo. Y un dictado se guarda UNA vez:
# los registros se multiplicaban (la frase llegaba dos veces, o se reintentaba el guardado).
RSpec.describe 'Asistente: dictado libre, espacios por nombre y tareas', type: :request do
  let(:club)  { create(:club, plan: 'total', features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:carpa) { create(:sala, club: club, nombre: 'Carpa grande', kind: 'mixta', created_by: admin) }
  let(:flora) { create(:sala, club: club, nombre: 'Flora', kind: 'mixta', created_by: admin) }
  let(:flora2) { create(:sala, club: club, nombre: 'Flora 2', kind: 'mixta', created_by: admin) }
  let(:ananda) { create(:genetica, club: club, nombre: 'Ananda') }
  let!(:lote_ananda) { create(:lote, club: club, sala: carpa, genetica: ananda, codigo: 'L-26-001', estado: 'vegetativo') }
  let!(:lote_otro)   { create(:lote, club: club, sala: flora2, codigo: 'L-26-002', estado: 'floracion') }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }
  before { sign_in_as(admin) }

  def ejecutar(acciones, contexto: nil, correccion_id: nil)
    post '/api/asistente/ejecutar',
         params: { acciones: acciones, contexto: contexto, correccion_id: correccion_id }.compact, as: :json
    response.parsed_body
  end

  describe 'el mapa del cultivo llega a la IA aunque no se haya elegido nada' do
    it 'con los espacios, los códigos y la genética de cada lote, y la fecha de hoy' do
      flora # existe
      enviado = nil
      http = double('http', 'use_ssl=': true, 'read_timeout=': 30)
      allow(http).to receive(:request) { |req| enviado = JSON.parse(req.body); double(code: '200', body: { content: [{ text: '{"resumen":"ok","acciones":[]}' }], usage: {} }.to_json) }
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('clave-de-prueba')

      post '/api/asistente/parsear', params: { texto: 'regué la Ananda' }, as: :json

      expect(response).to have_http_status(:ok), response.body
      sistema = enviado['system'].map { |b| b['text'] }.join
      expect(sistema).to include('MAPA DEL CULTIVO', '«Carpa grande»', '«Flora»', 'L-26-001 | Ananda')
      expect(sistema).to include("HOY: ")
    end
  end

  describe 'un registro de espacio por su nombre' do
    it 'se aplica a los lotes de ESE espacio, y no a los de otro' do
      r = ejecutar([{ tipo: 'registro_ambiental_sala', sala_nombre: 'carpa grande',
                      datos: { tareas_realizadas: ['riego'], temperatura: 25 } }])

      expect(r['ejecutadas']).to eq(1), r.inspect
      expect(lote_ananda.registros_ambientales.count).to eq(1)
      expect(lote_otro.registros_ambientales.count).to eq(0)
    end

    it 'un nombre parecido no cae en otro espacio: «Flora» no es «Flora 2»' do
      flora
      ejecutar([{ tipo: 'registro_ambiental_sala', sala_nombre: 'Flora', datos: { temperatura: 24 } }])

      expect(lote_otro.registros_ambientales.count).to eq(0)
    end

    it 'un espacio que no existe se rechaza con el motivo' do
      r = ejecutar([{ tipo: 'nota_sala', sala_nombre: 'Invernadero', datos: { contenido: 'hola' } }])

      expect(r['errores']).to eq(1)
      expect(r['errores_detalle'].first['error']).to include('espacio')
    end

    it 'la nota de espacio va al espacio nombrado' do
      ejecutar([{ tipo: 'nota_sala', sala_nombre: 'Carpa grande', datos: { contenido: 'huele a cogollo' } }])

      expect(carpa.notas.pluck(:contenido)).to eq(['huele a cogollo'])
    end
  end

  describe 'una tarea dictada' do
    let(:manana) { Time.zone.today + 1 }

    def tarea(datos = {})
      { tipo: 'tarea', datos: { titulo: 'Revisar plagas', tipo_tarea: 'revision_plagas',
                                lote_codigo: 'L-26-001', dias_desde_hoy: 1 }.merge(datos) }
    end

    it 'queda para mañana, en ese lote, en su espacio y con su tipo' do
      r = ejecutar([tarea])

      expect(r['ejecutadas']).to eq(1), r.inspect
      t = club.tareas.last
      expect(t).to have_attributes(tipo: 'revision_plagas', fecha_programada: manana,
                                   lote_id: lote_ananda.id, sala_id: carpa.id, estado: 'pendiente')
    end

    # El bug: la prioridad por defecto era «media», que no existe, y la tarea no se guardaba.
    it 'sin prioridad dicha, se guarda como normal' do
      ejecutar([tarea])
      expect(club.tareas.last.prioridad).to eq('normal')
    end

    # Antes caía a «dentro de 7 días» en silencio.
    it 'sin día no se inventa uno: no se crea y dice por qué' do
      r = ejecutar([tarea(dias_desde_hoy: nil)])

      expect(club.tareas.count).to eq(0)
      expect(r['errores_detalle'].first['error']).to include('¿Para cuándo')
    end

    it 'el lote nombrado manda sobre el lote desde donde se abrió el asistente' do
      ejecutar([tarea(lote_codigo: 'L-26-002')], contexto: { tipo: 'lote', lote_id: lote_ananda.id })

      expect(club.tareas.last.lote_id).to eq(lote_otro.id)
    end

    it 'sin lote nombrado, toma el del contexto' do
      ejecutar([tarea(lote_codigo: nil)], contexto: { tipo: 'lote', lote_id: lote_otro.id })

      expect(club.tareas.last.lote_id).to eq(lote_otro.id)
    end

    it 'no se duplica si se dicta dos veces la misma' do
      ejecutar([tarea])
      r = ejecutar([tarea(titulo: 'revisar plagas')])

      expect(club.tareas.count).to eq(1)
      expect(r['resultados'].first['mensaje']).to include('ya estaba')
    end

    it 'la misma tarea para OTRO lote sí se crea' do
      ejecutar([tarea])
      ejecutar([tarea(lote_codigo: 'L-26-002')])

      expect(club.tareas.count).to eq(2)
    end

    # Con su tipo, el registro de «revisé plagas» de mañana la da por hecha.
    it 'el registro de esa actividad la reconoce para cerrarla' do
      ejecutar([tarea])

      candidatas = Tarea.candidatas_por_registro(tareas_realizadas: ['revision_plagas'], usuario: admin,
                                                 es_privilegiado: true, lote: lote_ananda)
      expect(candidatas).to include(club.tareas.last)
    end

    it 'no toma un lote de otra organización' do
      otra = create(:club)
      ActsAsTenant.with_tenant(otra) { create(:lote, club: otra, codigo: 'L-26-099') }

      r = ejecutar([tarea(lote_codigo: 'L-26-099')])

      expect(club.tareas.count).to eq(0)
      expect(r['errores']).to eq(1)
    end
  end

  # Un dictado se guarda una vez.
  describe 'guardar dos veces el mismo dictado' do
    let(:correccion) { AsistenteCorreccion.create!(club: club, user: admin, texto: 'regué la Ananda', propuesto: {}) }
    let(:riego) { [{ tipo: 'registro_ambiental', lote_codigo: 'L-26-001', datos: { tareas_realizadas: ['riego'] } }] }

    it 'la segunda vez se rechaza y no se duplica el registro' do
      ejecutar(riego, correccion_id: correccion.id)
      expect(response).to have_http_status(:ok)

      r = ejecutar(riego, correccion_id: correccion.id)

      expect(response).to have_http_status(:conflict)
      expect(r['ya_guardado']).to be(true)
      expect(lote_ananda.registros_ambientales.count).to eq(1)
    end

    it 'la misma acción repetida dentro de un dictado se guarda una sola vez' do
      ejecutar(riego + riego, correccion_id: correccion.id)

      expect(lote_ananda.registros_ambientales.count).to eq(1)
    end

    it 'dos dictados distintos sí se guardan los dos' do
      otro = AsistenteCorreccion.create!(club: club, user: admin, texto: 'regué de nuevo', propuesto: {})
      ejecutar(riego, correccion_id: correccion.id)
      ejecutar(riego, correccion_id: otro.id)

      expect(lote_ananda.registros_ambientales.count).to eq(2)
    end
  end

  # En una organización, un cultivador con sedes asignadas ve sólo sus salas. El asistente
  # (el mapa y cada búsqueda) respeta lo mismo: por voz no se toca otra sede.
  describe 'un cultivador asignado a una sede' do
    let(:sede_a) { create(:sede, club: club, created_by: admin) }
    let(:sede_b) { create(:sede, club: club, created_by: admin) }
    let(:sala_a) { create(:sala, club: club, sede: sede_a, nombre: 'Vege A', kind: 'vegetativo', created_by: admin) }
    let(:sala_b) { create(:sala, club: club, sede: sede_b, nombre: 'Vege B', kind: 'vegetativo', created_by: admin) }
    let!(:lote_a) { create(:lote, club: club, sala: sala_a, codigo: 'L-26-010', estado: 'vegetativo') }
    let!(:lote_b) { create(:lote, club: club, sala: sala_b, codigo: 'L-26-011', estado: 'vegetativo') }
    let(:cultivador) { create(:user, :cultivador, club: club) }

    before do
      UserSede.create!(user: cultivador, sede: sede_a)
      delete '/api/users/sign_out'
      sign_in_as(cultivador)
    end

    it 'registra en su sede' do
      ejecutar([{ tipo: 'registro_ambiental', lote_codigo: 'L-26-010', datos: { tareas_realizadas: ['riego'] } }])
      expect(lote_a.registros_ambientales.count).to eq(1)
    end

    it 'no registra en un lote de otra sede aunque diga el código' do
      r = ejecutar([{ tipo: 'registro_ambiental', lote_codigo: 'L-26-011', datos: { tareas_realizadas: ['riego'] } }])

      expect(lote_b.registros_ambientales.count).to eq(0)
      expect(r['errores']).to eq(1)
    end

    it 'ni en un espacio de otra sede por su nombre' do
      ejecutar([{ tipo: 'registro_ambiental_sala', sala_nombre: 'Vege B', datos: { temperatura: 25 } }])
      expect(lote_b.registros_ambientales.count).to eq(0)
    end

    # 7-oct-2026 (Germán): lo que le quedó pendiente lo anota él, y queda a su nombre (la misma
    # regla que el alta de tareas: el cultivador se asigna a sí mismo).
    it 'crea su tarea por voz, asignada a él' do
      r = ejecutar([{ tipo: 'tarea', datos: { titulo: 'Terminar de defoliar', tipo_tarea: 'defoliacion',
                                              lote_codigo: 'L-26-010', dias_desde_hoy: 1 } }])

      expect(r['ejecutadas']).to eq(1), r.inspect
      expect(club.tareas.last).to have_attributes(asignada_a_id: cultivador.id, creada_por_id: cultivador.id,
                                                  lote_id: lote_a.id, fecha_programada: Time.zone.today + 1)
    end

    it 'aunque nombre a otro, queda a su nombre' do
      otro = create(:user, :cultivador, club: club, first_name: 'Pedro')
      ejecutar([{ tipo: 'tarea', datos: { titulo: 'Podar', tipo_tarea: 'poda', lote_codigo: 'L-26-010',
                                          dias_desde_hoy: 1, asignar_a: 'Pedro' } }])

      expect(club.tareas.last.asignada_a_id).to eq(cultivador.id)
      expect(club.tareas.last.asignada_a_id).not_to eq(otro.id)
    end

    it 'no en un lote de otra sede' do
      r = ejecutar([{ tipo: 'tarea', datos: { titulo: 'Podar', tipo_tarea: 'poda', lote_codigo: 'L-26-011', dias_desde_hoy: 1 } }])

      expect(club.tareas.count).to eq(0)
      expect(r['errores']).to eq(1)
    end

    it 'no se manda un aviso a sí mismo' do
      expect(PushNotificationService).not_to receive(:notify_user_async)
      ejecutar([{ tipo: 'tarea', datos: { titulo: 'Regar', tipo_tarea: 'riego', lote_codigo: 'L-26-010', dias_desde_hoy: 1 } }])
    end
  end

  # El admin dicta «mañana el cultivador revisa plagas del lote X»: la tarea queda asignada a esa
  # persona, y le llega el aviso.
  describe 'el admin asigna una tarea por voz' do
    let!(:juan) { create(:user, :cultivador, club: club, first_name: 'Juan', last_name: 'Pérez') }

    def tarea_para(quien)
      [{ tipo: 'tarea', datos: { titulo: 'Revisar plagas', tipo_tarea: 'revision_plagas',
                                 lote_codigo: 'L-26-001', dias_desde_hoy: 1, asignar_a: quien }.compact }]
    end

    it 'por rol, si hay uno solo de ese rol' do
      ejecutar(tarea_para('el cultivador'))
      expect(club.tareas.last.asignada_a_id).to eq(juan.id)
    end

    it 'por nombre' do
      ejecutar(tarea_para('Juan'))
      expect(club.tareas.last.asignada_a_id).to eq(juan.id)
    end

    it 'le avisa a quien se la asignó' do
      expect(PushNotificationService).to receive(:notify_user_async).with(juan, hash_including(tipo: 'tarea_asignada'))
      ejecutar(tarea_para('Juan'))
    end

    it 'sin decir quién, queda sin asignar' do
      ejecutar(tarea_para(nil))
      expect(club.tareas.last.asignada_a_id).to be_nil
    end

    # Lo ambiguo no se adivina: asignarle la tarea a otro es peor que no crearla.
    it 'con dos del mismo rol no adivina: no la crea y pide a cuál' do
      create(:user, :cultivador, club: club, first_name: 'Pedro')
      r = ejecutar(tarea_para('el cultivador'))

      expect(club.tareas.count).to eq(0)
      expect(r['errores_detalle'].first['error']).to include('decí a cuál')
    end

    it 'un nombre que no es del equipo no se asigna a nadie: no la crea y lo dice' do
      r = ejecutar(tarea_para('Roberto'))

      expect(club.tareas.count).to eq(0)
      expect(r['errores_detalle'].first['error']).to include('Roberto')
    end

    it 'no se le puede asignar a un paciente' do
      create(:user, club: club, role: 'paciente', first_name: 'Marta')
      ejecutar(tarea_para('Marta'))
      expect(club.tareas.count).to eq(0)
    end

    it 'el equipo va en el mapa que recibe la IA' do
      enviado = nil
      http = double('http', 'use_ssl=': true, 'read_timeout=': 30)
      allow(http).to receive(:request) { |req| enviado = JSON.parse(req.body); double(code: '200', body: { content: [{ text: '{"resumen":"ok","acciones":[]}' }], usage: {} }.to_json) }
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('clave-de-prueba')

      post '/api/asistente/parsear', params: { texto: 'mañana Juan revisa plagas' }, as: :json

      expect(enviado['system'].map { |b| b['text'] }.join).to include('EQUIPO', 'Juan Pérez (cultivador)')
    end
  end
end
