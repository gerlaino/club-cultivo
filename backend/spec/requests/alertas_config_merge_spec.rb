require 'rails_helper'

# `alertas_config` LA ESCRIBEN VARIAS PANTALLAS, y cada formulario manda sólo SUS claves.
#
# Reemplazando el jsonb entero, guardar en una borraba en silencio lo configurado en la otra: el
# admin no se entera hasta que el aviso que había prendido deja de llegar, que es la peor forma
# de perder una configuración — no falta un registro, cambia solo lo que la app hace.
RSpec.describe 'La configuración de alertas se mergea', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, alertas_config: { 'cierre_mostrador' => { 'activo' => true, 'hora' => '23:00' } }) }
  let(:admin) { create(:user, :admin, club: club) }

  def guardar(config)
    sign_in_as(admin)
    # `as: :json` como manda el front: form-encoded convierte todo a string y `false` llegaría
    # como "false", que es justo el tipo de diferencia que no se ve hasta producción.
    patch '/api/preferences', headers: auth_headers,
          params: { club: { alertas_config: config } }, as: :json
  end

  it 'guardar las alertas de cultivo no borra el aviso de caja sin cerrar' do
    guardar(postcosecha_dias: 3)

    expect(response).to have_http_status(:ok)
    cfg = club.reload.alertas_config
    expect(cfg['postcosecha_dias']).to eq(3)
    expect(cfg.dig('cierre_mostrador', 'hora')).to eq('23:00')
  end

  it 'y lo que sí viene, pisa lo que había' do
    guardar(cierre_mostrador: { activo: false, hora: '21:30' })

    cfg = club.reload.alertas_config
    expect(cfg.dig('cierre_mostrador', 'activo')).to be(false)
    expect(cfg.dig('cierre_mostrador', 'hora')).to eq('21:30')
  end
end
