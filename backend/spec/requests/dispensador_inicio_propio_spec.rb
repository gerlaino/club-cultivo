require 'rails_helper'

# AC: quien atiende el mostrador ve SU mostrador, no el tablero de la organización.
#
# El inicio del dispensador servía el tablero completo del club: el ranking de consumo del mes con
# nombre y apellido de cada paciente, cuántos del padrón tienen el REPROCANN vencido, el volumen
# del club por día, el inventario de todas las sedes y las entregas de delivery abiertas.
#
# Un ranking de consumo de cannabis con nombre es dato de salud (Ley 25.326) y no es algo que
# necesite quien entrega: para trabajar le alcanza con su caja, su stock y sus reservas. El admin
# sigue viendo todo, que es su trabajo.
RSpec.describe 'Inicio del dispensador — ve lo suyo', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:norte) { create(:sede, club: club, nombre: 'Norte') }
  let(:sur)   { create(:sede, club: club, nombre: 'Sur') }

  let(:ana)  { create(:user, :dispensador, club: club) }
  let(:beto) { create(:user, :dispensador, club: club) }

  let(:paciente_de_ana)  { create(:paciente, club: club, nombre: 'Pab', apellido: 'Uno') }
  let(:paciente_de_beto) { create(:paciente, club: club, nombre: 'Ceci', apellido: 'Dos') }

  def stock_en(sede, cantidad: 500)
    lote = create(:lote, club: club, sala: create(:sala, club: club, sede: sede))
    create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                   cantidad: cantidad, costo_unitario_ars: 1, precio_sugerido_ars: 10)
  end

  # No hay factory de dispensación: se crean a mano, como en el resto de la suite.
  def dispensa!(usuario:, paciente:, sede:, gramos:)
    Dispensacion.create!(paciente: paciente, user: usuario, stock: stock_en(sede), sede: sede,
                         cantidad: gramos, medio_pago: 'efectivo', aporte_socio_ars: gramos * 10,
                         fecha_dispensacion: Time.zone.today)
  end

  before do
    ActsAsTenant.with_tenant(club) do
      dispensa!(usuario: ana,  paciente: paciente_de_ana,  sede: norte, gramos: 10)
      dispensa!(usuario: beto, paciente: paciente_de_beto, sede: sur,   gramos: 40)
    end
  end

  def inicio_de(usuario)
    sign_in_as(usuario)
    get '/api/analytics/dispensador', headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)
  end

  describe 'el dispensador' do
    it 'cuenta sólo SUS dispensaciones, no las del club' do
      data = inicio_de(ana)

      expect(data['alcance']).to eq('propio')
      expect(data.dig('resumen', 'dispensaciones_hoy')).to eq(1)
      expect(data.dig('resumen', 'gramos_hoy')).to eq(10.0)
    end

    # El corazón del asunto: el ranking de consumo del mes con nombre y apellido.
    it 'no ve en el ranking a un paciente que atendió otro' do
      nombres = inicio_de(ana)['top_pacientes'].map { |p| p['paciente'] }

      expect(nombres).to include(paciente_de_ana.nombre_completo)
      expect(nombres).not_to include(paciente_de_beto.nombre_completo)
    end

    # En el mostrador la persona está enfrente: los dígitos no ayudan a reconocer a nadie y son
    # un dato identificatorio que no hace falta servir.
    it 'no recibe ni un dígito del DNI' do
      top = inicio_de(ana)['top_pacientes']

      expect(top).to be_present
      expect(top.first.keys).not_to include('dni_last4', 'iniciales')
    end

    it 'no recibe el estado del REPROCANN del padrón ni las entregas del club' do
      data = inicio_de(ana)

      expect(data).not_to have_key('reprocann')
      expect(data).not_to have_key('entregas_hoy')
    end

    it 've el stock de SU sede, no el de todas' do
      ActsAsTenant.with_tenant(club) do
        UserSede.create!(user: ana, sede: norte)
        stock_en(sur, cantidad: 9_999)
      end

      total = inicio_de(ana)['stocks'].sum { |s| s['cantidad_g'] }

      expect(total).to be < 9_999
    end
  end

  describe 'el admin' do
    it 'sigue viendo la organización entera' do
      data = inicio_de(admin)

      expect(data['alcance']).to eq('club')
      expect(data.dig('resumen', 'dispensaciones_hoy')).to eq(2)
      nombres = data['top_pacientes'].map { |p| p['paciente'] }
      expect(nombres).to include(paciente_de_ana.nombre_completo, paciente_de_beto.nombre_completo)
    end
  end

  # La clave era sólo por club y fecha. Al personalizar el contenido sin tocarla, el primero que
  # entrara le serviría SUS datos a todos los demás del club — la fuga que veníamos a cerrar,
  # servida desde la caché.
  #
  # OJO: el entorno de test usa `:null_store`, así que estos dos ejemplos pasaban en verde con la
  # clave vieja puesta. Un caché que no guarda nada no puede servir el dato de otro. Se levanta un
  # MemoryStore real sólo acá, que es lo único que hace que el test pruebe lo que dice probar.
  describe 'la caché' do
    around do |ejemplo|
      anterior = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      ejemplo.run
    ensure
      Rails.cache = anterior
    end

    it 'no le sirve a un dispensador los datos del otro' do
      de_ana  = inicio_de(ana)
      de_beto = inicio_de(beto)

      expect(de_ana.dig('resumen', 'gramos_hoy')).to eq(10.0)
      expect(de_beto.dig('resumen', 'gramos_hoy')).to eq(40.0)
    end

    it 'no le sirve al dispensador lo que se cacheó para el admin' do
      inicio_de(admin)
      data = inicio_de(ana)

      expect(data['alcance']).to eq('propio')
      expect(data.dig('resumen', 'dispensaciones_hoy')).to eq(1)
    end
  end
end
