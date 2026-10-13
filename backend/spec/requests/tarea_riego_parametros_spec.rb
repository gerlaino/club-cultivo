require 'rails_helper'

# AC (Germán, 12-oct-2026): al crear una tarea de riego se le indica cómo regar —receta, litros,
# pH y EC—, igual que cuando se registra un riego. Viaja con la tarea (y con sus repeticiones) para
# que el registro del riego se abra con eso precargado.
RSpec.describe 'Tarea de riego con parámetros', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)   { create(:club, features: { 'cultivo' => true }) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:receta) { receta_de(club, 'Flora 1', ph_objetivo: 6.0, ec_objetivo: 1.6) }

  def receta_de(c, nombre, **extra)
    ActsAsTenant.with_tenant(c) do
      base = c.insumos.create!(nombre: "Base #{nombre}", unidad_medida: 'mililitro', tipo: 'cultivo')
      c.recetas.create!(nombre: nombre, uso: 'riego', **extra,
                        receta_items_attributes: [{ insumo_id: base.id, dosis: 2, unidad: 'ml_l' }])
    end
  end

  before { sign_in_as(admin) }

  def crear(extra = {})
    post '/tareas', params: { tarea: { titulo: 'Regar', tipo: 'riego', prioridad: 'normal',
                                       fecha_programada: Time.zone.today.to_s }.merge(extra) },
                    headers: auth_headers, as: :json
  end

  it 'guarda receta, litros, pH y EC y los devuelve' do
    crear(receta_id: receta.id, riego_litros: 20, riego_ph: 6.2, riego_ec: 1.4)

    expect(response).to have_http_status(:created), response.body
    tarea = json['tarea'] || json
    expect(tarea['riego']).to eq('receta' => { 'id' => receta.id, 'nombre' => 'Flora 1' },
                                 'litros' => 20.0, 'ph' => 6.2, 'ec' => 1.4)
  end

  it 'sin parámetros es una tarea de riego como siempre' do
    crear

    expect(response).to have_http_status(:created)
    expect((json['tarea'] || json)['riego']).to be_nil
  end

  it 'una tarea que no es de riego no guarda parámetros de riego' do
    crear(tipo: 'poda', receta_id: receta.id, riego_litros: 20)

    expect(response).to have_http_status(:created)
    t = Tarea.unscoped.find((json['tarea'] || json)['id'])
    expect([t.receta_id, t.riego_litros]).to eq([nil, nil])
  end

  it 'rechaza un pH imposible' do
    crear(riego_ph: 15)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'no acepta la receta de otra organización' do
    otro = create(:club, features: { 'cultivo' => true })
    ajena = receta_de(otro, 'Ajena')
    crear(receta_id: ajena.id)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'las repeticiones heredan cómo regar' do
    crear(receta_id: receta.id, riego_litros: 20, recurrente: true, frecuencia: 'semanal', recurrencia_veces: 3)

    expect(response).to have_http_status(:created), response.body
    hijas = Tarea.unscoped.where(parent_tarea_id: (json['tarea'] || json)['id'])
    expect(hijas.count).to eq(2)
    expect(hijas.map { |h| [h.receta_id, h.riego_litros.to_f] }.uniq).to eq([[receta.id, 20.0]])
  end
end
