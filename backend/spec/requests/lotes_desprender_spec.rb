require 'rails_helper'

# Desprender parte de un lote: de 20 que prendieron, 10 a maceta de 3 L y 10 a 5 L. Desde ahí no son
# el mismo grupo —riego, frecuencia y trasplante distintos— y un lote tiene UNA maceta, así que el
# dato le mentiría a la mitad de las plantas.
RSpec.describe 'POST /lotes/:id/desprender', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }
  let(:lote)  do
    create(:lote, club: club, sala: sala, estado: 'vegetativo', codigo: 'L-26-043',
                  tamanio_maceta: 3, start_date: 30.days.ago.to_date)
  end

  before do
    sign_in_as(admin)
    20.times { |i| create(:plant, lote: lote, club: club, state: 'vegetativo', nombre: "P#{i}") }
    lote.update_column(:plants_count, 20)
  end

  it 'separa las plantas a un lote nuevo con su propia maceta' do
    post "/api/lotes/#{lote.id}/desprender", params: { cantidad: 10, tamanio_maceta: 5 }

    expect(response).to have_http_status(:created)
    nuevo = Lote.find(JSON.parse(response.body)['lote_nuevo']['id'])

    expect(nuevo.plants.count).to eq(10)
    expect(lote.reload.plants.count).to eq(10)
    expect(nuevo.tamanio_maceta.to_f).to eq(5.0)
    expect(lote.tamanio_maceta.to_f).to eq(3.0)   # el original conserva la suya
    expect(nuevo.plants_count).to eq(10)
    expect(lote.plants_count).to eq(10)
  end

  # El sufijo muestra el parentesco sin tener que leer un campo.
  it 'le da un código derivado del original y lo deja apuntando al padre' do
    post "/api/lotes/#{lote.id}/desprender", params: { cantidad: 10, tamanio_maceta: 5 }
    nuevo = Lote.find(JSON.parse(response.body)['lote_nuevo']['id'])

    expect(nuevo.codigo).to eq('L-26-043-B')
    expect(nuevo.lote_origen_id).to eq(lote.id)
    expect(nuevo.split_at).to be_present
  end

  # Enraizaron juntas: si el hijo arrancara hoy, sus días de ciclo y de enraizado saldrían mal.
  it 'el hijo hereda la fecha de inicio y la genética, no arranca de cero' do
    genetica = create(:genetica, club: club)
    lote.update!(genetica: genetica, origen: 'esqueje')

    post "/api/lotes/#{lote.id}/desprender", params: { cantidad: 5 }
    nuevo = Lote.find(JSON.parse(response.body)['lote_nuevo']['id'])

    expect(nuevo.start_date).to eq(lote.start_date)
    expect(nuevo.genetica_id).to eq(genetica.id)
    expect(nuevo.origen).to eq('esqueje')
    expect(nuevo.estado).to eq('vegetativo')
    expect(nuevo.sala_id).to eq(sala.id)
  end

  # La historia hasta el desprendimiento es compartida: las que se van vivieron las mismas fases el
  # mismo día. Sin los eventos, el hijo se queda sin la fecha en que entró a vegetativo y su ciclo
  # se cuenta desde el esqueje — marcaría 30 días donde el padre marca 12.
  it 'el hijo hereda la línea de tiempo, y sus relojes coinciden con los del padre' do
    lote.lote_eventos.create!(tipo: 'cambio_estado', estado_anterior: 'enraizado',
                              estado_nuevo: 'vegetativo', registrado_en: 12.days.ago,
                              club: club, user: admin)

    post "/api/lotes/#{lote.id}/desprender", params: { cantidad: 5, tamanio_maceta: 5 }
    hijo = Lote.find(JSON.parse(response.body)['lote_nuevo']['id'])

    expect(hijo.dias_ciclo).to eq(lote.reload.dias_ciclo)
    expect(hijo.dias_enraizado).to eq(lote.dias_enraizado)
    expect(hijo.fecha_inicio_vegetativo).to eq(lote.fecha_inicio_vegetativo)
  end

  # Con QR por planta, elegir CUÁLES importa: si el sistema las elige solo, las etiquetas físicas
  # dejan de coincidir con los datos.
  it 'permite elegir exactamente qué plantas se van' do
    elegidas = lote.plants.order(:id).limit(3).to_a

    post "/api/lotes/#{lote.id}/desprender", params: { plant_ids: elegidas.map(&:id), tamanio_maceta: 5 }

    expect(response).to have_http_status(:created)
    nuevo = Lote.find(JSON.parse(response.body)['lote_nuevo']['id'])
    expect(nuevo.plants.order(:id).pluck(:id)).to eq(elegidas.map(&:id))
  end

  it 'no deja vaciar el lote entero' do
    post "/api/lotes/#{lote.id}/desprender", params: { cantidad: 20 }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to match(/quedaría vacío/i)
    expect(lote.reload.plants.count).to eq(20)
  end

  it 'no separa más plantas de las que hay' do
    post "/api/lotes/#{lote.id}/desprender", params: { cantidad: 50 }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  # ── La plata ──────────────────────────────────────────────────────────────
  # El gasto queda ENTERO y con su lote original en el libro (un gasto real de $10.000 no son dos de
  # $5.000: no hay dos facturas). El reparto de lo común vive en el COSTEO.
  describe 'el costo acumulado' do
    before do
      create(:movimiento_contable, club: club, lote: lote, tipo: 'egreso',
                                   categoria: 'insumo', monto_ars: 10_000, fecha: 10.days.ago)
      CostoDesdeLibroService.new(lote: lote.reload).call
    end

    it 'se reparte por cabeza entre el que queda y el que se va' do
      expect(lote.reload.costo_lote.costo_total.to_f).to eq(10_000.0)

      post "/api/lotes/#{lote.id}/desprender", params: { cantidad: 10, tamanio_maceta: 5 }
      nuevo = Lote.find(JSON.parse(response.body)['lote_nuevo']['id'])

      # 10 de 20 plantas se van con la mitad del costo acumulado.
      expect(nuevo.costo_heredado_ars.to_f).to eq(5_000.0)
      expect(nuevo.costo_lote.costo_total.to_f).to eq(5_000.0)
      # Y el padre deja de cargar plantas que ya no tiene: sin esto su costo/gramo saldría inflado.
      expect(lote.reload.costo_cedido_ars.to_f).to eq(5_000.0)
      expect(lote.costo_lote.reload.costo_total.to_f).to eq(5_000.0)
    end

    # El libro es la fuente de verdad y `CostoLote` se deriva de él: si el reparto no sobreviviera
    # al próximo recálculo, volvería a quedar todo en el padre.
    it 'sobrevive a un recálculo desde el libro' do
      post "/api/lotes/#{lote.id}/desprender", params: { cantidad: 10, tamanio_maceta: 5 }
      nuevo = Lote.find(JSON.parse(response.body)['lote_nuevo']['id'])

      CostoDesdeLibroService.new(lote: lote.reload).call
      CostoDesdeLibroService.new(lote: nuevo.reload).call

      expect(lote.costo_lote.reload.costo_total.to_f).to eq(5_000.0)
      expect(nuevo.costo_lote.reload.costo_total.to_f).to eq(5_000.0)
    end

    # Lo que se llevó es lo que se llevó el día que se separó: un gasto posterior es solo del lote
    # al que se le imputa, no se reparte hacia atrás.
    it 'un gasto posterior al desprendimiento no se reparte' do
      post "/api/lotes/#{lote.id}/desprender", params: { cantidad: 10, tamanio_maceta: 5 }
      nuevo = Lote.find(JSON.parse(response.body)['lote_nuevo']['id'])

      create(:movimiento_contable, club: club, lote: nuevo, tipo: 'egreso',
                                   categoria: 'insumo', monto_ars: 2_000, fecha: Date.current)
      CostoDesdeLibroService.new(lote: nuevo.reload).call

      expect(nuevo.costo_lote.reload.costo_total.to_f).to eq(7_000.0)  # 5.000 heredados + 2.000 propios
      expect(lote.reload.costo_lote.costo_total.to_f).to eq(5_000.0)   # el padre no se entera
    end
  end
end
