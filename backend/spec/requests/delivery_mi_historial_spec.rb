require 'rails_helper'

# El rango del historial ("7 / 30 / 90 días") filtraba por `updated_at`: la última vez que se
# TOCÓ el registro, no cuándo se cerró la entrega. Con eso el filtro mentía en los dos
# sentidos — una entrega vieja que después se editó (un cobro corregido, una reprogramación)
# volvía a caer dentro de "7 días".
RSpec.describe 'Delivery — historial de lo cerrado', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:repartidor) { create(:user, :delivery, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:lote)     { create(:lote, club: club) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let(:stock)    { create(:stock, club: club, sede: sede, lote: lote, cantidad: 500) }

  def cerrada(estado:, entregado_at: nil, updated_at: Time.current)
    d = Dispensacion.create!(
      paciente: paciente, stock: stock, cantidad: 5, sede: sede,
      fecha_dispensacion: Time.zone.today, user: admin,
      con_envio: true, delivery_id: repartidor.id, estado_envio: estado,
      direccion_envio: 'Av. Siempreviva 742', contacto_nombre: paciente.nombre_completo,
      entregado_at: entregado_at,
      motivo_fallo: estado == 'fallido' ? 'Nadie en el domicilio' : nil,
    )
    # Al crear con envío, el modelo fuerza 'pendiente': el cierre se hace por los endpoints
    # de entrega. Acá se arma el estado final directo, que es lo que el historial consulta.
    d.update_columns(estado_envio: estado, entregado_at: entregado_at, updated_at: updated_at)
    d
  end

  before { sign_in_as(repartidor) }

  def historial(dias)
    get '/api/dispensaciones/mi_historial', params: { dias: dias }
    expect(response).to have_http_status(:ok), response.body
    JSON.parse(response.body)
  end

  it 'trae lo entregado y lo fallido, con su resumen' do
    cerrada(estado: 'entregado', entregado_at: 1.day.ago)
    cerrada(estado: 'fallido')

    body = historial(30)

    expect(response).to have_http_status(:ok)
    expect(body['dispensaciones'].size).to eq(2)
    expect(body['resumen']).to include('entregados' => 1, 'fallidos' => 1)
  end

  it 'una entrega de hoy aparece en el rango de 7 días' do
    cerrada(estado: 'entregado', entregado_at: Time.current)

    expect(historial(7)['dispensaciones'].size).to eq(1)
  end

  # El caso que el filtro viejo se comía: entregada hace 40 días, editada ayer.
  it 'NO trae una entrega vieja sólo porque el registro se tocó después' do
    cerrada(estado: 'entregado', entregado_at: 40.days.ago, updated_at: 1.day.ago)

    expect(historial(7)['dispensaciones']).to be_empty
    expect(historial(90)['dispensaciones'].size).to eq(1)
  end

  it 'no muestra lo que todavía no se cerró' do
    Dispensacion.create!(paciente: paciente, stock: stock, cantidad: 5, sede: sede,
                         fecha_dispensacion: Time.zone.today, user: admin,
                         con_envio: true, delivery_id: repartidor.id, estado_envio: 'en_viaje',
                         direccion_envio: 'Av. Siempreviva 742',
                         contacto_nombre: paciente.nombre_completo)

    expect(historial(30)['dispensaciones']).to be_empty
  end

  it 'no muestra las entregas de otro repartidor' do
    otro = create(:user, :delivery, club: club)
    d = cerrada(estado: 'entregado', entregado_at: 1.day.ago)
    d.update_columns(delivery_id: otro.id)

    expect(historial(30)['dispensaciones']).to be_empty
  end
end
