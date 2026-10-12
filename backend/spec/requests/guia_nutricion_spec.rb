require 'rails_helper'

# AC (11-oct-2026, Germán): una guía de nutrientes general para el autocultivo, «para que la vea y
# si quiere, que la aplique, pero no mucho más»: nada de recetas por marca (no nos hacemos
# responsables de una cosecha por ofrecer un plan). Se ve con su aviso; aplicar copia los rangos de
# EC y pH a SUS alertas, sin crear tareas ni tocar recetas; compara sus registros recientes.
RSpec.describe 'Guía de nutrientes (autocultivo)', type: :request do
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL) }
  let(:admin) { create(:user, :admin, club: club) }

  before { sign_in_as(admin) }

  it 'se ve por fase, por nutriente y con el aviso; ninguna marca' do
    get '/guia_nutricion'

    expect(response).to have_http_status(:ok)
    expect(json['aviso']).to include('referencia general').and include('ajustá')
    expect(json['fases'].map { |f| f['fase'] }).to eq(%w[enraizado vegetativo floracion])
    flora = json['fases'].last
    expect(flora['predomina']).to include('Fósforo')
    # Los rangos son los de las alertas: una sola fuente.
    expect(flora['ec']).to eq('min' => 1.4, 'max' => 2.2)
    expect(json['fuentes']).not_to be_empty
    expect(json['aplicada']).to be(false)
  end

  it 'aplicar copia los rangos a sus alertas, sin crear tareas, y queda marcada' do
    expect {
      post '/guia_nutricion/aplicar'
    }.not_to change { ActsAsTenant.with_tenant(club) { Tarea.count } }

    expect(response).to have_http_status(:ok)
    expect(json['aplicada']).to be(true)
    ActsAsTenant.with_tenant(club) do
      sp = SetpointFase.find_by(club_id: club.id, fase: 'vegetativo', tipo_lectura: 'ec', genetica_id: nil)
      expect([sp.valor_min.to_f, sp.valor_max.to_f]).to eq([0.8, 1.4])
    end
  end

  it 'aplicar respeta los rangos que la persona cargó para UNA genética' do
    ActsAsTenant.with_tenant(club) do
      gen = create(:genetica, club: club)
      SetpointFase.create!(club_id: club.id, fase: 'floracion', tipo_lectura: 'ec', genetica_id: gen.id, valor_min: 1.0, valor_max: 1.6)
    end

    post '/guia_nutricion/aplicar'

    ActsAsTenant.with_tenant(club) do
      propio = SetpointFase.where(club_id: club.id, fase: 'floracion', tipo_lectura: 'ec').where.not(genetica_id: nil).first
      expect([propio.valor_min.to_f, propio.valor_max.to_f]).to eq([1.0, 1.6])
    end
  end

  it 'compara los registros de las últimas dos semanas contra el rango de la fase' do
    ActsAsTenant.with_tenant(club) do
      sala = create(:sala, club: club)
      lote = create(:lote, club: club, sala: sala, estado: 'vegetativo')
      create(:registro_ambiental, lote: lote, club: club, ec: 1.0, ph: 6.0, registrado_en: 2.days.ago)
      create(:registro_ambiental, lote: lote, club: club, ec: 2.5, ph: 7.2, registrado_en: 3.days.ago)
      create(:registro_ambiental, lote: lote, club: club, ec: 2.5, ph: 7.2, registrado_en: 30.days.ago)
    end

    get '/guia_nutricion'

    vege = json['fases'].find { |f| f['fase'] == 'vegetativo' }
    expect(vege['comparacion']['ec']).to eq('registros' => 2, 'fuera' => 1)
    expect(vege['comparacion']['ph']).to eq('registros' => 2, 'fuera' => 1)
  end

  it 'una organización no la tiene' do
    org = create(:club, plan: 'basico', features: { 'cultivo' => true })
    sign_in_as(create(:user, :admin, club: org))

    get '/guia_nutricion'
    expect(response).to have_http_status(:not_found)
  end

  it 'aislamiento: aplicar no toca las alertas de otra cuenta' do
    otro = create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL)

    post '/guia_nutricion/aplicar'

    expect(ActsAsTenant.without_tenant { SetpointFase.where(club_id: otro.id).count }).to eq(0)
  end
end
