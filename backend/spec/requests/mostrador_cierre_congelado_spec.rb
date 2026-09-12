require 'rails_helper'

# CUÁNDO UN CIERRE DEJA DE PODER CORREGIRSE.
#
# Corregir un cierre mueve inventario real y asienta plata en el libro, y hasta acá no tenía
# NINGUNA frontera temporal: cualquier cierre, para siempre. Son tres candados de naturaleza
# distinta y por eso cada uno dice lo suyo — son tres arreglos distintos en tres lugares distintos.
RSpec.describe 'Un cierre que ya no se corrige', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'mixta') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  # Se contó 480 donde había 500: un faltante de 20 que se aplicó al inventario.
  let!(:turno) do
    ActsAsTenant.with_tenant(club) do
      t = abrir_mostrador!(sede, usuario: admin, recibe: ana)
      Mostradores::CerrarCaja.call(turno: t, usuario: ana, efectivo_contado_ars: 0,
                                   conteos: [{ stock_id: stock.id, contado: 480 }], notas: 'cierre')
      t.reload
    end
  end

  def item = turno.items.find_by(stock_id: stock.id)

  def corregir!(contado: 500, motivo: 'me comí un dígito', como: admin)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/turnos/#{turno.id}/corregir", headers: auth_headers,
         params: { conteos: [{ item_id: item.id, contado: contado }], motivo: motivo }
    JSON.parse(response.body)
  end

  def ficha(como = admin)
    sign_in_as(como)
    get "/api/sedes/#{sede.id}/mostrador/turnos/#{turno.id}", headers: auth_headers
    JSON.parse(response.body)
  end

  it 'mientras no pase nada, se corrige y la ficha lo dice' do
    expect(ficha['correccion']).to eq('permitida' => true)

    corregir!
    expect(response).to have_http_status(:ok)
    expect(stock.reload.cantidad.to_f).to eq(500.0)
  end

  # ① MARCADO COMO VISTO — es una FIRMA. Y por eso el candado tiene llave: sin ella un clic de
  # más sería permanente, y el gesto —que tiene que ser liviano, la lista está para vaciarse—
  # pasaría a ser una decisión pesada.
  describe 'cuando administración ya lo miró' do
    before do
      sign_in_as(admin)
      post "/api/sedes/#{sede.id}/mostrador/turnos/#{turno.id}/revisar", headers: auth_headers
    end

    it 'no se corrige, y la ficha explica por qué' do
      body = corregir!

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/ya lo miró/i)
      expect(stock.reload.cantidad.to_f).to eq(480.0)

      expect(ficha['correccion']['permitida']).to be false
      expect(ficha['correccion']['motivo']).to eq('visto')
    end

    it 'reabrirlo para revisión devuelve la llave, y vuelve a la lista de trabajo' do
      delete "/api/sedes/#{sede.id}/mostrador/turnos/#{turno.id}/revisar", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(turno.reload.revisado_at).to be_nil
      expect(turno.revisado_por).to be_nil
      expect(JSON.parse(response.body)['correccion']).to eq('permitida' => true)

      corregir!
      expect(response).to have_http_status(:ok)
      expect(stock.reload.cantidad.to_f).to eq(500.0)
    end

    it 'y queda el rastro de quién lo reabrió' do
      delete "/api/sedes/#{sede.id}/mostrador/turnos/#{turno.id}/revisar", headers: auth_headers

      aud = Auditoria.unscoped.where(auditable_type: 'TurnoMostrador', auditable_id: turno.id).last
      expect(aud.cambios.keys).to include('revisado_por_id')
      expect(aud.user_id).to eq(admin.id)
    end

    it 'quien atiende no reabre nada' do
      sign_in_as(ana)
      delete "/api/sedes/#{sede.id}/mostrador/turnos/#{turno.id}/revisar", headers: auth_headers

      expect(response).to have_http_status(:forbidden)
      expect(turno.reload.revisado_at).to be_present
    end
  end

  # ② SE ABRIÓ OTRA CAJA — no es una regla que decidimos: es que la corrección deja de ser
  # correcta. Abrir es contar, así que el producto ya se volvió a medir.
  describe 'cuando después se volvió a abrir la caja' do
    before { ActsAsTenant.with_tenant(club) { abrir_mostrador!(sede, usuario: admin, recibe: ana) } }

    it 'el cierre anterior ya no se toca' do
      body = corregir!

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/se volvió a abrir la caja/i)
      expect(stock.reload.cantidad.to_f).to eq(480.0)
    end

    it 'y la ficha lo dice, en vez de esconder el botón' do
      expect(ficha['correccion']['motivo']).to eq('caja_posterior')
      expect(ficha['correccion']['texto']).to match(/última medición|más fresca/i)
    end

    # Una caja abierta por error se ANULA, y entonces nunca hubo turno: no puede congelar el
    # cierre anterior.
    it 'una caja anulada no congela nada' do
      ActsAsTenant.with_tenant(club) { sede.mostrador!.turno_abierto.caja_turno.anular!(usuario: admin) }

      corregir!
      expect(response).to have_http_status(:ok)
      expect(stock.reload.cantidad.to_f).to eq(500.0)
    end
  end

  # ③ EL PERÍODO CONTABLE CERRADO. `CorregirCierre` asienta un movimiento de `diferencia_caja` y
  # mueve stock: sin este candado se podía corregir un cierre de un ejercicio ya presentado.
  describe 'cuando el período contable está cerrado' do
    before { club.update!(contabilidad_cerrada_hasta: Time.zone.today) }

    it 'no se corrige, y manda a reabrir el período' do
      body = corregir!

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/período contable cerrado/i)
      expect(body['error']).to match(/reabrí el período/i)
      expect(stock.reload.cantidad.to_f).to eq(480.0)
    end

    it 'la ficha lo dice con la fecha del cierre del período' do
      expect(ficha['correccion']['motivo']).to eq('periodo_cerrado')
      expect(ficha['correccion']['texto']).to include(Time.zone.today.strftime('%d/%m/%Y'))
    end

    it 'reabierto el período, se corrige' do
      club.update!(contabilidad_cerrada_hasta: nil)

      corregir!
      expect(response).to have_http_status(:ok)
      expect(stock.reload.cantidad.to_f).to eq(500.0)
    end
  end
end
