require 'rails_helper'

# GET /informes/inase: el cálculo vive en `Informes::Inase` (ver su spec); acá se fija lo que es del
# endpoint —período, salidas, permisos— y que la pantalla, el PDF y el Excel lean el mismo hash.
RSpec.describe 'GET /informes/inase', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:gen_reg) { create(:genetica, club: club, nombre: 'Lemon', registrada_inase: true, criador: 'INTA') }
  let(:gen_no)  { create(:genetica, club: club, nombre: 'Casera') }

  def cosechado!(genetica, cuando:, gramos:, plantas: 10)
    l = create(:lote, club: club, sala: sala, genetica: genetica, estado: 'curado',
                      rendimiento_real_g: gramos, plants_count_cosechadas: plantas)
    l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha', club: club, user: admin, registrado_en: cuando)
    l
  end

  before { sign_in_as(admin) }

  it 'liga cada variedad con su producción del período, y el período se elige como en el resto' do
    cosechado!(gen_reg, cuando: Time.zone.today.beginning_of_year + 5.days, gramos: 500)
    cosechado!(gen_reg, cuando: 2.years.ago, gramos: 250)

    get '/informes/inase', params: { periodo: 'anio' }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)

    lemon = body['variedades'].find { |v| v['nombre'] == 'Lemon' }
    expect(lemon['vinculada']).to be(true)
    expect(lemon['criador']).to eq('INTA')
    expect(lemon['lotes']).to eq(1)
    expect(lemon['gramos']).to eq(500.0)
    expect(body['kpis']['variedades']).to eq(1)
    expect(body['kpis']['gramos']).to eq(500.0)
    expect(body['resena']).to be_present

    get '/informes/inase', params: { desde: 3.years.ago.to_date.to_s, hasta: Time.zone.today.to_s }, headers: auth_headers
    expect(JSON.parse(response.body)['kpis']['gramos']).to eq(750.0)
  end

  # Germán: "aparecen genéticas que no tengo... figuran las eliminadas". Eliminar una genética es
  # `activa: false`. Desde que el informe tiene período, lo que decide es si tuvo cosecha (o está
  # en pie): una archivada sin cultivo no aparece, y una archivada con cosecha en el período sí.
  describe 'genéticas archivadas' do
    def nombres
      get '/informes/inase', params: { periodo: 'anio' }, headers: auth_headers
      JSON.parse(response.body)['variedades'].map { |g| g['nombre'] }
    end

    it 'no declara una que se archivó sin haber llegado a cultivarse' do
      gen_no.update!(activa: false)

      expect(nombres).not_to include('Casera')
    end

    it 'sí declara una archivada que tuvo cosecha en el período' do
      cosechado!(gen_no, cuando: Time.zone.today.beginning_of_year + 5.days, gramos: 80)
      gen_no.update!(activa: false)

      expect(nombres).to include('Casera')
    end
  end

  it 'el PDF y el Excel salen del mismo hash' do
    cosechado!(gen_reg, cuando: Time.zone.today.beginning_of_year + 5.days, gramos: 500)

    get '/informes/inase.pdf', params: { periodo: 'anio' }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(response.body.byteslice(0, 4)).to eq('%PDF')

    get '/informes/inase.xlsx', params: { periodo: 'anio' }, headers: auth_headers
    expect(response).to have_http_status(:ok)
  end

  it 'requiere rol auditor o admin' do
    sign_in_as(create(:user, :cultivador, club: club))
    get '/informes/inase', headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end
end
