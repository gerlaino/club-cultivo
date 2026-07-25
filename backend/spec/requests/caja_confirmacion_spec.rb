require 'rails_helper'

# Caja de turno con confirmación entre roles (B5 del rediseño del Salón).
# Auth por cookie httpOnly: se re-firma con sign_in_as ANTES de cada request para alternar
# el rol dentro de un mismo flujo (la cookie manda; el Bearer no la alterna — ver auth_helpers).
RSpec.describe 'Caja de turno — confirmación entre roles', type: :request do
  let(:club)  { create(:club, features: { 'bar' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:disp)  { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:bar)   { ActsAsTenant.with_tenant(club) { club.bares.create!(sede: sede, nombre: 'La Terraza') } }

  # Alterna de rol limpio: borra el jwt_token viejo antes de re-firmar, si no la cookie previa
  # se promueve a Authorization (application_controller) y Warden autentica al usuario anterior.
  def como(user)
    reset! # sesión/cookie jar limpio, si no la cookie previa se promueve a Authorization
    sign_in_as(user)
  end

  def caja_actual = ActsAsTenant.with_tenant(club) { bar.caja_turnos.recientes.first }
  def abrir(monto = 10_000)
    post "/bares/#{bar.id}/cajas/abrir", params: { monto_inicial_ars: monto }, as: :json
  end
  def caja_post(action, id, params = {})
    post "/bares/#{bar.id}/cajas/#{id}/#{action}", params: params, as: :json
  end

  it 'flujo completo: admin abre → dispensador confirma → dispensador envía cierre → admin confirma' do
    como(admin); abrir
    expect(response).to have_http_status(:created)
    caja = caja_actual
    expect(caja.estado).to eq('abierta')

    como(disp); caja_post('confirmar_apertura', caja.id)
    expect(response).to have_http_status(:ok)
    expect(caja_actual.apertura_confirmada?).to be(true)
    expect(caja_actual.apertura_confirmada_por_id).to eq(disp.id)

    como(disp); caja_post('solicitar_cierre', caja.id, { efectivo_declarado_ars: 9_800 })
    expect(response).to have_http_status(:ok)
    expect(caja_actual.estado).to eq('pendiente_cierre')
    expect(caja_actual.cierre_solicitado_por_id).to eq(disp.id)

    como(admin); caja_post('confirmar_cierre', caja.id)
    expect(response).to have_http_status(:ok)
    final = caja_actual
    expect(final.estado).to eq('cerrada')
    expect(final.cerrada_por_id).to eq(admin.id)
    expect(final.efectivo_declarado_ars).to eq(9_800)
  end

  it 'el dispensador no puede abrir la caja (la apertura es de gestión)' do
    como(disp); abrir
    expect(response).to have_http_status(:forbidden)
  end

  it 'el dispensador no puede confirmar el cierre (lo confirma gestión)' do
    como(admin); abrir
    caja = caja_actual
    como(disp); caja_post('solicitar_cierre', caja.id, { efectivo_declarado_ars: 9_800 })
    como(disp); caja_post('confirmar_cierre', caja.id)
    expect(response).to have_http_status(:forbidden)
  end

  it 'admin/supervisor puede cerrar directo' do
    como(admin); abrir
    caja = caja_actual
    caja_post('cerrar', caja.id, { efectivo_declarado_ars: 10_000 })
    expect(response).to have_http_status(:ok)
    expect(caja_actual.estado).to eq('cerrada')
  end

  it 'no permite dos cajas activas por bar (abierta o pendiente_cierre)' do
    como(admin); abrir
    caja = caja_actual
    como(disp); caja_post('solicitar_cierre', caja.id, { efectivo_declarado_ars: 9_800 }) # pendiente_cierre
    como(admin); abrir(5_000)
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
