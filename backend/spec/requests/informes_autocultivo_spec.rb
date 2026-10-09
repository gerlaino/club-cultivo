require 'rails_helper'

# «MIS INFORMES» DEL AUTOCULTIVO (9-oct-2026, Germán). AC:
#   · Mi cosecha: planta por planta y por genética; si varias se pesaron juntas, a cada una le toca
#     su parte y se dice («repartido»).
#   · De dónde salió: cada frasco con las plantas de las que salió, su genética y el QR de cada una.
#   · Mis gastos: por mes y por tipo, y cuánto costó cada gramo (gastado ÷ seco cosechado).
#   · Se descargan en PDF y Excel. Sólo en autocultivo; cada cuenta ve lo suyo.
RSpec.describe 'Informes del autocultivo', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:carpa) { create(:sala, club: club, sede: sede, created_by: admin, kind: 'floracion', nombre: 'Carpa') }
  let(:gorilla) { create(:genetica, club: club, nombre: 'Gorilla Glue') }
  let(:kings)   { create(:genetica, club: club, nombre: 'Kings Juice', automatica: true) }
  let(:hoy) { Time.zone.today }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }
  before { sign_in_as(admin) }

  # Dos Gorilla cargadas juntas y pesadas juntas (240 g secos entre las dos) y una Kings sola (64 g).
  let!(:lote_gorilla) do
    l = create(:lote, club: club, sala: carpa, sede: sede, genetica: gorilla, estado: 'cosecha',
                      start_date: hoy - 110, rendimiento_real_g: 240, plants_count_cosechadas: 2)
    create(:plant, lote: l, nombre: 'Gorilla 1', state: 'cosechado', fecha_cosecha: hoy - 2, codigo_qr: 'QR-G1')
    create(:plant, lote: l, nombre: 'Gorilla 2', state: 'cosechado', fecha_cosecha: hoy - 2, codigo_qr: 'QR-G2')
    l
  end
  let!(:lote_kings) do
    l = create(:lote, club: club, sala: carpa, sede: sede, genetica: kings, estado: 'cosecha',
                      start_date: hoy - 80, rendimiento_real_g: 64, plants_count_cosechadas: 1)
    create(:plant, lote: l, nombre: 'La petisa', state: 'cosechado', fecha_cosecha: hoy - 1, codigo_qr: 'QR-P')
    l
  end

  def get_json(path) = (get path, params: { periodo: 'mes_actual' }, headers: auth_headers.merge('Accept' => 'application/json')) && response.parsed_body

  describe 'Mi cosecha' do
    it 'planta por planta: la que se pesó sola tiene su peso; las que se pesaron juntas, su parte y lo dice' do
      d = get_json('/informes/mi_cosecha')
      expect(response).to have_http_status(:ok), response.body
      filas = d['plantas'].index_by { |f| f['nombre'] }

      expect(filas['La petisa']).to include('seco_g' => 64.0, 'repartido' => false, 'tipo' => 'Auto')
      expect(filas['Gorilla 1']).to include('seco_g' => 120.0, 'repartido' => true, 'tipo' => 'Foto')
      expect(d).to include('total_plantas' => 3, 'seco_g' => 304.0)
    end

    it 'una cosecha del lote entero (las plantas sin fecha propia) cuenta con la fecha del lote' do
      l = create(:lote, club: club, sala: carpa, sede: sede, genetica: gorilla, estado: 'curado', start_date: hoy - 120, rendimiento_real_g: 90)
      create(:plant, lote: l, nombre: 'Gorilla 3', state: 'cosechado')
      create(:plant, lote: l, nombre: 'Gorilla 4', state: 'cosechado')
      create(:plant, lote: l, nombre: 'Gorilla 5', state: 'descartada')
      l.lote_eventos.create!(tipo: 'cambio_estado', estado_anterior: 'floracion', estado_nuevo: 'cosecha',
                             registrado_en: (hoy - 3).in_time_zone.change(hour: 12), club: club, user: admin)

      filas = get_json('/informes/mi_cosecha')['plantas'].index_by { |f| f['nombre'] }
      expect(filas['Gorilla 3']).to include('seco_g' => 45.0, 'repartido' => true, 'cosechada' => (hoy - 3).iso8601)
      expect(filas).not_to have_key('Gorilla 5')
    end

    it 'una cosecha sin plantas cargadas aparece igual, con sus gramos' do
      l = create(:lote, club: club, sala: carpa, sede: sede, genetica: kings, estado: 'curado', start_date: hoy - 90, rendimiento_real_g: 50)
      l.lote_eventos.create!(tipo: 'cambio_estado', estado_anterior: 'floracion', estado_nuevo: 'cosecha',
                             registrado_en: (hoy - 4).in_time_zone.change(hour: 12), club: club, user: admin)
      fila = get_json('/informes/mi_cosecha')['plantas'].find { |f| f['nombre'].include?('sin plantas') }
      expect(fila).to include('seco_g' => 50.0, 'genetica' => 'Kings Juice')
    end

    it 'por genética, el promedio por planta' do
      d = get_json('/informes/mi_cosecha')
      gen = d['por_genetica'].index_by { |g| g['genetica'] }
      expect(gen['Gorilla Glue']).to include('plantas' => 2, 'seco_g' => 240.0, 'por_planta_g' => 120.0)
      expect(gen['Kings Juice']).to include('plantas' => 1, 'por_planta_g' => 64.0)
    end
  end

  describe 'De dónde salió' do
    it 'el frasco nombra las plantas de las que salió, su genética y el QR de cada una' do
      create(:stock, club: club, sede: sede, lote: lote_gorilla, cantidad: 59, cantidad_inicial: 59, codigo_qr: 'F-03')
      d = get_json('/informes/de_donde_salio')
      expect(response).to have_http_status(:ok), response.body
      f = d['frascos'].first
      expect(f).to include('codigo' => 'F-03', 'gramos' => 59.0, 'genetica' => 'Gorilla Glue')
      expect(f['plantas']).to eq(['Gorilla 1', 'Gorilla 2'])
      expect(f['qr_plantas']).to eq(%w[QR-G1 QR-G2])
    end
  end

  describe 'Mis gastos' do
    it 'cada gramo = lo gastado en el período ÷ lo cosechado seco en el período' do
      create(:movimiento_contable, club: club, created_by: admin, monto_ars: 30_400, fecha: hoy, categoria: 'insumo')
      create(:movimiento_contable, club: club, created_by: admin, monto_ars: 15_200, fecha: hoy, categoria: 'electricidad', lote: lote_kings)
      create(:movimiento_contable, club: club, created_by: admin, tipo: 'ingreso', monto_ars: 99_999, fecha: hoy)

      d = get_json('/informes/mis_gastos')
      expect(response).to have_http_status(:ok), response.body
      expect(d['total']).to eq(45_600.0)
      expect(d['por_gramo']).to eq(150) # 45.600 ÷ 304 g
      cosecha = d['por_cosecha'].first
      expect(cosecha).to include('plantas' => ['La petisa'], 'gastado' => 15_200.0, 'por_gramo' => 238) # 15.200 ÷ 64 g
    end
  end

  it 'la pantalla recibe la misma definición que el PDF: números destacados y tablas' do
    d = get_json('/informes/mi_cosecha')
    expect(d.dig('vista', 'kpis').map { |k| k['label'] }).to eq(['Plantas cosechadas', 'Seco', 'Por planta'])
    expect(d.dig('vista', 'secciones', 0, 'headers')).to include('Planta', 'Seco (g)')
    expect(d.dig('vista', 'secciones', 0, 'rows').map(&:first)).to include('La petisa')
  end

  it 'los tres se descargan en PDF y en Excel' do
    %w[mi_cosecha de_donde_salio mis_gastos].each do |inf|
      get "/informes/#{inf}.pdf", params: { periodo: 'mes_actual' }, headers: auth_headers
      expect(response).to have_http_status(:ok), "#{inf}.pdf: #{response.body.first(200)}"
      expect(response.media_type).to eq('application/pdf')
      get "/informes/#{inf}.xlsx", params: { periodo: 'mes_actual' }, headers: auth_headers
      expect(response).to have_http_status(:ok), "#{inf}.xlsx"
    end
  end

  it 'una organización no los tiene' do
    org = create(:club)
    jefe = create(:user, :admin, club: org)
    ActsAsTenant.with_tenant(org) do
      sign_in_as(jefe)
      get '/informes/mi_cosecha', params: { periodo: 'mes_actual' }, headers: auth_headers.merge('Accept' => 'application/json')
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'cada cuenta ve sólo lo suyo' do
    otra = create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL)
    dueno = create(:user, :admin, club: otra)
    ActsAsTenant.with_tenant(otra) do
      sign_in_as(dueno)
      get '/informes/mi_cosecha', params: { periodo: 'mes_actual' }, headers: auth_headers.merge('Accept' => 'application/json')
      expect(response.parsed_body['total_plantas']).to eq(0)
    end
  end
end
