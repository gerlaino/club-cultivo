require 'rails_helper'

# AC (Germán): "una solapa al lado de categorías donde podamos crear gastos recurrentes… al crear
# nuevo movimiento, arriba de todo, un dropdown con el listado, lo marcás y se presetea toda la
# data… si bien la luz es algo fijo mensual, no todos los meses viene lo mismo, entonces el monto
# debería ser editable".
#
# El molde es una ENTIDAD con pantalla propia, no una marca sobre un movimiento ya cargado
# (`movimientos_contables.frecuente`, que duró unas horas y se sacó): marcando el movimiento no se
# puede dar de alta "Luz" antes de la primera factura ni corregir el monto de referencia sin
# cargar un gasto de verdad.
RSpec.describe 'Gastos recurrentes', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  def crear(attrs = {})
    post '/gastos_recurrentes',
         params: { gasto_recurrente: { nombre: 'Luz', monto_ars: 85_000 }.merge(attrs) },
         headers: auth_headers
    JSON.parse(response.body)
  end

  describe 'el admin' do
    before { sign_in_as(admin) }

    it 'da de alta uno antes de haber pagado nunca' do
      datos = crear

      expect(response).to have_http_status(:created), response.body
      expect(datos['nombre']).to eq('Luz')
      expect(datos['monto_ars']).to eq(85_000.0)
    end

    it 'con todo lo que después rellena el formulario' do
      cat = club.categorias_contables.create!(nombre: 'Servicios', tipo: 'egreso')

      datos = crear(categoria_contable_id: cat.id, sede_id: sede.id, cantidad: 1,
                    unidad: 'servicio', medio_pago: 'transferencia', proveedor: 'Edenor',
                    descripcion: 'Factura de luz')

      expect(datos).to include(
        'categoria_label' => 'Servicios', 'sede_nombre' => sede.nombre,
        'unidad' => 'servicio', 'medio_pago' => 'transferencia', 'proveedor' => 'Edenor',
        'descripcion' => 'Factura de luz',
      )
    end

    # El monto es una REFERENCIA y por eso se puede corregir sin cargar ningún gasto: la luz es
    # fija todos los meses salvo en el monto, que es justamente lo que cambia.
    it 'y le corrige el monto cuando cambia' do
      id = crear['id']

      put "/gastos_recurrentes/#{id}",
          params: { gasto_recurrente: { monto_ars: 91_500 } }, headers: auth_headers

      expect(JSON.parse(response.body)['monto_ars']).to eq(91_500.0)
    end

    it 'el sector lo hereda de la categoría, no se elige aparte' do
      unidad = club.unidades_negocio.create!(nombre: 'General', tipo: 'administracion')
      cat    = club.categorias_contables.create!(nombre: 'Servicios', tipo: 'egreso', unidad_negocio: unidad)

      expect(crear(categoria_contable_id: cat.id)['unidad_negocio_id']).to eq(unidad.id)
    end

    # Dos "Luz" en el buscador no se distinguen.
    it 'no deja repetir el nombre' do
      crear
      crear

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].join).to match(/ya existe/i)
    end

    it 'lo borra sin tocar los movimientos que ya se cargaron con él' do
      id  = crear['id']
      mov = club.movimientos_contables.create!(created_by: admin, tipo: 'egreso', categoria: 'otro',
                                               descripcion: 'Luz de julio', monto_ars: 85_000,
                                               fecha: Time.zone.today)

      delete "/gastos_recurrentes/#{id}", headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(mov.reload).to be_present
    end
  end

  describe 'el listado' do
    before { sign_in_as(admin) }

    it 'puede pedirse sólo con los activos' do
      crear
      crear(nombre: 'Alquiler', activo: false)

      get '/gastos_recurrentes', params: { activos: 'true' }, headers: auth_headers

      expect(JSON.parse(response.body).map { |g| g['nombre'] }).to eq(['Luz'])
    end

    it 'y no se mezcla con el de otra organización' do
      crear
      otro = create(:club)
      otro_admin = create(:user, :admin, club: otro)
      ActsAsTenant.with_tenant(otro) { otro.gastos_recurrentes.create!(nombre: 'Ajeno', created_by: otro_admin) }

      get '/gastos_recurrentes', headers: auth_headers

      expect(JSON.parse(response.body).map { |g| g['nombre'] }).to eq(['Luz'])
    end
  end

  # Misma regla que las categorías: configurar cómo se carga la plata es del admin.
  describe 'quién puede' do
    it 'un dispensador no los gestiona' do
      sign_in_as(create(:user, club: club, role: 'dispensador'))

      crear

      expect(response).to have_http_status(:forbidden)
    end
  end
end
