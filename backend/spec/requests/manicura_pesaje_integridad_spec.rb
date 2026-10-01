require 'rails_helper'

# AC (Germán, 1-oct-2026: «manicura y pesajes: no podemos fallar ahí»). Lo que se fija acá:
# - un pesaje entra UNA vez al stock aunque lo confirmen dos a la vez;
# - una planta se pesa en UNA jornada (corregir: misma jornada, reabrirla, o reajustar si ya se
#   confirmó) y una descartada no se pesa;
# - borrar una jornada deja sus plantas sin pesar (y el lote puede cerrar);
# - reajustar después del cierre corrige el rendimiento del lote;
# - el pesaje va a un frasco de flor seca abierto del lote.
RSpec.describe 'Manicura: integridad del pesaje', type: :request do
  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'vegetativo', plants_count: 3) }
  let!(:p1)   { create(:plant, lote: lote, state: 'secado', nombre: 'P1') }
  let!(:p2)   { create(:plant, lote: lote, state: 'secado', nombre: 'P2') }
  let!(:p3)   { create(:plant, lote: lote, state: 'secado', nombre: 'P3') }

  before do
    ActsAsTenant.with_tenant(club) { lote.update_columns(estado: 'en_manicura', sala_id: nil, sede_id: sede.id) }
    sign_in_as(admin)
  end

  def json = JSON.parse(response.body)
  def t(&) = ActsAsTenant.with_tenant(club, &)
  def stock_total = t { Stock.where(lote_id: lote.id).sum(:cantidad).to_f }
  def pesar(p, g, extra = {}) = post("/plants/#{p.id}/registrar_peso", params: { peso_seco_g: g }.merge(extra), headers: auth_headers, as: :json)
  def jornada = t { lote.pesajes_manicura.order(:id).last }
  def enviar(j) = post("/lotes/#{lote.id}/pesajes_manicura/#{j.id}/enviar", headers: auth_headers, as: :json)
  def confirmar(j, g, extra = {}) = post("/lotes/#{lote.id}/pesajes_manicura/#{j.id}/confirmar", params: { peso_confirmado_g: g }.merge(extra), headers: auth_headers, as: :json)
  def resto(g, extra = {}) = post("/lotes/#{lote.id}/pesajes_manicura", params: { peso_total_g: g, enviar: true, force_new: true }.merge(extra), headers: auth_headers, as: :json)

  describe 'confirmar dos veces' do
    it 'dos confirmaciones a la vez: el peso entra una sola vez y la segunda dice que ya estaba' do
      pesar(p1, 10); j = jornada; enviar(j)
      a = t { PesajeManicura.find(j.id) }
      b = t { PesajeManicura.find(j.id) } # la copia vieja de la segunda request
      t { a.confirmar!(confirmado_por: admin, peso_confirmado_g: 10) }
      expect { t { b.confirmar!(confirmado_por: admin, peso_confirmado_g: 10) } }.to raise_error(RuntimeError, /ya fue confirmado/)
      expect(stock_total).to eq(10.0)
    end

    it 'por la API, la segunda responde 422 y no suma' do
      pesar(p1, 10); j = jornada; enviar(j)
      confirmar(j, 10)
      confirmar(j, 10)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to match(/ya fue confirmado/)
      expect(stock_total).to eq(10.0)
    end
  end

  describe 'una planta, una jornada' do
    it 'no se vuelve a pesar si su jornada ya se confirmó, y dice cómo corregirla' do
      pesar(p1, 10); j = jornada; enviar(j); confirmar(j, 10)
      pesar(p1, 12)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('P1 ya está pesada', 'reajusta')
      expect(stock_total).to eq(10.0)
      expect(t { p1.reload.peso_seco.to_f }).to eq(10.0)
    end

    it 'si su jornada está enviada, «empezar una nueva» no la duplica: hay que reabrirla' do
      pesar(p1, 10); j = jornada; enviar(j)
      pesar(p1, 12, force_new: true)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('reabrí esa jornada')
    end

    it 'reabierta, se corrige el peso dentro de la misma jornada (sin duplicar)' do
      pesar(p1, 10); j = jornada; enviar(j)
      post "/lotes/#{lote.id}/pesajes_manicura/#{j.id}/reabrir", headers: auth_headers, as: :json
      pesar(p1, 12)
      expect(response).to have_http_status(:ok), response.body
      expect(t { j.reload.pesadas_plantas.pluck(:plant_id, :peso_seco_g).map { |a, b| [a, b.to_f] } }).to eq([[p1.id, 12.0]])
    end

    # La cola sin señal reintenta el mismo peso cuando la primera vez sí había llegado (se perdió la
    # respuesta) y la jornada ya se envió: no es una falla, es «ya registrado».
    it 'el reintento del mismo peso desde la cola sin señal no es una falla' do
      pesar(p1, 10); j = jornada; enviar(j)
      pesar(p1, 10, force_new: true)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json).to include('ya_registrado' => true)
      pesar(p1, 11, force_new: true) # otro peso: eso sí es un conflicto de verdad
      expect(json).to include('ya_registrado' => false)
    end

    it 'en la misma jornada abierta se corrige libremente' do
      pesar(p1, 10); pesar(p1, 11)
      expect(response).to have_http_status(:ok)
      expect(t { jornada.pesadas_plantas.count }).to eq(1)
    end

    it '«registrar directo» del admin con una planta ya pesada se rechaza y no guarda nada' do
      pesar(p1, 10); j = jornada; enviar(j); confirmar(j, 10)
      post "/lotes/#{lote.id}/pesajes_manicura/registrar_directo", params: { pesos: [{ plant_id: p1.id, peso_seco_g: 10 }, { plant_id: p2.id, peso_seco_g: 9 }] },
                                                                  headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('P1 ya está pesada')
      expect(stock_total).to eq(10.0)
      expect(t { p2.reload.peso_seco }).to be_nil
    end

    it '«cargar el resto» no reparte entre las que ya están pesadas en otra jornada' do
      pesar(p1, 10); j = jornada; enviar(j); confirmar(j, 10)
      resto(20)
      expect(response).to have_http_status(:created), response.body
      expect(json['plantas_count']).to eq(2)
      confirmar(jornada, 20)
      l = t { lote.reload }
      expect([l.estado, l.rendimiento_real_g.to_f, stock_total]).to eq(['curado', 30.0, 30.0])
    end
  end

  describe 'plantas descartadas' do
    before { t { p3.update_columns(state: 'descartada') } }

    it 'una descartada no se pesa' do
      pesar(p3, 5)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('descartada')
    end

    it '«cargar el resto» no les reparte peso, y el lote cierra con las vivas' do
      resto(20, plantas_count: 3)
      expect(json['plantas_count']).to eq(2)
      confirmar(jornada, 20)
      expect(t { lote.reload.estado }).to eq('curado')
      expect(t { p3.reload.peso_seco }).to be_nil
    end

    it 'el lote dice cuántas faltan sin contarlas (lo usan las pantallas de la manicura)' do
      pesar(p1, 10)
      get "/lotes/#{lote.id}", headers: auth_headers
      expect(json['manicura']).to eq('plantas' => 2, 'pesadas' => 1, 'sin_pesar' => 1)
    end

    it 'el progreso que ve la manicura no las cuenta' do
      pesar(p1, 10)
      expect(json['progreso']).to include('pesadas' => 1, 'total' => 2, 'completado' => false)
      pesar(p2, 10)
      expect(json['progreso']).to include('pesadas' => 2, 'total' => 2, 'completado' => true)
    end
  end

  describe 'borrar una jornada sin confirmar' do
    it 'sus plantas vuelven a quedar sin pesar, se pueden pesar de nuevo y el lote cierra' do
      pesar(p1, 10); j = jornada
      delete "/lotes/#{lote.id}/pesajes_manicura/#{j.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:no_content)
      expect(t { p1.reload.peso_seco }).to be_nil
      resto(30, plantas_count: 3)
      expect(json['plantas_count']).to eq(3)
      confirmar(jornada, 30)
      l = t { lote.reload }
      expect([l.estado, l.rendimiento_real_g.to_f, stock_total]).to eq(['curado', 30.0, 30.0])
    end

    it 'una enviada que borra el admin, igual' do
      pesar(p1, 10); j = jornada; enviar(j)
      delete "/lotes/#{lote.id}/pesajes_manicura/#{j.id}", headers: auth_headers, as: :json
      expect(t { p1.reload.peso_seco }).to be_nil
      pesar(p1, 11)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'reajustar un pesaje confirmado' do
    def cerrar_lote!(g = 30)
      [p1, p2, p3].each { |p| pesar(p, g / 3.0) }
      j = jornada; enviar(j); confirmar(j, g); j
    end

    it 'después del cierre, el rendimiento del lote se corrige con el frasco' do
      j = cerrar_lote!
      expect(t { lote.reload.estado }).to eq('curado')
      patch "/lotes/#{lote.id}/pesajes_manicura/#{j.id}/reajustar_peso", params: { peso_confirmado_g: 40 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok), response.body
      expect(stock_total).to eq(40.0)
      expect(t { lote.reload.rendimiento_real_g.to_f }).to eq(40.0)
    end

    it 'mientras el lote sigue en manicura, el rendimiento no se toca (lo calcula el cierre)' do
      pesar(p1, 10); j = jornada; enviar(j); confirmar(j, 10)
      patch "/lotes/#{lote.id}/pesajes_manicura/#{j.id}/reajustar_peso", params: { peso_confirmado_g: 12 }, headers: auth_headers, as: :json
      expect(stock_total).to eq(12.0)
      expect(t { lote.reload.rendimiento_real_g }).to be_nil
    end

    # Se dispensó todo (frasco agotado, lote finalizado) y el pesaje real era más: el frasco recibe
    # la diferencia, se reabre, y el lote vuelve a curado porque ya no es cierto que no le quede nada.
    it 'un frasco vaciado que se reajusta para arriba se reabre, y su lote vuelve a curado' do
      j = cerrar_lote!
      st = t { j.reload.stock }
      t do
        st.update_columns(cantidad: 0, estado: 'agotado')
        lote.update_columns(estado: 'finalizado')
      end
      patch "/lotes/#{lote.id}/pesajes_manicura/#{j.id}/reajustar_peso", params: { peso_confirmado_g: 33 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok), response.body
      expect([st.reload.cantidad.to_f, st.estado]).to eq([3.0, 'pendiente_asignacion'])
      l = t { lote.reload }
      expect([l.estado, l.rendimiento_real_g.to_f]).to eq(['curado', 33.0])
      expect(t { l.lote_eventos.where(estado_anterior: 'finalizado', estado_nuevo: 'curado').count }).to eq(1)
    end

    it 'para abajo, no puede quedar en menos de lo que ya salió, y lo dice con números' do
      j = cerrar_lote!
      t { j.reload.stock.update_columns(cantidad: 5) } # salieron 25 de 30
      patch "/lotes/#{lote.id}/pesajes_manicura/#{j.id}/reajustar_peso", params: { peso_confirmado_g: 20 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('ya salieron 25.0 g', 'menos de 25.0 g')
    end
  end

  describe 'a qué frasco va' do
    def frasco!(forma: 'flor_seca', estado: 'asignado', cantidad: 5)
      t { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: forma, unidad: 'g', cantidad: cantidad, estado: estado) }
    end

    it 'a un frasco de flor abierto del lote, sí' do
      f = frasco!
      pesar(p1, 10); j = jornada; enviar(j); confirmar(j, 10, stock_id: f.id)
      expect(response).to have_http_status(:ok), response.body
      expect(f.reload.cantidad.to_f).to eq(15.0)
    end

    # AC (Germán, 1-oct-2026): «hoy cargo un frasco, se dispensó todo, mañana manicuro, peso y lo
    # pongo en ese frasco». El frasco vacío se vuelve a usar y deja de estar agotado.
    it 'a un frasco que se vació, sí: recibe el peso y se reabre' do
      f = frasco!
      t { f.update_columns(estado: 'agotado', cantidad: 0) }
      pesar(p1, 10); j = jornada; enviar(j); confirmar(j, 10, stock_id: f.id)
      expect(response).to have_http_status(:ok), response.body
      expect([f.reload.cantidad.to_f, f.estado]).to eq([10.0, 'asignado'])
      expect(t { Stock.where(club_id: club.id).where('cantidad > 0').where.not(estado: 'agotado').exists?(f.id) }).to be(true)
    end

    it 'al elegir frasco, la lista trae los vacíos del lote sólo si se los pide (y nunca otra forma)' do
      abierto = frasco!
      vacio = frasco!
      t { vacio.update_columns(estado: 'agotado', cantidad: 0) }
      hash = t { Stock.new(sede: sede, lote: lote, origen: 'lote', forma_producto: 'hash', unidad: 'g', cantidad: 0, estado: 'agotado').tap { |x| x.save!(validate: false) } }
      get '/stocks', params: { lote_id: lote.id }, headers: auth_headers
      expect(json.map { |x| x['id'] }).to eq([abierto.id])
      get '/stocks', params: { lote_id: lote.id, incluir_vacios: 1 }, headers: auth_headers
      expect(json.map { |x| x['id'] }).to contain_exactly(abierto.id, vacio.id)
      expect(json.map { |x| x['id'] }).not_to include(hash.id)
    end

    it 'el caso entero: jornada 1 al frasco, se dispensa todo, jornada 2 al mismo frasco' do
      pesar(p1, 10); j1 = jornada; enviar(j1); confirmar(j1, 10)
      f = t { j1.reload.stock }
      t { f.update!(sede: sede, estado: 'asignado') }
      paciente = t { create(:paciente, club: club, created_by: admin) }
      t { Dispensacion.create!(paciente: paciente, user: admin, sede: sede, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today,
                               items_attributes: [{ stock: f, cantidad: 10 }]) }
      expect(f.reload.estado).to eq('agotado')
      expect(t { lote.reload.estado }).to eq('en_manicura') # en manicura, que se vacíe no cierra el lote

      pesar(p2, 12, force_new: true); j2 = jornada; enviar(j2); confirmar(j2, 12, stock_id: f.id)
      expect(response).to have_http_status(:ok), response.body
      expect([f.reload.cantidad.to_f, f.cantidad_inicial.to_f, f.estado]).to eq([12.0, 22.0, 'asignado'])
      traza = t { Stocks::Trazabilidad.new(stock: f).call }
      expect(traza[:totales]).to include(gramos_producidos: 22.0, gramos_dispensados: 10.0, sin_explicar_g: 0.0)
    end

    it 'a un frasco que no es de flor, no' do
      f = t { Stock.new(sede: sede, lote: lote, origen: 'lote', forma_producto: 'preroll', unidad: 'un', cantidad: 5, estado: 'asignado').tap { |s| s.save!(validate: false) } }
      pesar(p1, 10); j = jornada; enviar(j); confirmar(j, 10, stock_id: f.id)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('no es de flor seca')
    end

    it 'registrar directo a un frasco que se vació, también: se reabre' do
      f = frasco!
      t { f.update_columns(estado: 'agotado', cantidad: 0) }
      post "/lotes/#{lote.id}/pesajes_manicura/registrar_directo", params: { pesos: [{ plant_id: p1.id, peso_seco_g: 10 }], stock_id: f.id },
                                                                  headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      expect([f.reload.cantidad.to_f, f.estado]).to eq([10.0, 'asignado'])
    end
  end

  describe 'sacar una planta de la jornada abierta' do
    def quitar(j, p) = delete("/lotes/#{lote.id}/pesajes_manicura/#{j.id}/plantas/#{p.id}", headers: auth_headers, as: :json)

    it 'la planta vuelve a quedar sin pesar y el resto de la jornada sigue' do
      pesar(p1, 10); pesar(p2, 12); j = jornada
      quitar(j, p2)
      expect(response).to have_http_status(:ok), response.body
      expect(json['plant_ids']).to eq([p1.id])
      expect(t { p2.reload.peso_seco }).to be_nil
      expect(t { p1.reload.peso_seco.to_f }).to eq(10.0)
      pesar(p2, 11)
      expect(response).to have_http_status(:ok)
    end

    it 'de una jornada enviada no: hay que reabrirla' do
      pesar(p1, 10); j = jornada; enviar(j)
      quitar(j, p1)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('reabrila')
    end

    it 'una planta que no está en la jornada' do
      pesar(p1, 10); j = jornada
      quitar(j, p3)
      expect(response).to have_http_status(:not_found)
    end

    it 'la jornada de otra manicura, no' do
      otra = create(:user, club: club, role: 'manicura')
      pesar(p1, 10); j = jornada
      sign_in_as(otra)
      quitar(j, p1)
      expect(response).to have_http_status(:forbidden)
      expect(t { p1.reload.peso_seco.to_f }).to eq(10.0)
    end
  end

  it 'la ficha de la planta dice en qué jornada está pesada' do
    pesar(p1, 10); j = jornada; enviar(j); confirmar(j, 10)
    get "/plants/#{p1.id}", headers: auth_headers
    expect(json['jornada_pesaje']).to include('id' => j.id, 'estado' => 'confirmado', 'mia' => true)
    get "/plants/#{p2.id}", headers: auth_headers
    expect(json['jornada_pesaje']).to be_nil
  end

  it 'aislamiento: no se confirma un pesaje de otra organización' do
    otro = create(:club, features: { 'cultivo' => true })
    ajeno = ActsAsTenant.with_tenant(otro) do
      a = create(:user, :admin, club: otro)
      s2 = create(:sede, club: otro, created_by: a)
      l2 = create(:lote, club: otro, sala: create(:sala, club: otro, sede: s2, created_by: a), estado: 'vegetativo')
      l2.update_columns(estado: 'en_manicura', sala_id: nil)
      l2.pesajes_manicura.create!(manicurador: a, club: otro, fecha_pesaje: Time.zone.today, estado: 'enviado', peso_total_g: 10)
    end
    post "/lotes/#{ajeno.lote_id}/pesajes_manicura/#{ajeno.id}/confirmar", params: { peso_confirmado_g: 10 }, headers: auth_headers, as: :json
    expect(response.status).to be_in([403, 404])
    expect(ActsAsTenant.with_tenant(otro) { ajeno.reload.estado }).to eq('enviado')
  end
end
