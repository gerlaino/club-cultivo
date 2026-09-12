require 'rails_helper'

# UN PRODUCTO SUBIDO ENTERO A LA MESA TIENE QUE SEGUIR EN LA TABLA DE ADMINISTRACIÓN.
#
# La tabla con la que administración gobierna la mesa es `disponibles` (lo que se puede subir
# desde el depósito) con la mesa mergeada encima. `disponibles` filtraba por "algo libre abajo", y
# la mesa también es un apartado: un frasco de 46 g con los 46 arriba tiene disponible 0, se caía
# del filtro, y la pantalla quedaba con el KPI diciendo "46 g sobre la mesa" y la tabla diciendo
# "no hay stock habilitado". Sin fila no había desde dónde bajarlo. Pasó en producción.
RSpec.describe 'La mesa se ve entera desde administración', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'mixta') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 46, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  def cargar!(cantidad)
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'carga',
                               cambios: [{ stock_id: stock.id, cantidad: cantidad }])
    end
  end

  def mostrador_actual
    sign_in_as(admin)
    get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers
    JSON.parse(response.body)
  end

  it 'con todo el frasco arriba, la fila sigue en la lista con depósito 0' do
    cargar!(46)

    cuerpo = mostrador_actual
    fila   = cuerpo['disponibles'].find { |s| s['stock_id'] == stock.id }

    expect(cuerpo['mesa'].map { |m| m['stock_id'] }).to include(stock.id)
    expect(fila).to be_present
    expect(fila['disponible'].to_f).to eq(0.0)
    expect(fila['hay_en_deposito']).to be(false)
  end

  it 'y no se lista dos veces cuando todavía queda algo abajo' do
    cargar!(20)

    ids = mostrador_actual['disponibles'].map { |s| s['stock_id'] }

    expect(ids.count(stock.id)).to eq(1)
  end

  # El caso de antes del candado de contar: la fila del Stock en 0 con producto todavía arriba.
  # Ahí ni siquiera pasaba el scope `.disponibles`, no sólo el filtro.
  it 'aunque la fila del stock haya quedado en cero, lo que está arriba se ve' do
    cargar!(46)
    ActsAsTenant.with_tenant(club) { stock.update_column(:cantidad, 0) }

    ids = mostrador_actual['disponibles'].map { |s| s['stock_id'] }

    expect(ids).to include(stock.id)
  end
end
