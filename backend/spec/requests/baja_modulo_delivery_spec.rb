require 'rails_helper'

# AC: dar de baja un módulo NO lo corta en el momento — la organización lo pagó hasta el fin del
# período. Se programa para esa fecha, sigue andando igual hasta ahí, y recién entonces se apaga
# y se ordena lo que deja colgando.
#
# En Delivery: los repartidores dejan de poder entrar (eso ya lo hace `check_rol_habilitado!`) y
# los repartos que todavía no salieron se sueltan. Lo que ya está EN VIAJE se termina: cortarlo
# dejaría al repartidor con producto de la organización y sin poder registrar la entrega.
RSpec.describe 'Baja programada del módulo Delivery', type: :request do
  let(:club) do
    create(:club, plan_activo_hasta: Date.current + 12.days,
                  features: { 'produccion_dispensa' => true, 'delivery' => true })
  end
  let(:super_admin) { create(:user, :super_admin, club: nil) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:repartidor)  { create(:user, club: club, role: 'delivery') }

  describe 'programar la baja' do
    before { sign_in_as(super_admin) }

    it 'no lo apaga hoy: lo deja andando hasta el fin del período pago' do
      patch "/api/super_admin/clubs/#{club.id}", params: { club: { features: { 'delivery' => false } } }

      expect(response).to have_http_status(:ok)
      expect(club.reload.feature?(:delivery)).to be(true), 'se cortó el módulo que ya estaba pagado'
      expect(club.baja_programada_para('delivery')).to eq(Date.current + 12.days)
    end

    it 'informa hasta cuándo, para poder decírselo a la organización' do
      patch "/api/super_admin/clubs/#{club.id}", params: { club: { features: { 'delivery' => false } } }

      baja = JSON.parse(response.body)['bajas_programadas'].first
      expect(baja['modulo']).to eq('delivery')
      expect(baja['hasta']).to eq((Date.current + 12.days).to_s)
    end

    it 'sin fecha de plan, corta a fin de mes' do
      club.update!(plan_activo_hasta: nil)
      patch "/api/super_admin/clubs/#{club.id}", params: { club: { features: { 'delivery' => false } } }

      expect(club.reload.baja_programada_para('delivery')).to eq(Date.current.end_of_month)
    end

    it 'volver a prenderlo antes del vencimiento cancela la baja' do
      club.programar_baja_modulo!('delivery')
      patch "/api/super_admin/clubs/#{club.id}", params: { club: { features: { 'delivery' => true } } }

      expect(club.reload.baja_programada?('delivery')).to be(false)
    end
  end

  describe 'cuando la fecha llega' do
    it 'deja de estar habilitado aunque el job todavía no haya corrido' do
      # Entre el vencimiento y la corrida diaria hay una ventana: nadie puede usar el módulo ahí.
      club.programar_baja_modulo!('delivery', hasta: Date.current - 1.day)
      expect(club.feature?(:delivery)).to be(false)
    end

    it 'el repartidor deja de poder trabajar' do
      club.programar_baja_modulo!('delivery', hasta: Date.current - 1.day)
      expect(repartidor.reload.rol_habilitado?).to be(false)
    end
  end

  describe 'AplicarBajasModulosJob' do
    let!(:paciente) { create(:paciente, club: club, created_by: admin) }
    let(:stock)     { create(:stock, club: club, cantidad: 500, cantidad_inicial: 500) }

    # No hay factory de Dispensacion; mismo patrón que el resto de los specs.
    #
    # El estado se fija DESPUÉS de crear: al crear con envío, `generar_codigo_paquete` fuerza
    # 'pendiente'. En la vida real pasa lo mismo — el reparto nace pendiente y arranca el viaje
    # con un update posterior.
    def envio(estado)
      d = Dispensacion.create!(paciente: paciente, user: admin, stock: stock, cantidad: 1,
                               medio_pago: 'efectivo', fecha_dispensacion: Date.current,
                               con_envio: true, delivery_id: repartidor.id,
                               direccion_envio: 'Av. Siempreviva 742', contacto_nombre: 'Quien recibe')
      d.update_column(:estado_envio, estado)
      d
    end

    before { club.programar_baja_modulo!('delivery', hasta: Date.current - 1.day) }

    it 'apaga la bandera y limpia la baja' do
      AplicarBajasModulosJob.new.perform

      expect(club.reload.features['delivery']).to be_nil
      expect(club.features_baja).to eq({})
    end

    it 'suelta los repartos que todavía no salieron' do
      pendiente = envio('pendiente')

      AplicarBajasModulosJob.new.perform

      expect(pendiente.reload.delivery_id).to be_nil
    end

    it 'NO toca lo que ya está en viaje: se termina lo que arrancó' do
      en_viaje = envio('en_viaje')

      AplicarBajasModulosJob.new.perform

      expect(en_viaje.reload.delivery_id).to eq(repartidor.id)
    end

    it 'avisa al admin que quedaron entregas sin responsable' do
      envio('pendiente')

      expect { AplicarBajasModulosJob.new.perform }
        .to change { AlertaInterna.where(tipo: 'modulo_dado_de_baja').count }.by(1)
    end

    it 'no toca las organizaciones cuya baja todavía no venció' do
      otro = create(:club, features: { 'produccion_dispensa' => true, 'delivery' => true })
      otro.programar_baja_modulo!('delivery', hasta: Date.current + 5.days)

      AplicarBajasModulosJob.new.perform

      expect(otro.reload.features['delivery']).to be(true)
    end
  end

  describe 'el rol delivery sólo se ofrece si el módulo está' do
    it 'la organización con el módulo lo incluye' do
      expect(club.roles_para_alta).to include('delivery')
    end

    it 'sin el módulo, no' do
      club.update!(features: { 'produccion_dispensa' => true })
      expect(club.roles_para_alta).not_to include('delivery')
    end

    it 'el backend rechaza crear un repartidor sin el módulo, no sólo la pantalla' do
      club.update!(features: { 'produccion_dispensa' => true })
      create(:sede, club: club)
      sign_in_as(admin)

      expect {
        post '/api/usuarios', params: { user: { email: 'r@test.com', role: 'delivery',
                                                first_name: 'Repa', last_name: 'Tidor' } }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].join).to include('Delivery')
    end
  end
end
