require 'rails_helper'

# AC (Germán): "el retiro de caja siempre tiene que estar atado a algún usuario, y siempre tiene
# que ser admin/supervisor".
#
# `created_by` no alcanza: dice quién REGISTRÓ el movimiento, y el admin puede anotar el retiro
# que hizo el supervisor. Sin distinguirlos, "$100.000 anotados a mí" queda anotado a quien tipeó
# y a fin de mes nadie sabe quién tiene esa plata.
#
# La regla vive en el MODELO, no en el controller: es una regla del dato, no de una pantalla. Por
# API se saltea siempre.
RSpec.describe 'El retiro de caja queda a nombre de alguien', type: :request do
  include AuthHelpers

  let(:club)       { create(:club) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:supervisor) { create(:user, :supervisor, club: club) }
  let(:ana)        { create(:user, :dispensador, club: club) }
  let(:sede)       { create(:sede, club: club, tipo: 'social') }

  let(:caja) do
    sign_in_as(admin)
    post "/api/sedes/#{sede.id}/caja/abrir", headers: auth_headers, params: { monto_inicial_ars: 200_000 }
    JSON.parse(response.body)
  end

  def retirar!(params = {})
    caja
    sign_in_as(admin)
    post "/api/sedes/#{sede.id}/caja/#{caja['id']}/salida", headers: auth_headers,
         params: { monto_ars: 100_000, motivo: 'para el proveedor', clase: 'retiro' }.merge(params)
    JSON.parse(response.body)
  end

  def ultimo_retiro
    ActsAsTenant.with_tenant(club) { MovimientoContable.where(club_id: club.id, categoria: 'retiro_caja').last }
  end

  it 'sin decir a quién, queda a nombre de quien lo registra' do
    retirar!

    expect(response).to have_http_status(:ok)
    expect(ultimo_retiro.retirado_por_id).to eq(admin.id)
  end

  # El caso que lo motivó: el admin anota lo que se llevó el supervisor.
  it 'se le puede atribuir a otro' do
    retirar!(retirado_por_id: supervisor.id)

    mov = ultimo_retiro
    expect(mov.retirado_por_id).to eq(supervisor.id)
    # Y sigue constando quién lo cargó: son dos datos distintos.
    expect(mov.created_by_id).to eq(admin.id)
  end

  it 'no se le puede atribuir a un dispensador' do
    cuerpo = retirar!(retirado_por_id: ana.id)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(cuerpo['error']).to match(/administrador o supervisor/i)
    expect(ultimo_retiro).to be_nil
  end

  it 'no se le puede atribuir a alguien de otra organización' do
    ajeno = create(:user, :admin, club: create(:club))

    retirar!(retirado_por_id: ajeno.id)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(ultimo_retiro).to be_nil
  end

  # La regla es del dato: un retiro sin dueño no se puede guardar ni desde la consola.
  it 'el modelo rechaza un retiro sin dueño, aunque no pase por el controller' do
    mov = ActsAsTenant.with_tenant(club) do
      MovimientoContable.new(
        club: club, sede: sede, created_by: admin, tipo: 'ajuste', categoria: 'retiro_caja',
        descripcion: 'Retiro de caja — sin dueño', monto_ars: 1_000, fecha: Time.zone.today,
        pagado: true, medio_pago: 'efectivo', comprobante_tipo: 'sin_comprobante'
      )
    end

    expect(mov).not_to be_valid
    expect(mov.errors[:retirado_por].join).to match(/obligatorio/i)
  end

  # Un GASTO no se le atribuye a nadie: lo gastó la organización.
  it 'un gasto no necesita dueño' do
    caja
    sign_in_as(admin)
    post "/api/sedes/#{sede.id}/caja/#{caja['id']}/salida", headers: auth_headers,
         params: { monto_ars: 5_000, motivo: 'flete', clase: 'gasto' }

    expect(response).to have_http_status(:ok)
    mov = ActsAsTenant.with_tenant(club) { MovimientoContable.where(categoria: 'salida_caja').last }
    expect(mov.retirado_por_id).to be_nil
  end

  describe 'a quién se le puede atribuir' do
    it 'ofrece admins y supervisores, nunca al mostrador' do
      admin; supervisor; ana
      sign_in_as(admin)
      get "/api/sedes/#{sede.id}/caja/responsables", headers: auth_headers

      roles = JSON.parse(response.body).map { |u| u['rol'] }
      expect(roles).to include('admin', 'supervisor')
      expect(roles).not_to include('dispensador')
    end
  end
end
