require 'rails_helper'

# Los gastos fijos del club (alquiler, impuestos, servicios) se cargan a mano todos los meses. No
# hay tabla de "gastos fijos": se detectan del historial y se ofrecen prellenados para confirmar.
RSpec.describe 'GET /movimientos_contables/recurrentes', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  # Se pide un mes EXPLÍCITO en vez de congelar el reloj: la ventana de detección son los 6 meses
  # previos al mes pedido, así que con `mes` fijo el spec no depende de cuándo se corra.
  let(:mes)   { '2026-06' }

  def egreso(descripcion:, monto:, fecha:, categoria: 'servicios', sede_id: nil, **extra)
    club.movimientos_contables.create!(
      created_by: admin, tipo: 'egreso', categoria: categoria, descripcion: descripcion,
      monto_ars: monto, fecha: fecha, sede_id: sede_id, **extra
    )
  end

  before { sign_in_as(admin) }

  def fijos(params = {})
    get '/api/movimientos_contables/recurrentes', params: { mes: mes }.merge(params), as: :json
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)['fijos']
  end

  it 'detecta un gasto que se repitió en dos meses' do
    egreso(descripcion: 'Alquiler abril',  monto: 400_000, fecha: Date.new(2026, 4, 5))
    egreso(descripcion: 'Alquiler mayo', monto: 450_000, fecha: Date.new(2026, 5, 5))

    lista = fijos
    expect(lista.size).to eq(1)
    expect(lista.first['veces']).to eq(2)
    expect(lista.first['monto_sugerido']).to eq(450_000.0) # el último, no el promedio
    expect(lista.first['ya_cargado']).to be(false)
  end

  it 'agrupa aunque la descripción nombre el mes: "Alquiler mayo" y "Alquiler junio" son el mismo' do
    egreso(descripcion: 'Alquiler abril 2026',  monto: 400_000, fecha: Date.new(2026, 4, 5))
    egreso(descripcion: 'Alquiler mayo 2026', monto: 450_000, fecha: Date.new(2026, 5, 5))

    expect(fijos.size).to eq(1)
  end

  it 'sugiere la descripción y la fecha del mes pedido' do
    egreso(descripcion: 'Alquiler abril 2026',  monto: 400_000, fecha: Date.new(2026, 4, 5))
    egreso(descripcion: 'Alquiler mayo 2026', monto: 450_000, fecha: Date.new(2026, 5, 5))

    f = fijos.first
    expect(f['descripcion']).to eq('Alquiler junio 2026') # reescrito al mes destino
    expect(f['fecha_sugerida']).to eq('2026-06-05')       # mismo día del mes que la última vez
  end

  it 'no propone lo que aparece una sola vez' do
    egreso(descripcion: 'Compra de una escalera', monto: 90_000, fecha: Date.new(2026, 5, 10))
    expect(fijos).to be_empty
  end

  it 'marca como ya cargado el que ya existe en el mes pedido' do
    egreso(descripcion: 'Luz abril',  monto: 60_000, fecha: Date.new(2026, 4, 12))
    egreso(descripcion: 'Luz mayo', monto: 70_000, fecha: Date.new(2026, 5, 12))
    ya = egreso(descripcion: 'Luz junio', monto: 80_000, fecha: Date.new(2026, 6, 12))

    f = fijos.first
    expect(f['ya_cargado']).to be(true)
    expect(f['ya_cargado_id']).to eq(ya.id)
    expect(f['monto_sugerido']).to eq(70_000.0) # el último ANTERIOR al mes pedido
  end

  it 'ordena primero lo que falta cargar, y ahí lo más caro' do
    egreso(descripcion: 'Internet abril',  monto: 30_000, fecha: Date.new(2026, 4, 3))
    egreso(descripcion: 'Internet mayo', monto: 30_000, fecha: Date.new(2026, 5, 3))
    egreso(descripcion: 'Alquiler abril',  monto: 400_000, fecha: Date.new(2026, 4, 5))
    egreso(descripcion: 'Alquiler mayo', monto: 450_000, fecha: Date.new(2026, 5, 5))
    egreso(descripcion: 'Expensas abril',  monto: 90_000, fecha: Date.new(2026, 4, 8))
    egreso(descripcion: 'Expensas mayo', monto: 90_000, fecha: Date.new(2026, 5, 8))
    egreso(descripcion: 'Expensas junio', monto: 95_000, fecha: Date.new(2026, 6, 8)) # ya cargado

    lista = fijos
    expect(lista.map { |f| f['descripcion'] }.first(2)).to eq(['Alquiler junio', 'Internet junio'])
    expect(lista.last['ya_cargado']).to be(true)
  end

  # Mismo filtro excluye las dispensaciones y las cuotas de una compra financiada: nada de eso se
  # carga a mano, así que no es un gasto fijo.
  it 'no cuenta como gasto fijo las ventas del salón (tienen su propio automatismo)' do
    egreso(descripcion: 'Compra bar', monto: 20_000, fecha: Date.new(2026, 4, 6), categoria: 'bar')
    egreso(descripcion: 'Compra bar', monto: 20_000, fecha: Date.new(2026, 5, 6), categoria: 'bar')

    expect(fijos).to be_empty
  end

  it 'separa los gastos de sedes distintas' do
    otra = create(:sede, club: club, created_by: admin)
    egreso(descripcion: 'Alquiler abril',  monto: 400_000, fecha: Date.new(2026, 4, 5), sede_id: sede.id)
    egreso(descripcion: 'Alquiler mayo', monto: 400_000, fecha: Date.new(2026, 5, 5), sede_id: sede.id)
    egreso(descripcion: 'Alquiler abril',  monto: 200_000, fecha: Date.new(2026, 4, 5), sede_id: otra.id)
    egreso(descripcion: 'Alquiler mayo', monto: 200_000, fecha: Date.new(2026, 5, 5), sede_id: otra.id)

    expect(fijos.size).to eq(2)
    expect(fijos.map { |f| f['sede_id'] }).to contain_exactly(sede.id, otra.id)
  end

  it 'no filtra movimientos de otro club' do
    otro_club  = create(:club)
    otro_admin = create(:user, :admin, club: otro_club)
    ActsAsTenant.with_tenant(otro_club) do
      2.times do |i|
        otro_club.movimientos_contables.create!(
          created_by: otro_admin, tipo: 'egreso', categoria: 'servicios',
          descripcion: 'Alquiler ajeno', monto_ars: 1, fecha: Date.new(2026, 5 + i, 5)
        )
      end
    end

    expect(fijos).to be_empty
  end

  it 'acepta el mes por parámetro' do
    egreso(descripcion: 'Luz enero',   monto: 50_000, fecha: Date.new(2026, 1, 12))
    egreso(descripcion: 'Luz febrero', monto: 55_000, fecha: Date.new(2026, 2, 12))

    lista = fijos(mes: '2026-03')
    expect(lista.first['descripcion']).to eq('Luz marzo')
    expect(lista.first['fecha_sugerida']).to eq('2026-03-12')
  end
end
