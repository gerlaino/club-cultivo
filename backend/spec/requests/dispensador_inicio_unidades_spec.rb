require 'rails_helper'

# AC (Germán, 12-oct-2026, revisión de las vistas por rol): el inicio del dispensador mostraba
# «Preroll 100 g» —eran 100 unidades— y sumaba los prerolls a los «gramos dispensados». Cada
# producto en su unidad, y los gramos son de flor seca, por línea (como el panel y los informes).
RSpec.describe 'Inicio del dispensador — cada producto en su unidad', type: :request do
  let(:club)     { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'mixta') }
  let(:dana)     { create(:user, :dispensador, club: club) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  let!(:flor) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, forma_producto: 'flor_seca', unidad: 'g', cantidad: 1_000,
                     estado: 'asignado', precio_sugerido_ars: 10)
    end
  end
  let!(:preroll) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, forma_producto: 'preroll', unidad: 'un', cantidad: 100,
                     estado: 'asignado', precio_sugerido_ars: 10)
    end
  end

  before do
    UserSede.create!(user: dana, sede: sede)
    ActsAsTenant.with_tenant(club) do
      # Como en el mostrador: la mesa cargada y la caja abierta por quien atiende.
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'carga',
                               cambios: [{ stock_id: flor.id, cantidad: 100 }, { stock_id: preroll.id, cantidad: 10 }])
      Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: dana, efectivo_contado_ars: 0)
      Dispensacion.create!(paciente: paciente, user: dana, sede: sede, medio_pago: 'efectivo',
                           fecha_dispensacion: Time.zone.today, aporte_socio_ars: 100,
                           items_attributes: [{ stock: flor, cantidad: 5 }, { stock: preroll, cantidad: 3 }])
    end
    sign_in_as(dana)
    get '/api/analytics/dispensador'
  end

  def json = JSON.parse(response.body)

  it 'el preroll se informa en unidades, no en gramos' do
    pre = json['stocks'].find { |s| s['forma'] == 'preroll' }
    expect(pre['unidad']).to eq('un')
    expect(json['stocks'].find { |s| s['forma'] == 'flor_seca' }['unidad']).to eq('g')
  end

  it 'los gramos dispensados son sólo de flor seca: 3 prerolls no son 3 gramos' do
    expect(json.dig('resumen', 'gramos_hoy')).to eq(5.0)
    expect(json.dig('resumen', 'dispensaciones_hoy')).to eq(1)
  end
end
