require 'rails_helper'

# El informe INASE se presenta ante el organismo: tiene que nombrar la variedad con la que el
# club acredita, y DECIR con qué nombre la cultiva puertas adentro (decisión de Germán, 12-sep-2026:
# así el informe se audita solo). Lo que queda sin vincular no es un KPI en grande: es un aviso,
# sólo cuando hay algo, y sólo sobre lo que sale en el documento.
RSpec.describe 'Informe INASE con variedades declaradas', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  let!(:inscripta) do
    ActsAsTenant.without_tenant do
      Genetica.create!(nombre: 'ANANDA001', global: true, club_id: nil,
                       registrada_inase: true, numero_registro_inase: 'INASE-12345')
    end
  end

  let!(:declarada) do
    create(:genetica, club: club, nombre: 'Northern Lights',
                      registrada_inase: false, declarada_como: inscripta)
  end

  let!(:pendiente) do
    create(:genetica, club: club, nombre: 'Critical Kush', registrada_inase: false)
  end

  let(:admin_sede) { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let(:sala)       { create(:sala, club: club, sede: admin_sede, created_by: admin) }

  def cosechado!(genetica, gramos: 100)
    l = create(:lote, club: club, sala: sala, genetica: genetica, estado: 'curado',
                      rendimiento_real_g: gramos, plants_count_cosechadas: 5)
    l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha', club: club, user: admin,
                           registrado_en: Time.zone.today.beginning_of_year + 3.days)
    l
  end

  before do
    sign_in_as(admin)
    cosechado!(declarada)
    cosechado!(pendiente)
  end

  def informe
    get '/api/informes/inase', params: { periodo: 'anio' }
    expect(response).to have_http_status(:ok), response.body
    JSON.parse(response.body)
  end

  it 'nombra la variedad declarada con la inscripta, y dice con qué nombre la cultiva' do
    fila = informe['variedades'].find { |v| v['nombre'] == 'ANANDA001' }

    expect(fila['vinculada']).to be(true)
    expect(fila['acredita']).to eq(['Northern Lights'])
  end

  it 'la que no declara nada sale con su nombre propio, marcada' do
    fila = informe['variedades'].find { |v| v['nombre'] == 'Critical Kush' }

    expect(fila['vinculada']).to be(false)
    expect(fila['acredita']).to eq([])
  end

  it 'los KPIs cuentan VARIEDADES, en la misma unidad que la tabla' do
    # El bug: contaban genéticas propias mientras la tabla agrupa por variedad, así que un club
    # con 24 genéticas declaradas contra una sola variedad leía "24 genéticas" arriba de UNA fila.
    datos = informe

    expect(datos['kpis']['variedades']).to eq(1)
    expect(datos['variedades'].count { |v| v['vinculada'] }).to eq(1)
  end

  it 'NO pide un número de registro por variedad, porque el INASE no lo asigna' do
    datos = informe

    expect(datos).not_to have_key('falta_registro')
    expect(datos['variedades'].first).not_to have_key('numero')
  end

  it 'lo no vinculado es un AVISO que nombra, no un KPI' do
    datos = informe

    expect(datos['sin_vincular'].map { |g| g['nombre'] }).to eq(['Critical Kush'])
    expect(datos['kpis']).not_to have_key('sin_acreditar')
  end

  it 'informa el obtentor de la VARIEDAD, no el de la genética propia' do
    inscripta.update!(criador: 'Anandamida Organic S.A.S.')
    declarada.update!(criador: 'El club')

    expect(informe['variedades'].find { |v| v['nombre'] == 'ANANDA001' }['criador']).to eq('Anandamida Organic S.A.S.')
  end

  it 'declarar una genética la saca del aviso y no agrega una variedad nueva' do
    expect(informe['sin_vincular'].size).to eq(1)

    pendiente.update!(declarada_como: inscripta)
    datos = informe

    expect(datos['sin_vincular']).to be_empty
    # Las dos genéticas acreditan contra la MISMA variedad: una sola fila, con las dos debajo.
    expect(datos['variedades'].size).to eq(1)
    expect(datos['variedades'].first['acredita']).to eq(['Critical Kush', 'Northern Lights'])
  end
end
