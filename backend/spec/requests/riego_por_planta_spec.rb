require 'rails_helper'

# AC (Germán, 30-sep-2026): «NO poner riego en el detalle de una planta, pero sí, cuando
# registrás el riego del lote, elegir qué planta del lote fue regada, como hacemos con la cosecha
# o el pesaje de la manicura; así podés registrar riego en ciertas plantas 1 pulso, en ciertas
# otras 2». Decidido: tandas (plantas + cantidad), en litros o en pulsos con «1 pulso = X L».
# - cada planta elegida queda con lo suyo; el lote recibe la suma;
# - las que no se eligieron no recibieron ese riego (tampoco lo heredan en su historial);
# - sólo plantas en pie del lote, y cada una en una sola tanda;
# - sin tandas, el riego es de todo el lote como siempre.
RSpec.describe 'Riego por planta', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'vegetativo', plants_count: 4) }
  let!(:p1)   { create(:plant, lote: lote) }
  let!(:p2)   { create(:plant, lote: lote) }
  let!(:p3)   { create(:plant, lote: lote) }
  let!(:p4)   { create(:plant, lote: lote) }

  before { sign_in_as(admin) }

  def regar(plantas, extra = {})
    post "/lotes/#{lote.id}/registros_ambientales",
         params: { registro_ambiental: { tareas_realizadas: ['riego'], plantas: plantas }.merge(extra) },
         headers: auth_headers, as: :json
  end
  def filas = ActsAsTenant.with_tenant(club) { RiegoPlanta.order(:plant_id).map { |r| [r.plant_id, r.volumen_l.to_f, r.pulsos&.to_f] } }
  def volumen_del_lote = ActsAsTenant.with_tenant(club) { lote.registros_ambientales.last.volumen_l.to_f }

  it 'unas plantas 1 pulso, otras 2: cada una con lo suyo y el lote con la suma' do
    regar([{ plant_ids: [p1.id, p2.id], pulsos: 1, litros_por_pulso: 0.25 },
           { plant_ids: [p3.id], pulsos: 2, litros_por_pulso: 0.25 }])
    expect(response).to have_http_status(:created), response.body
    expect(filas).to eq([[p1.id, 0.25, 1.0], [p2.id, 0.25, 1.0], [p3.id, 0.5, 2.0]])
    expect(volumen_del_lote).to eq(1.0)
    expect(json['plantas'].map { |x| x['texto'] }).to include('1 pulso (0,25 L)', '2 pulsos (0,5 L)')
  end

  it 'en litros también, y una sola planta alcanza' do
    regar([{ plant_ids: [p4.id], litros: 1.5 }])
    expect(response).to have_http_status(:created), response.body
    expect(filas).to eq([[p4.id, 1.5, nil]])
    expect(volumen_del_lote).to eq(1.5)
  end

  it 'sin tandas es el riego de todo el lote, como siempre' do
    post "/lotes/#{lote.id}/registros_ambientales", params: { registro_ambiental: { tareas_realizadas: ['riego'], volumen_l: 8 } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:created)
    expect(filas).to be_empty
    expect(volumen_del_lote).to eq(8.0)
  end

  it 'el volumen del lote es la suma aunque se mande otro total' do
    regar([{ plant_ids: [p1.id, p2.id], litros: 2 }], volumen_l: 20)
    expect(volumen_del_lote).to eq(4.0)
  end

  describe 'lo que no se acepta (y no deja nada guardado)' do
    def nada_guardado
      expect(response).to have_http_status(:unprocessable_entity)
      expect(ActsAsTenant.with_tenant(club) { lote.registros_ambientales.count }).to eq(0)
      expect(filas).to be_empty
    end

    it 'una planta en dos tandas' do
      regar([{ plant_ids: [p1.id], litros: 1 }, { plant_ids: [p1.id, p2.id], litros: 2 }])
      nada_guardado
    end

    it 'una planta de otro lote' do
      otro = create(:plant, lote: create(:lote, club: club, sala: sala, estado: 'vegetativo'))
      regar([{ plant_ids: [p1.id, otro.id], litros: 1 }])
      nada_guardado
    end

    it 'una planta descartada' do
      ActsAsTenant.with_tenant(club) { p2.update_columns(state: 'descartada') }
      regar([{ plant_ids: [p2.id], litros: 1 }])
      nada_guardado
    end

    it 'una planta de otra organización' do
      otro_club = create(:club)
      ajena = ActsAsTenant.with_tenant(otro_club) do
        a = create(:user, :admin, club: otro_club)
        s2 = create(:sede, club: otro_club, created_by: a)
        create(:plant, lote: create(:lote, club: otro_club, sala: create(:sala, club: otro_club, sede: s2, created_by: a), estado: 'vegetativo'))
      end
      regar([{ plant_ids: [ajena.id], litros: 1 }])
      nada_guardado
    end

    it 'pulsos sin decir cuántos litros es uno' do
      regar([{ plant_ids: [p1.id], pulsos: 2 }])
      nada_guardado
    end

    it 'una tanda sin cantidad' do
      regar([{ plant_ids: [p1.id] }])
      nada_guardado
    end
  end

  describe 'el historial' do
    before do
      regar([{ plant_ids: [p1.id, p2.id], pulsos: 1, litros_por_pulso: 0.25 }, { plant_ids: [p3.id], pulsos: 2, litros_por_pulso: 0.25 }],
            ec: 1.4, temperatura: 24)
    end

    it 'del lote dice a cuáles y cuánto' do
      get "/lotes/#{lote.id}/historial", headers: auth_headers
      det = json['historial'].find { |i| i['source'] == 'registro_ambiental' }['detalle']
      expect(det).to include('en 3 plantas: 2 con 1 pulso (0,25 L), 1 con 2 pulsos (0,5 L)')
    end

    it 'de una planta regada: su cantidad' do
      get "/plants/#{p3.id}/plant_activities", headers: auth_headers
      r = json.find { |a| a['activity_type'] == 'registro_ambiental_lote' }
      expect(r['metadata']['riego_planta']).to include('texto' => '2 pulsos (0,5 L)')
      expect(r['metadata']['tareas_realizadas']).to include('riego')
    end

    it 'de una planta NO regada: no hereda el riego ni lo del agua, sí lo del aire' do
      get "/plants/#{p4.id}/plant_activities", headers: auth_headers
      r = json.find { |a| a['activity_type'] == 'registro_ambiental_lote' }
      expect(r['metadata']['tareas_realizadas']).not_to include('riego')
      expect(r['metadata']).not_to have_key('ec')
      expect(r['metadata']).not_to have_key('riego_planta')
      expect(r['metadata']['temperatura']).to be_present
    end

    it 'si el registro era sólo el riego, a la planta no regada no le aparece' do
      regar([{ plant_ids: [p1.id], litros: 1 }])
      get "/plants/#{p4.id}/plant_activities", headers: auth_headers
      expect(json.count { |a| a['activity_type'] == 'registro_ambiental_lote' }).to eq(1)
    end
  end

  it 'la ficha del lote recuerda cuántos litros era un pulso' do
    regar([{ plant_ids: [p1.id], pulsos: 1, litros_por_pulso: 0.3 }])
    get "/lotes/#{lote.id}", headers: auth_headers
    expect(json['litros_por_pulso']).to eq(0.3)
  end
end
