require 'rails_helper'

# EL DETALLE DE UNA DISPENSA EN EL PORTAL (27-oct-2026).
#
# AC: el paciente abre una dispensa SUYA y ve qué se llevó, cómo lo pagó y, de cada producto, la
# trazabilidad de su lote: las etapas con fecha y sala, el análisis de laboratorio, lo que recibió
# el cultivo (nutrición y aplicaciones con su carencia) y el enlace a la genética si la organización
# se la muestra. Nada de otros pacientes, ni el costo, ni quién lo atendió.
RSpec.describe 'Portal — el detalle de una dispensa', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:admin)    { create(:user, :admin, club: club, first_name: 'Dana') }
  let(:sede)     { create(:sede, club: club, created_by: admin, nombre: 'Sede Centro') }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin, nombre: 'Sala Norte') }
  let(:genetica) { create(:genetica, club: club, nombre: 'Northern Lights', visible_paciente: true) }
  let(:lote) do
    create(:lote, club: club, sala: sala, genetica: genetica, codigo: 'L-26-031', origen: 'esqueje',
                  estado: 'curado', plants_count: 24)
  end
  let(:stock) do
    Stock.create!(sede: sede, lote: lote, genetica: genetica, origen: 'lote', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 500, precio_sugerido_ars: 1000, costo_unitario_ars: 400,
                  fecha_elaboracion: 9.days.ago.to_date)
  end

  def paciente!
    create(:paciente, club: club, created_by: admin, aprobado_at: Time.current)
  end

  def dispensar!(paciente)
    d = Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede, cantidad: 5,
                             medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today, aporte_socio_ars: 5000)
    Cobro.create!(club: club, dispensacion: d, created_by: admin, medio: 'efectivo', monto_ars: 5000) if Cobro.where(dispensacion_id: d.id).none?
    d
  end

  def con_cuenta(paciente)
    user = Pacientes::Acceso.crear!(paciente).user
    user.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
    user
  end

  def historia!
    { 'enraizado' => 70, 'vegetativo' => 56, 'floracion' => 40, 'secado' => 12, 'curado' => 9 }.each do |estado, hace|
      LoteEvento.create!(lote: lote, club: club, user: admin, tipo: 'cambio_estado', estado_nuevo: estado,
                         registrado_en: hace.days.ago, sala_destino: (estado == 'floracion' ? sala : nil))
    end
    AnalisisLaboratorio.create!(lote: lote, club_id: club.id, user: admin, fecha_analisis: 11.days.ago.to_date,
                                laboratorio: 'Laboratorio Sur', thc_pct: 18.2, cbd_pct: 0.4, cbg_pct: 0.9,
                                terpenos_principales: 'mirceno, pineno')
    RegistroAmbiental.create!(lote: lote, club: club, user: admin, registrado_en: 50.days.ago,
                              fitosanitario: 'Aceite de neem', fitosanitario_motivo: 'preventivo', carencia_dias: 7)
  end

  def detalle(id) = get("/api/portal/historial/#{id}")
  def json = JSON.parse(response.body)['data']

  it 'muestra qué se llevó, cómo pagó y la trazabilidad del lote de su frasco' do
    yo = paciente!
    historia!
    dispensa = dispensar!(yo)
    sign_in_as(con_cuenta(yo))

    detalle(dispensa.id)

    expect(response).to have_http_status(:ok), response.body
    expect(json['numero']).to eq(format('%04d', dispensa.id))
    expect(json['sede']).to eq('Sede Centro')
    expect(json['pagos']).to eq([{ 'medio' => 'Efectivo', 'monto' => 5000.0 }])

    item = json['items'].first
    expect(item).to include('nombre' => 'Northern Lights', 'forma' => 'Flor seca', 'cantidad' => 5.0)
    expect(item['frasco']['numero']).to eq(stock.numero_lote_producto)

    lote_json = item['lote']
    expect(lote_json).to include('codigo' => 'L-26-031', 'origen' => 'De esqueje', 'plantas' => 24)
    etapas = lote_json['etapas'].map { |e| e['etapa'] }
    expect(etapas).to include('Vegetativo', 'Floración', 'Envasado')
    expect(etapas.last).to eq('Te lo entregaron')
    floracion = lote_json['etapas'].find { |e| e['etapa'] == 'Floración' }
    expect(floracion['detalle']).to include('Sala Norte', '28 días')

    expect(lote_json['analisis']).to include('laboratorio' => 'Laboratorio Sur', 'thc' => 18.2)
    expect(lote_json['fitosanitarios'].first).to include('producto' => 'Aceite de neem', 'carencia_dias' => 7)
  end

  it 'la genética trae su id sólo si la organización se la muestra al paciente' do
    yo = paciente!
    dispensa = dispensar!(yo)
    sign_in_as(con_cuenta(yo))

    detalle(dispensa.id)
    expect(json['items'].first['genetica']['id']).to eq(genetica.id)

    genetica.update!(visible_paciente: false)
    detalle(dispensa.id)
    expect(json['items'].first['genetica']['id']).to be_nil
    expect(json['items'].first['genetica']['nombre']).to eq('Northern Lights')
  end

  it 'no trae el costo ni quién lo atendió' do
    yo = paciente!
    dispensa = dispensar!(yo)
    sign_in_as(con_cuenta(yo))

    detalle(dispensa.id)

    expect(response.body).not_to include('costo_unitario')
    expect(response.body).not_to include('Dana')
  end

  it 'la dispensa de otro paciente no existe para él' do
    yo   = paciente!
    otro = paciente!
    ajena = dispensar!(otro)
    sign_in_as(con_cuenta(yo))

    detalle(ajena.id)

    expect(response).to have_http_status(:not_found)
  end

  it 'ni la de otra organización' do
    yo = paciente!
    sign_in_as(con_cuenta(yo))
    otra = create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
    ajena = ActsAsTenant.with_tenant(otra) do
      admin_otra = create(:user, :admin, club: otra)
      sede_otra  = create(:sede, club: otra, created_by: admin_otra)
      st = Stock.create!(sede: sede_otra, origen: 'compra_externa', proveedor: 'X', forma_producto: 'flor_seca',
                         unidad: 'g', cantidad: 50, precio_sugerido_ars: 10)
      Dispensacion.create!(paciente: create(:paciente, club: otra, created_by: admin_otra), user: admin_otra, stock: st,
                           sede: sede_otra, cantidad: 1, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today,
                           aporte_socio_ars: 10)
    end

    detalle(ajena.id)

    expect(response).to have_http_status(:not_found)
  end
end
