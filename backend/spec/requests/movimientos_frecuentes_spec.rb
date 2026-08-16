require 'rails_helper'

# AC (Germán): "que haya un checkbox para indicar si es frecuente y arriba de todo un dropdown
# con una lista de frecuentes, con un buscador… en caso de seleccionar un frecuente ya usar la
# data guardada de ese movimiento".
#
# Ya existía `recurrentes`, que los ADIVINA del historial (seis meses, agrupando por descripción
# normalizada). Adivinar sirve para proponer, no para buscar: el alquiler aparece recién después
# de dos meses cargándolo a mano, y lo que se paga cada dos meses no aparece nunca. La marca es
# explícita y sirve desde la primera vez.
RSpec.describe 'GET /movimientos_contables/frecuentes', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  def gasto(descripcion, monto:, frecuente: false, fecha: Time.zone.today, **extra)
    club.movimientos_contables.create!(
      created_by: admin, tipo: 'egreso', categoria: 'otro', sede: sede,
      descripcion: descripcion, monto_ars: monto, fecha: fecha, frecuente: frecuente, **extra
    )
  end

  def frecuentes
    get '/movimientos_contables/frecuentes', headers: auth_headers
    JSON.parse(response.body)
  end

  before { sign_in_as(admin) }

  it 'devuelve sólo los marcados' do
    gasto('Luz de julio', monto: 85_000, frecuente: true)
    gasto('Un cable', monto: 3_000)

    expect(frecuentes.map { |f| f['descripcion'] }).to eq(['Luz de julio'])
  end

  # Si la luz se cargó ocho veces interesa la última —tiene el monto más cercano a lo que va a
  # salir hoy— y no ocho renglones iguales en el buscador.
  it 'uno por descripción, el más reciente' do
    gasto('Alquiler', monto: 100_000, frecuente: true, fecha: 3.months.ago.to_date)
    gasto('Alquiler', monto: 130_000, frecuente: true, fecha: 1.month.ago.to_date)

    expect(frecuentes.size).to eq(1)
    expect(frecuentes.first['monto_ars']).to eq(130_000.0)
  end

  # Lo que se copia al elegirlo: sin esto el atajo no ahorra nada.
  it 'trae los datos que rellenan el formulario' do
    cat = club.categorias_contables.create!(nombre: 'Servicios', tipo: 'egreso')
    gasto('Luz', monto: 85_000, frecuente: true, categoria_contable: cat,
                 cantidad: 2, unidad: 'servicio', medio_pago: 'transferencia', proveedor: 'Edenor')

    f = frecuentes.first
    expect(f).to include(
      'descripcion' => 'Luz', 'monto_ars' => 85_000.0,
      'cantidad' => 2.0, 'unidad' => 'servicio',
      'medio_pago' => 'transferencia', 'proveedor' => 'Edenor',
      'categoria_label' => 'Servicios',
    )
    expect(f['categoria_contable_id']).to eq(cat.id)
  end

  it 'y no se mezcla con los de otra organización' do
    otro = create(:club)
    otro_admin = create(:user, :admin, club: otro)
    ActsAsTenant.with_tenant(otro) do
      otro.movimientos_contables.create!(created_by: otro_admin, tipo: 'egreso', categoria: 'otro',
                                         descripcion: 'Ajeno', monto_ars: 1, fecha: Time.zone.today,
                                         frecuente: true)
    end
    gasto('Propio', monto: 10, frecuente: true)

    expect(frecuentes.map { |f| f['descripcion'] }).to eq(['Propio'])
  end

  describe 'la marca' do
    it 'se guarda al crear el movimiento' do
      post '/movimientos_contables', params: { movimiento_contable: {
        tipo: 'egreso', categoria: 'otro', descripcion: 'Internet', monto_ars: 40_000,
        fecha: Time.zone.today.to_s, frecuente: true,
      } }, headers: auth_headers

      expect(response).to have_http_status(:created), response.body
      expect(JSON.parse(response.body)['frecuente']).to be(true)
    end

    it 'y por defecto no está puesta' do
      expect(gasto('Suelto', monto: 1).frecuente).to be(false)
    end
  end
end
