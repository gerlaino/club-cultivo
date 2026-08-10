require 'rails_helper'

# Entregar una reserva dejaba la dispensación marcada como pago "mixto" sin un solo cobro
# detrás. Mixto significa que se pagó de dos formas distintas — no que no se pagó.
#
# Eran dos piezas: la reserva creaba la dispensación con `medio_pago: 'mixto'` de placeholder
# "que los cobros afinan", y `afinar_medio_pago!` con CERO cobros también resolvía 'mixto'
# (porque `[].size == 1` es false). Si no había resto que cobrar, nadie corregía el placeholder.
RSpec.describe 'Entregar una reserva — el medio de pago', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:lote)        { create(:lote, club: club) }
  let(:paciente)    { create(:paciente, club: club, created_by: admin) }
  let(:stock) do
    create(:stock, club: club, sede: sede, lote: lote, cantidad: 500,
                   estado: 'asignado', precio_sugerido_ars: 100)
  end

  def crear_reserva(sena:, estimado:, medio: 'transferencia')
    Reserva.create!(
      club: club, paciente: paciente, stock: stock, cantidad: 10,
      fecha_entrega_estimada: Date.current + 1, estado: 'pendiente',
      sena_ars: sena, aporte_estimado_ars: estimado, medio_pago: medio, user: admin,
    )
  end

  before { sign_in_as(dispensador) }

  def entregar(reserva, params = {})
    patch "/api/reservas/#{reserva.id}/entregar", params: params, as: :json
  end

  # El caso que rompía: la seña cubrió todo, así que al entregar no queda nada por cobrar.
  context 'cuando la seña ya cubrió el total' do
    let(:reserva) { crear_reserva(sena: 1000, estimado: 1000, medio: 'transferencia') }

    it 'NO marca la entrega como pago mixto' do
      entregar(reserva)

      expect(response).to have_http_status(:ok), response.body
      disp = reserva.reload.dispensacion
      expect(disp).to be_present
      expect(disp.medio_pago).not_to eq('mixto')
    end

    it 'conserva el medio con el que se señó la reserva' do
      entregar(reserva)

      expect(reserva.reload.dispensacion.medio_pago).to eq('transferencia')
    end

    it 'no deja crédito colgado' do
      entregar(reserva)

      expect(reserva.reload.dispensacion.monto_credito_ars.to_f).to eq(0.0)
    end
  end

  context 'cuando se cobra el resto en un solo medio' do
    let(:reserva) { crear_reserva(sena: 200, estimado: 1000) }

    it 'toma el medio de ese cobro' do
      # `aporte_socio_ars` explícito: así el cobro cubre exactamente el total y nada cae a
      # cuenta corriente (que este paciente no tiene habilitada).
      entregar(reserva, aporte_socio_ars: 800, cobros: [{ medio: 'efectivo', monto: 800 }])

      expect(response).to have_http_status(:ok), response.body
      expect(reserva.reload.dispensacion.medio_pago).to eq('efectivo')
    end
  end

  context 'cuando el resto se paga de dos formas' do
    let(:reserva) { crear_reserva(sena: 200, estimado: 1000) }

    # Acá "mixto" sí corresponde: hubo dos cobros de medios distintos.
    it 'ahí sí queda mixto' do
      entregar(reserva, aporte_socio_ars: 800,
                        cobros: [{ medio: 'efectivo', monto: 500 },
                                 { medio: 'transferencia', monto: 300 }])

      expect(response).to have_http_status(:ok), response.body
      expect(reserva.reload.dispensacion.medio_pago).to eq('mixto')
    end
  end

  context 'contra entrega (lo cobra el delivery)' do
    let(:reserva) { crear_reserva(sena: 0, estimado: 1000, medio: 'efectivo') }

    it 'tampoco nace como mixto: todavía no se cobró nada' do
      entregar(reserva, cobrar_en_entrega: true, con_envio: true,
                        envio_calle: 'Rivadavia', envio_altura: '5066',
                        contacto_nombre: paciente.nombre_completo)

      expect(response).to have_http_status(:ok), response.body
      expect(reserva.reload.dispensacion.medio_pago).not_to eq('mixto')
    end
  end
end

# El mismo placeholder 'mixto' vivía en la creación normal de dispensaciones, no sólo en las
# reservas. En CONTRA ENTREGA no se cobra nada al crear —el delivery cobra después— así que no
# hay cobros de los que deducir el medio, y el placeholder terminaba siendo el valor final:
# toda entrega a domicilio nacía marcada "mixto".
RSpec.describe 'Contra entrega — el medio de pago', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:lote)        { create(:lote, club: club) }
  let(:paciente)    { create(:paciente, club: club, created_by: admin) }
  let(:stock) do
    create(:stock, club: club, sede: sede, lote: lote, cantidad: 500,
                   estado: 'asignado', precio_sugerido_ars: 100)
  end

  before { sign_in_as(dispensador) }

  def dispensar(extra = {})
    post "/api/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, con_envio: true,
                                   envio_calle: 'Rivadavia', envio_altura: '5066',
                                   contacto_nombre: paciente.nombre_completo }.merge(extra) },
         as: :json
  end

  it 'una entrega a cobrar en el domicilio NO nace como "mixto"' do
    dispensar(cobrar_en_entrega: true)

    expect(response).to have_http_status(:created), response.body
    expect(Dispensacion.last.medio_pago).not_to eq('mixto')
  end

  it 'respeta el medio que informó el mostrador' do
    dispensar(cobrar_en_entrega: true, medio_pago: 'transferencia')

    expect(Dispensacion.last.medio_pago).to eq('transferencia')
  end

  it 'sin medio informado, asume efectivo — que es el caso normal de una entrega' do
    dispensar(cobrar_en_entrega: true)

    expect(Dispensacion.last.medio_pago).to eq('efectivo')
  end

  it 'cobrado todo en un medio al crear, queda ese medio' do
    dispensar(cobros: [{ medio: 'transferencia', monto: 500 }])

    expect(response).to have_http_status(:created), response.body
    expect(Dispensacion.last.medio_pago).to eq('transferencia')
  end

  # "Mixto" tiene que seguir significando lo que significa.
  it 'cobrado en dos medios distintos, ahí sí es mixto' do
    dispensar(cobros: [{ medio: 'efectivo', monto: 300 },
                       { medio: 'transferencia', monto: 200 }])

    expect(response).to have_http_status(:created), response.body
    expect(Dispensacion.last.medio_pago).to eq('mixto')
  end

  it 'cuando el delivery cobra, el medio pasa a ser el que cobró de verdad' do
    dispensar(cobrar_en_entrega: true)
    d = Dispensacion.last
    d.update_columns(delivery_id: create(:user, :delivery, club: club).id, estado_envio: 'en_viaje')

    sign_in_as(admin)
    patch "/api/dispensaciones/#{d.id}/entregar",
          params: { cobros: [{ medio: 'efectivo', monto: 500 }] }, as: :json

    expect(response).to have_http_status(:ok), response.body
    expect(d.reload.medio_pago).to eq('efectivo')
  end
end
