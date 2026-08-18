require 'rails_helper'

# El informe INASE se presenta ante el organismo: tiene que nombrar la variedad con la que el
# club acredita, no el nombre de fantasía con el que la cultiva. Y tiene que dejar en claro
# qué queda sin acreditar, que es lo único accionable del informe.
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

  before { sign_in_as(admin) }

  def informe
    get '/api/informes/inase'
    expect(response).to have_http_status(:ok), response.body
    JSON.parse(response.body)
  end

  it 'nombra la variedad declarada con la inscripta, y guarda el nombre real aparte' do
    fila = informe['geneticas'].find { |g| g['nombre_propio'] == 'Northern Lights' }

    expect(fila['nombre']).to eq('ANANDA001')
    expect(fila['numero_registro_inase']).to eq('INASE-12345')
    expect(fila['declarada']).to be(true)
    expect(fila['acreditada']).to be(true)
  end

  it 'la que no declara nada sigue con su nombre y queda sin acreditar' do
    fila = informe['geneticas'].find { |g| g['nombre_propio'] == 'Critical Kush' }

    expect(fila['nombre']).to eq('Critical Kush')
    expect(fila['numero_registro_inase']).to be_nil
    expect(fila['acreditada']).to be(false)
  end

  it 'los KPIs cuentan VARIEDADES, en la misma unidad que la tabla' do
    # El bug: contaban genéticas propias mientras la tabla agrupa por variedad, así que un club
    # con 24 genéticas declaradas contra una sola variedad leía "24 genéticas" arriba de UNA fila.
    datos = informe

    # Una sola variedad acreditable (ANANDA001), aunque haya dos genéticas propias cargadas.
    expect(datos['total_variedades']).to eq(1)
    expect(datos['agrupadas'].size).to eq(datos['total_variedades'])
    expect(datos['agrupadas'].map { |v| v['nombre'] }).to eq(['ANANDA001'])
  end

  it 'NO pide un número de registro por variedad, porque el INASE no lo asigna' do
    # Lo que identifica a cada variedad es su NOMBRE en el Catálogo Nacional de Cultivares; lo
    # que consta aparte es la resolución que la inscribió. El informe llegó a mostrar una columna
    # "N° registro" que quedaba en blanco para siempre: un pendiente imposible de cerrar, que es
    # lo que entrena a la gente a ignorar los avisos.
    datos = informe

    expect(datos).not_to have_key('falta_registro')
    expect(datos['agrupadas'].first).not_to have_key('numero')
  end

  it 'lo no acreditado se cuenta en genéticas propias y va aparte' do
    # Es la excepción de unidad, a propósito: justamente NO son una variedad todavía.
    datos = informe

    expect(datos['sin_acreditar']).to eq(1)
    expect(datos['pendientes'].map { |g| g['nombre_propio'] }).to eq(['Critical Kush'])
  end

  it 'una genética sin acreditar NO se cuela en la tabla haciéndose pasar por variedad' do
    # Entraba: al agrupar por `nombre_declarado`, la no declarada caía en su propio nombre y
    # aparecía como una variedad del INASE que no existe.
    expect(informe['agrupadas'].map { |v| v['nombre'] }).not_to include('Critical Kush')
  end

  it 'informa el obtentor de la VARIEDAD, no el de la genética propia' do
    # Si el club cultiva "Northern Lights" y lo declara como ANANDA001, ante el INASE el obtentor
    # es el de ANANDA001 — no el que le puso el nombre de fantasía puertas adentro.
    inscripta.update!(criador: 'Anandamida Organic S.A.S.')
    declarada.update!(criador: 'El club')

    expect(informe['agrupadas'].first['criador']).to eq('Anandamida Organic S.A.S.')
  end

  it 'el informe NO expone con qué nombre cultiva la organización' do
    # Esto se presenta ante el INASE: cómo llama a sus genéticas puertas adentro es asunto suyo.
    # El par se audita en la pantalla de Genéticas.
    variedad = informe['agrupadas'].first

    expect(variedad).not_to have_key('propios')
    expect(variedad.to_s).not_to include('Northern Lights')
  end

  it 'declarar una genética la saca de los pendientes y no agrega una variedad nueva' do
    expect(informe['sin_acreditar']).to eq(1)

    pendiente.update!(declarada_como: inscripta)
    datos = informe

    expect(datos['sin_acreditar']).to eq(0)
    expect(datos['pendientes']).to be_empty
    # Las dos genéticas acreditan contra la MISMA variedad: sigue habiendo una sola fila.
    expect(datos['total_variedades']).to eq(1)
  end
end
