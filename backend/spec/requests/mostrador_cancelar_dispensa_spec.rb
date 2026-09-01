require 'rails_helper'

# Cancelar una dispensa que salió de la mesa tiene que devolverle el producto A LA MESA, no sólo
# al stock.
#
# Sin esto el gramo volvía al pozo pero el mostrador lo seguía dando por salido: el frasco
# vuelve a la mesa y a la noche el conteo da un SOBRANTE que el que atendió no puede explicar.
# Es el inverso exacto de `imputar_a_mostrador`.
RSpec.describe 'Cancelar una dispensa del mostrador', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:ana)      { create(:user, :dispensador, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'social') }
  let(:lote)     { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  let!(:turno) { abrir_mostrador!(sede, usuario: admin, recibe: ana) }

  def dispensar!(cantidad = 50)
    ActsAsTenant.with_tenant(club) do
      Dispensacion.create!(paciente: paciente, user: ana, stock: stock, sede: sede,
                           cantidad: cantidad, medio_pago: 'efectivo', aporte_socio_ars: 5_000,
                           fecha_dispensacion: Time.zone.today)
    end
  end

  def item = turno.items.first

  it 'con el turno abierto, el producto vuelve a la mesa' do
    d = dispensar!(50)
    expect(item.reload.cantidad_dispensada.to_f).to eq(50.0)
    esperado_antes = turno.items.first.esperado

    ActsAsTenant.with_tenant(club) { d.destroy }

    expect(item.reload.cantidad_dispensada.to_f).to eq(0.0)
    expect(item.esperado).to eq(esperado_antes + 50)
    expect(stock.reload.cantidad.to_f).to eq(500.0)
  end

  # Lo que importa de verdad: que el conteo de la noche siga cerrando.
  it 'y el conteo de la noche sigue cuadrando' do
    d = dispensar!(50)
    ActsAsTenant.with_tenant(club) { d.destroy }

    sign_in_as(ana)
    post "/api/sedes/#{sede.id}/mostrador/cerrar", headers: auth_headers,
         params: { conteos: [{ item_id: item.id, contado: 500 }], efectivo_contado_ars: 0 }

    expect(response).to have_http_status(:ok)
    expect(item.reload.diferencia_cierre.to_f).to eq(0.0)
  end

  # Si el turno ya cerró, su arqueo se hizo con el producto afuera: tocar ese número movería algo
  # que alguien ya firmó. El producto vuelve al depósito y la mesa de mañana se carga de cero.
  it 'con el turno ya cerrado, no se toca lo que alguien firmó' do
    d = dispensar!(50)
    ActsAsTenant.with_tenant(club) do
      Mostradores::CerrarTurno.call(turno: turno, usuario: ana, efectivo_contado_ars: 0,
                                    conteos: [{ item_id: item.id, contado: item.esperado }])
      d.destroy
    end

    expect(item.reload.cantidad_dispensada.to_f).to eq(50.0) # intacto
    expect(stock.reload.cantidad.to_f).to eq(500.0)          # pero el producto volvió al pozo
  end
end
