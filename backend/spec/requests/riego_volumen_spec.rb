require 'rails_helper'

# EL VOLUMEN DE AGUA DEL RIEGO, COMO NÚMERO (Germán, 29-sep-2026). Lo que se afirma:
# - el volumen del riego de un lote queda en el lote (`volumen_l`), se lo sume o no con nutrientes;
# - en la sala se carga el TOTAL y a cada lote le toca su parte (la suma da el total); igual en
#   la cama con lotes;
# - la nutrición del lote suma el agua y la da por planta y por semana; un riego sin volumen
#   cargado NO cuenta como 0 L;
# - el historial lo dice;
# - lo viejo se recupera del texto que la app escribía, repartiendo los riegos de sala, sin pisar
#   lo cargado y sin escribir si no se confirma.
RSpec.describe 'Volumen de agua del riego', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo', m2: 4) }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'vegetativo', plants_count: 4) }

  before { sign_in_as(admin) }

  def vol(l) = ActsAsTenant.with_tenant(club) { l.registros_ambientales.order(:id).pluck(:volumen_l).map(&:to_f) }

  it 'el riego de un lote guarda su volumen' do
    post "/lotes/#{lote.id}/registros_ambientales", params: { registro_ambiental: { volumen_l: 12.5, tareas_realizadas: ['riego'] } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:created), response.body
    expect(vol(lote)).to eq([12.5])
  end

  it 'en la sala se carga el total y a cada lote le toca su parte' do
    otros = Array.new(2) { create(:lote, club: club, sala: sala, estado: 'vegetativo') }
    lote
    post "/salas/#{sala.id}/registrar_sala", params: { registro_ambiental: { volumen_l: 30, tareas_realizadas: ['riego'] } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:created), response.body
    partes = [lote, *otros].flat_map { |l| vol(l) }
    expect(partes).to all(eq(10.0))
    expect(partes.sum).to eq(30.0)
  end

  it 'un total que no se divide exacto igual suma el total' do
    create(:lote, club: club, sala: sala, estado: 'vegetativo'); create(:lote, club: club, sala: sala, estado: 'vegetativo')
    lote
    post "/salas/#{sala.id}/registrar_sala", params: { registro_ambiental: { volumen_l: 10, tareas_realizadas: ['riego'] } }, headers: auth_headers, as: :json
    total = ActsAsTenant.with_tenant(club) { RegistroAmbiental.where(lote_id: sala.lotes.select(:id)).sum(:volumen_l) }
    expect(total.to_f).to eq(10.0)
  end

  describe '«Cargar por lote» en el riego de la sala (30-sep-2026)' do
    def regar_por_lote(volumenes, total: nil)
      post "/salas/#{sala.id}/registrar_sala",
           params: { registro_ambiental: { volumen_l: total, volumenes: volumenes, tareas_realizadas: ['riego'] }.compact },
           headers: auth_headers, as: :json
    end

    it 'cada lote queda con lo que se le cargó, no con la parte pareja' do
      otro = create(:lote, club: club, sala: sala, estado: 'vegetativo')
      lote
      regar_por_lote({ lote.id => 25, otro.id => 15 }, total: 40)
      expect(response).to have_http_status(:created), response.body
      expect(vol(lote)).to eq([25.0])
      expect(vol(otro)).to eq([15.0])
    end

    it 'un lote sin número queda «sin volumen cargado», no con 0 ni con una parte del resto' do
      otro = create(:lote, club: club, sala: sala, estado: 'vegetativo')
      lote
      regar_por_lote({ lote.id => 10, otro.id => '' })
      expect(response).to have_http_status(:created), response.body
      expect(vol(lote)).to eq([10.0])
      expect(ActsAsTenant.with_tenant(club) { otro.registros_ambientales.pluck(:volumen_l) }).to eq([nil])
    end

    it 'con un solo lote en la sala también vale' do
      regar_por_lote({ lote.id => 8 })
      expect(response).to have_http_status(:created), response.body
      expect(vol(lote)).to eq([8.0])
    end

    it 'un lote que no recibe el riego (enraizando, u otra sala) se rechaza y no se guarda nada' do
      enraizando = create(:lote, club: club, sala: sala, estado: 'enraizado')
      lote
      regar_por_lote({ lote.id => 10, enraizando.id => 5 })
      expect(response).to have_http_status(:unprocessable_entity)
      expect(ActsAsTenant.with_tenant(club) { lote.registros_ambientales.count }).to eq(0)
    end

    it 'un lote de otra organización no se puede nombrar' do
      otro_club = create(:club)
      ajeno = ActsAsTenant.with_tenant(otro_club) do
        a = create(:user, :admin, club: otro_club)
        s2 = create(:sede, club: otro_club, created_by: a)
        create(:lote, club: otro_club, sala: create(:sala, club: otro_club, sede: s2, created_by: a), estado: 'vegetativo')
      end
      lote
      regar_por_lote({ lote.id => 10, ajeno.id => 5 })
      expect(response).to have_http_status(:unprocessable_entity)
      expect(ActsAsTenant.with_tenant(otro_club) { ajeno.registros_ambientales.count }).to eq(0)
    end

    it 'la sala le dice a la pantalla qué lotes reciben su riego' do
      create(:lote, club: club, sala: sala, estado: 'enraizado', codigo: 'ENR-1')
      lote
      get "/salas/#{sala.id}", headers: auth_headers
      por_codigo = json['lotes'].to_h { |l| [l['codigo'], l['recibe_registro_sala']] }
      expect(por_codigo).to include(lote.codigo => true, 'ENR-1' => false)
    end
  end

  it 'en la cama con lotes, los litros de toda la cama se reparten' do
    post '/camas', params: { cama: { sala_id: sala.id, nombre: 'Cama A', largo_m: 2, ancho_m: 1, profundidad_cm: 30 } }, headers: auth_headers, as: :json
    cama = json
    2.times { post '/lotes', params: { lote: { cama_id: cama['id'], estado: 'vegetativo', plants_count: 2, start_date: Time.zone.today, m2_ocupados: 1 } }, headers: auth_headers, as: :json }
    post "/camas/#{cama['id']}/regar", params: { litros: 30 }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:created), response.body
    vols = ActsAsTenant.with_tenant(club) { RegistroAmbiental.where(lote_id: Lote.where(cama_id: cama['id']).select(:id)).pluck(:volumen_l).map(&:to_f) }
    expect(vols).to eq([15.0, 15.0])
  end

  it 'la nutrición del lote suma el agua; un riego sin volumen no cuenta como 0' do
    post "/lotes/#{lote.id}/registros_ambientales", params: { registro_ambiental: { volumen_l: 20, ec: 1.2, tareas_realizadas: ['riego'] } }, headers: auth_headers, as: :json
    post "/lotes/#{lote.id}/registros_ambientales", params: { registro_ambiental: { tareas_realizadas: ['riego'] } }, headers: auth_headers, as: :json
    get "/lotes/#{lote.id}/nutricion", headers: auth_headers
    t = json['totales']
    expect(t).to include('agua_l' => 20.0, 'agua_por_planta' => 5.0, 'riegos' => 2, 'riegos_con_volumen' => 1)
    expect(json['por_semana'].first).to include('agua_l' => 20.0, 'agua_por_planta' => 5.0)
  end

  it 'sin ningún volumen cargado, el agua es «sin dato», no 0' do
    post "/lotes/#{lote.id}/registros_ambientales", params: { registro_ambiental: { ec: 1.2, tareas_realizadas: ['riego'] } }, headers: auth_headers, as: :json
    get "/lotes/#{lote.id}/nutricion", headers: auth_headers
    expect(json['totales']['agua_l']).to be_nil
  end

  it 'el historial dice el agua' do
    post "/lotes/#{lote.id}/registros_ambientales", params: { registro_ambiental: { volumen_l: 20, tareas_realizadas: ['riego'] } }, headers: auth_headers, as: :json
    get "/lotes/#{lote.id}/historial", headers: auth_headers
    expect(json['historial'].find { |i| i['source'] == 'registro_ambiental' }['detalle']).to include('agua 20 L')
  end

  describe 'lo viejo, del texto (`Riegos::VolumenDesdeTexto`)' do
    def viejo(l, texto, cuando: Time.zone.parse('2026-09-01 12:00:00'), volumen: nil)
      ActsAsTenant.with_tenant(club) do
        l.registros_ambientales.create!(club: club, user: admin, registrado_en: cuando, observaciones: texto, volumen_l: volumen,
                                        created_at: cuando, tareas_realizadas: ['riego'])
      end
    end
    def correr(confirmar: true) = ActsAsTenant.without_tenant { Riegos::VolumenDesdeTexto.new(scope: RegistroAmbiental.where(club_id: club.id), confirmar: confirmar).call }

    it 'un riego de lote: el número del texto' do
      r = viejo(lote, "Riego: 18.5L\nhojas bien")
      correr
      expect(r.reload.volumen_l.to_f).to eq(18.5)
    end

    it 'un riego de sala (un registro por lote, mismo texto y momento) es el total y se reparte' do
      otro = create(:lote, club: club, sala: sala, estado: 'vegetativo')
      a = viejo(lote, 'Riego: 20L')
      b = viejo(otro, 'Riego: 20L', cuando: Time.zone.parse('2026-09-01 12:00:01'))
      res = correr
      expect([a.reload.volumen_l, b.reload.volumen_l].map(&:to_f)).to eq([10.0, 10.0])
      expect(res.compartidos).to eq(1)
    end

    it 'dos riegos del mismo lote en días distintos no se juntan' do
      a = viejo(lote, 'Riego: 20L')
      b = viejo(lote, 'Riego: 20L', cuando: Time.zone.parse('2026-09-03 12:00:00'))
      correr
      expect([a.reload.volumen_l, b.reload.volumen_l].map(&:to_f)).to eq([20.0, 20.0])
    end

    it 'el de la cama: «… L en toda la cama»' do
      r = viejo(lote, 'Riego de la Cama A: 30 L en toda la cama')
      correr
      expect(r.reload.volumen_l.to_f).to eq(30.0)
    end

    it 'no pisa un volumen cargado, ni escribe sin confirmar' do
      cargado = viejo(lote, 'Riego: 20L', volumen: 7)
      otro = viejo(lote, 'Riego: 5L', cuando: Time.zone.parse('2026-09-05 12:00'))
      res = correr(confirmar: false)
      expect(res.riegos).to eq(1)
      expect(otro.reload.volumen_l).to be_nil
      expect(cargado.reload.volumen_l.to_f).to eq(7.0)
    end
  end
end
