require 'rails_helper'

# El historial de cierres traía "las últimas 50 de cualquier estado" y el frontend se quedaba con
# las cerradas. Dos formas de mentir, las dos en silencio:
#
#   · Con 50 aperturas ANULADAS adelante, se veían CERO cierres. La pantalla decía que nunca se
#     cerró un turno.
#   · A partir del turno 51 los viejos desaparecían, sin nada que lo dijera. Con un turno por día
#     eso son menos de dos meses.
#
# El estado se filtra en SQL y la lista se pagina diciendo cuántas hay.
RSpec.describe 'Historial de cierres de caja — paginado', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }

  def caja!(estado:, dias_atras: 0)
    ActsAsTenant.with_tenant(club) do
      CajaTurno.create!(club: club, sede: sede, punto: sede.mostrador, abierta_por: admin,
                        monto_inicial_ars: 1_000, abierta_at: dias_atras.days.ago,
                        estado: estado, efectivo_declarado_ars: (1_000 if estado == 'cerrada'),
                        cerrada_at: (dias_atras.days.ago if estado != 'abierta'))
    end
  end

  def historial(params = {})
    sign_in_as(admin)
    get "/api/sedes/#{sede.id}/caja", headers: auth_headers, params: params
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)
  end

  # El bug de fondo: el corte tiene que aplicarse DESPUÉS de filtrar por estado, no antes.
  it 'muchas anuladas no tapan los cierres' do
    60.times { caja!(estado: 'anulada', dias_atras: 1) }
    caja!(estado: 'cerrada', dias_atras: 2)

    data = historial

    expect(data['cajas'].length).to eq(1)
    expect(data['meta']['total']).to eq(1)
  end

  it 'no devuelve anuladas ni la que está abierta' do
    caja!(estado: 'cerrada', dias_atras: 3)
    caja!(estado: 'anulada', dias_atras: 2)
    caja!(estado: 'abierta')

    estados = historial['cajas'].map { |c| c['estado'] }

    expect(estados).to eq(['cerrada'])
  end

  it 'pagina, y dice cuántas hay en total' do
    25.times { |i| caja!(estado: 'cerrada', dias_atras: i + 1) }

    primera = historial(limite: 10)
    expect(primera['cajas'].length).to eq(10)
    expect(primera['meta']['total']).to eq(25)

    tercera = historial(limite: 10, pagina: 3)
    expect(tercera['cajas'].length).to eq(5)
  end

  it 'las páginas no se pisan entre sí' do
    25.times { |i| caja!(estado: 'cerrada', dias_atras: i + 1) }

    ids = (1..3).flat_map { |p| historial(limite: 10, pagina: p)['cajas'].map { |c| c['id'] } }

    expect(ids.uniq.length).to eq(25)
  end

  it 'las más nuevas primero' do
    vieja = caja!(estado: 'cerrada', dias_atras: 30)
    nueva = caja!(estado: 'cerrada', dias_atras: 1)

    ids = historial['cajas'].map { |c| c['id'] }

    expect(ids.first).to eq(nueva.id)
    expect(ids.last).to eq(vieja.id)
  end

  # Un límite pedido por API no puede volverse una consulta que traiga todo.
  it 'un límite disparatado se acota' do
    3.times { |i| caja!(estado: 'cerrada', dias_atras: i + 1) }

    expect(historial(limite: 99_999)['meta']['limite']).to eq(50)
  end

  describe 'filtro por fecha' do
    # Por fecha de APERTURA: es la que la persona recuerda. Un turno que arranca de noche y
    # cierra pasada la medianoche se busca por el día en que se abrió, no por el del cierre.
    it 'acota al rango pedido' do
      caja!(estado: 'cerrada', dias_atras: 1)
      caja!(estado: 'cerrada', dias_atras: 10)
      caja!(estado: 'cerrada', dias_atras: 40)

      data = historial(desde: 15.days.ago.to_date.to_s, hasta: Time.zone.today.to_s)

      expect(data['meta']['total']).to eq(2)
    end

    it 'incluye el día completo de los bordes' do
      caja!(estado: 'cerrada', dias_atras: 3)

      hoy = 3.days.ago.to_date.to_s
      expect(historial(desde: hoy, hasta: hoy)['meta']['total']).to eq(1)
    end

    it 'una fecha inventada no rompe la pantalla' do
      sign_in_as(admin)
      get "/api/sedes/#{sede.id}/caja", headers: auth_headers, params: { desde: 'ayer nomás' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/fecha/i)
    end
  end

  it 'no muestra los cierres de otra sede' do
    otra = create(:sede, club: club, tipo: 'social', nombre: 'Otra')
    ActsAsTenant.with_tenant(club) do
      CajaTurno.create!(club: club, sede: otra, punto: otra.mostrador, abierta_por: admin,
                        monto_inicial_ars: 1_000, abierta_at: 1.day.ago, estado: 'cerrada',
                        efectivo_declarado_ars: 1_000, cerrada_at: 1.day.ago)
    end
    caja!(estado: 'cerrada', dias_atras: 2)

    expect(historial['meta']['total']).to eq(1)
  end
end
