require 'rails_helper'

# AC: el historial del dispensador abre en LO SUYO, con salida a lo de su sede.
#
# El listado le mostraba todas las entregas de la organización, con el paciente y el monto de cada
# una. Para trabajar le alcanza con las que hizo él; puede pasar a las de su sede porque si un
# paciente vuelve y pregunta por lo que le entregó un compañero, tiene que poder contestarle sin
# llamar a nadie. Quien administra sigue viendo todo: es su trabajo.
RSpec.describe 'Historial de dispensaciones — alcance por rol', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:norte) { create(:sede, club: club, nombre: 'Norte') }
  let(:sur)   { create(:sede, club: club, nombre: 'Sur') }

  let(:ana)  { create(:user, :dispensador, club: club) }
  let(:beto) { create(:user, :dispensador, club: club) }

  let(:pac_ana)  { create(:paciente, club: club, nombre: 'Pab', apellido: 'Uno') }
  let(:pac_beto) { create(:paciente, club: club, nombre: 'Ceci', apellido: 'Dos') }

  def dispensa!(usuario:, paciente:, sede:, gramos:)
    lote  = create(:lote, club: club, sala: create(:sala, club: club, sede: sede))
    stock = create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                           cantidad: 500, costo_unitario_ars: 1, precio_sugerido_ars: 10)
    Dispensacion.create!(paciente: paciente, user: usuario, stock: stock, sede: sede,
                         cantidad: gramos, medio_pago: 'efectivo', aporte_socio_ars: gramos * 10,
                         fecha_dispensacion: Time.zone.today)
  end

  before do
    ActsAsTenant.with_tenant(club) do
      # Ana atiende en Norte; Beto, en Sur.
      dispensa!(usuario: ana,  paciente: pac_ana,  sede: norte, gramos: 10)
      dispensa!(usuario: beto, paciente: pac_beto, sede: sur,   gramos: 40)
      UserSede.create!(user: ana, sede: norte)
    end
  end

  def historial(usuario, params = {})
    sign_in_as(usuario)
    # Sin `as: :json`: en un GET, ese flag hace que los params se manden como CUERPO y la ruta se
    # resuelve como POST → 404. En un GET los filtros van como query string.
    get '/api/dispensaciones', headers: auth_headers, params: params
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)['dispensaciones']
  end

  it 'sin pedir nada, el dispensador recibe SÓLO las suyas' do
    pacientes = historial(ana).map { |d| d['paciente_nombre'] }

    expect(pacientes).to include(pac_ana.nombre_completo)
    expect(pacientes).not_to include(pac_beto.nombre_completo)
  end

  it 'con alcance=sede ve las de su mostrador, no las de la otra sede' do
    pacientes = historial(ana, alcance: 'sede').map { |d| d['paciente_nombre'] }

    expect(pacientes).to include(pac_ana.nombre_completo)
    expect(pacientes).not_to include(pac_beto.nombre_completo)
  end

  # Un dispensador SIN sedes asignadas ve todas las del club (la convención de
  # `sedes_visibles_ids`, que ya regía para el stock). Lo que no puede es ver lo de otro club.
  it 'con alcance=sede y sin sedes asignadas, ve las del club' do
    pacientes = historial(beto, alcance: 'sede').map { |d| d['paciente_nombre'] }

    expect(pacientes).to include(pac_ana.nombre_completo, pac_beto.nombre_completo)
  end

  # Por API se saltea siempre: un valor inventado no puede ser una puerta al club entero.
  it 'un alcance que no existe cae en el más restrictivo, no en el más amplio' do
    pacientes = historial(ana, alcance: 'todo').map { |d| d['paciente_nombre'] }

    expect(pacientes).not_to include(pac_beto.nombre_completo)
  end

  it 'el admin sigue viendo la organización entera' do
    pacientes = historial(admin).map { |d| d['paciente_nombre'] }

    expect(pacientes).to include(pac_ana.nombre_completo, pac_beto.nombre_completo)
  end

  it 'las dispensaciones de otra organización no aparecen nunca' do
    otro = create(:club)
    ActsAsTenant.with_tenant(otro) do
      sede_ajena = create(:sede, club: otro)
      lote  = create(:lote, club: otro, sala: create(:sala, club: otro, sede: sede_ajena))
      stock = create(:stock, club: otro, sede: sede_ajena, lote: lote, forma_producto: 'flor_seca',
                             cantidad: 100, costo_unitario_ars: 1, precio_sugerido_ars: 10)
      Dispensacion.create!(paciente: create(:paciente, club: otro, nombre: 'Aje', apellido: 'Na'),
                           user: create(:user, :admin, club: otro), stock: stock, sede: sede_ajena,
                           cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 50,
                           fecha_dispensacion: Time.zone.today)
    end

    expect(historial(admin, alcance: 'sede').map { |d| d['paciente_nombre'] }).not_to include('Aje Na')
    expect(historial(ana, alcance: 'sede').map { |d| d['paciente_nombre'] }).not_to include('Aje Na')
  end
end
