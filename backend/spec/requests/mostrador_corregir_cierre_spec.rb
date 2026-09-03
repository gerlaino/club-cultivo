require 'rails_helper'

# Arreglar un conteo mal cargado en un turno que ya cerró.
#
# Era el único lugar del módulo donde un dedazo destruía datos: escribir 21 en vez de 215 cierra
# con un faltante de 194 g y AJUSTA EL INVENTARIO REAL. La caja se puede anular; esto no tenía
# vuelta atrás.
#
# No se borra nada: se asienta la diferencia entre lo que se había contado y lo que se cuenta
# ahora. Borrar un movimiento de stock para tapar un error es peor que el error — el rastro de
# que alguien corrigió es justamente lo que hay que poder mostrar.
RSpec.describe 'Corregir el conteo de un turno cerrado', type: :request do
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

  # Se carga 300, se dispensan 85, y el dedazo: cuenta 21 en vez de 215.
  let!(:turno) do
    ActsAsTenant.with_tenant(club) do
      t = abrir_mostrador!(sede, usuario: admin, recibe: ana)
      Dispensacion.create!(paciente: paciente, user: ana, stock: stock, sede: sede, cantidad: 85,
                           medio_pago: 'efectivo', aporte_socio_ars: 8_500,
                           fecha_dispensacion: Time.zone.today)
      Mostradores::CerrarCaja.call(turno: t, usuario: ana, efectivo_contado_ars: 8_500,
                                   conteos: [{ stock_id: stock.id, contado: 21 }], notas: 'conté mal')
      t.reload
    end
  end

  def item = turno.items.find_by(stock_id: stock.id)

  def corregir!(contado:, motivo: 'me comí un dígito', como: admin)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/turnos/#{turno.id}/corregir", headers: auth_headers,
         params: { conteos: [{ item_id: item.id, contado: contado }], motivo: motivo }
    JSON.parse(response.body)
  end

  it 'el dedazo dejó el inventario mal' do
    # 500 − 85 dispensados − 394 de "faltante" inventado
    expect(stock.reload.cantidad.to_f).to eq(21.0)
  end

  it 'corregirlo devuelve el inventario a donde tenía que estar' do
    corregir!(contado: 415)

    expect(response).to have_http_status(:ok)
    expect(stock.reload.cantidad.to_f).to eq(415.0)
    expect(item.reload.cantidad_cierre.to_f).to eq(415.0)
  end

  # El ajuste viejo NO se borra: queda, y se asienta la diferencia. Borrar para tapar un error es
  # peor que el error.
  it 'no borra el movimiento equivocado: asienta la corrección al lado' do
    corregir!(contado: 415)

    ajustes = stock.stock_movimientos.where(tipo: 'ajuste').order(:id)
    expect(ajustes.count).to eq(2)
    expect(ajustes.first.gramos.to_f).to eq(-394.0)  # el faltante inventado por el dedazo
    expect(ajustes.last.gramos.to_f).to eq(394.0)    # la corrección, que lo compensa
    expect(ajustes.last.notas).to match(/Corrección del conteo del turno/)
    expect(ajustes.last.usuario_id).to eq(admin.id)
  end

  it 'el motivo queda pegado al del cierre, no lo pisa' do
    corregir!(contado: 415, motivo: 'me comí un dígito')

    expect(item.reload.motivo_diferencia).to eq('conté mal · corregido: me comí un dígito')
  end

  it 'sin motivo no corrige' do
    body = corregir!(contado: 415, motivo: '')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(body['error']).to match(/por qué se corrige/i)
    expect(stock.reload.cantidad.to_f).to eq(21.0)
  end

  it 'corregir al mismo número no hace nada' do
    expect { corregir!(contado: 21) }
      .not_to change { stock.stock_movimientos.where(tipo: 'ajuste').count }
  end

  # Toca inventario de un turno cerrado: no es del mostrador.
  it 'el dispensador no corrige un cierre' do
    corregir!(contado: 415, como: ana)

    expect(response).to have_http_status(:forbidden)
    expect(stock.reload.cantidad.to_f).to eq(21.0)
  end

  it 'queda en el audit log quién corrigió el conteo' do
    corregir!(contado: 415)

    aud = Auditoria.unscoped.where(auditable_type: 'TurnoMostradorItem', auditable_id: item.id).last
    expect(aud).to be_present
    expect(aud.cambios.keys).to include('cantidad_cierre')
  end
end
