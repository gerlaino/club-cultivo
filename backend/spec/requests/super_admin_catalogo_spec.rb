require 'rails_helper'

# AC: qué se puede vender sale del backend, una sola vez.
#
# Antes cada pantalla del super admin repetía la lista de módulos a mano y las copias ya
# decían cosas distintas entre sí y con `Club::ADDONS`. Este endpoint es la fuente única; los
# specs de acá existen para que un módulo nuevo no se olvide en el camino.
RSpec.describe 'SuperAdmin catálogo', type: :request do
  let(:club)        { create(:club) }
  let(:super_admin) { create(:user, :super_admin) }

  def catalogo
    get '/api/super_admin/catalogo'
    JSON.parse(response.body)
  end

  describe 'GET /super_admin/catalogo' do
    before { sign_in_as(super_admin) }

    it 'devuelve los planes con sus límites' do
      planes = catalogo['planes']

      # Dos de organización y el personal (sep-2026), que viaja marcado como tal y sin equipo.
      expect(planes.map { |p| p['clave'] }).to contain_exactly('basico', 'total', 'personal')
      personal = planes.find { |p| p['clave'] == 'personal' }
      expect(personal).to include('personal' => true, 'equipo' => false)

      basico = planes.find { |p| p['clave'] == 'basico' }
      # Los escalones del 6-oct-2026.
      expect(personal['limites']).to include('plantas' => 9, 'salas' => 2, 'pacientes' => 0)
      expect(personal['precios'].values).to eq([8])

      expect(basico['limites']).to include('sedes' => 1, 'salas' => 3, 'plantas' => 450, 'pacientes' => 50)
      # Los lotes NO se limitan: el lote organiza, no mide capacidad.
      expect(basico['limites']['lotes']).to    be_nil
      # El de usuarios no es un número: es dos de cada rol, y viaja aparte para poder decirlo
      # con palabras en vez de con una barra que no significa nada.
      expect(basico['usuarios_por_rol']).to    eq(2)
      expect(basico['por_sede']).to            be(false)
      expect(basico['precios']).to             eq('1' => 200, '2' => 350)

      total = planes.find { |p| p['clave'] == 'total' }
      expect(total['limites']).to include('sedes' => 3, 'salas' => nil, 'plantas' => 900, 'pacientes' => 100)
      expect(total['usuarios_por_rol']).to eq(2)
      expect(total['por_sede']).to         be(true)
      expect(total['precios']).to          eq('1' => 400, '2' => 700)
    end

    it 'dice cuánto suma cada pack de pacientes y cada sede extra' do
      c = catalogo

      expect(c['pack_pacientes']).to eq('pacientes' => 10, 'plantas' => 90, 'precio_mensual' => 80)
      expect(c['sede_extra']).to     eq('precio_mensual' => 50)
      expect(c['moneda']).to         eq('USD')
    end

    it 'arma el resumen del plan para que el frontend no invente el vocabulario' do
      basico = catalogo['planes'].find { |p| p['clave'] == 'basico' }

      expect(basico['resumen']).to include('1 sedes', '3 salas', '450 plantas en floración')

      total = catalogo['planes'].find { |p| p['clave'] == 'total' }
      expect(total['resumen']).to include('salas sin límite', '900 plantas en floración')
    end

    it 'separa los módulos en los cajones que el panel muestra' do
      c = catalogo

      expect(c['suites'].map  { |s| s['clave'] }).to contain_exactly('cultivo', 'produccion_dispensa')
      # Los extras que se cobran aparte (en desarrollo) y lo que va a venir incluido cuando esté listo.
      extras = c['addons'].select { |a| a['tipo'] == 'extra' }.map { |a| a['clave'] }
      expect(extras).to contain_exactly('bar', 'vista_paciente', 'chatbot', 'iot')
      expect(c['addons'].select { |a| a['tipo'] == 'incluido_proximo' }.map { |a| a['clave'] })
        .to contain_exactly('whatsapp', 'ariccame')
      # Lo terminado viene adentro de los packs (6-oct-2026).
      expect(c['incluidos'].map { |i| i['clave'] }).to contain_exactly('medico', 'delivery', 'mailer', 'ia')
      # El cajón de "en construcción" está vacío hoy: `vista_paciente` salió a add-on cuando el
      # paciente pudo entrar. Que el catálogo lo siga informando (aunque vacío) es lo que hace
      # que el panel no se rompa el día que entre el próximo.
      expect(c).to have_key('en_construccion')
    end

    it 'dice de qué suite depende cada módulo incluido' do
      medico = catalogo['incluidos'].find { |i| i['clave'] == 'medico' }

      expect(medico['incluido_en']).to       eq(['produccion_dispensa'])
      expect(medico['incluido_en_label']).to eq('Producción y dispensa')

      ia = catalogo['incluidos'].find { |i| i['clave'] == 'ia' }
      expect(ia['incluido_en']).to contain_exactly('cultivo', 'produccion_dispensa')
    end

    it 'marca los add-ons incompletos con el motivo' do
      buffet = catalogo['addons'].find { |a| a['clave'] == 'bar' }

      expect(buffet['incompleto']).to be(true)
      expect(buffet['requiere']).to be_present
    end

    it 'marca los bloqueados, que no se pueden prender ni para probar' do
      ariccame = catalogo['addons'].find { |a| a['clave'] == 'ariccame' }

      expect(ariccame['bloqueado']).to be(true)
      expect(ariccame['motivo_bloqueo']).to be_present
    end

    # Los tramos de IA estaban escritos a mano en el template del panel, con los topes POR HORA
    # copiados en un array (`[20,60,200]`). Cambiar un tramo acá dejaba a la pantalla mostrando
    # y guardando el número viejo: la misma duplicación que ya había pasado con los módulos.
    it 'devuelve los tramos de IA, uno por plan' do
      tiers = catalogo['ia_tiers']

      # Uno POR PLAN, con su clave: el tramo de IA sale del plan y no de una perilla aparte,
      # que era la misma decisión escrita en dos lugares que dejaban de coincidir.
      expect(tiers.map { |t| t['clave'] }).to eq(%w[basico total personal])
      expect(tiers).to all(include('label' => be_present, 'limite_hora' => be_present,
                                   'limite_mes' => be_present))
    end

    # El alta elige los MÓDULOS antes que el plan, así que puede mostrar sólo los topes que
    # aplican: nombrarle salas y plantas a una organización que no compró Cultivo es la mitad de
    # la tarjeta en ruido, y desde ahí no hay forma de saber cuáles cuentan.
    it 'dice a qué suite le importa cada tope' do
      recursos = catalogo['planes'].find { |p| p['clave'] == 'basico' }['recursos']
      por_clave = recursos.to_h { |r| [r['clave'], r['suite']] }

      expect(por_clave['plantas']).to   eq('cultivo')
      expect(por_clave['pacientes']).to eq('produccion_dispensa')
      expect(por_clave['sedes']).to     be_nil   # le importa a cualquiera
    end

    # Un cultivador en una organización sin Cultivo loguea a una app sin una sola pantalla, y
    # el que lo descubre es el cliente.
    it 'dice de qué módulo depende cada rol del alta' do
      roles = catalogo['roles_alta'].to_h { |r| [r['clave'], r['requiere_modulo']] }

      expect(roles['cultivador']).to  eq('cultivo')
      expect(roles['dispensador']).to eq('produccion_dispensa')
      expect(roles['admin']).to       be_nil   # transversal
    end

    # Lo que se COBRA es el mensual: el horario es freno de ráfaga. Si el catálogo no lo
    # mandara, el panel volvería a mostrar el que menos importa.
    it 'los tramos coinciden con los del modelo, que es donde se aplican' do
      basico = catalogo['ia_tiers'].find { |t| t['clave'] == 'basico' }

      expect(basico['limite_mes']).to  eq(Club::IA_TIERS['basico'][:limite_mes])
      expect(basico['limite_hora']).to eq(Club::IA_TIERS['basico'][:limite_hora])
    end

    # Supervisor, abogado y auditor existen, pero no son parte del arranque de un club.
    it 'ofrece sólo los roles del alta' do
      roles = catalogo['roles_alta'].map { |r| r['clave'] }

      expect(roles).to contain_exactly('admin', 'medico', 'cultivador', 'dispensador', 'manicura')
      expect(catalogo['roles_alta']).to all(include('label' => be_present, 'desc' => be_present))
    end
  end

  # La cuenta del alta la hace el backend: la pantalla no suma precios por su cuenta.
  describe 'GET /super_admin/catalogo/cotizar' do
    before { sign_in_as(super_admin) }

    def cotizar(params)
      get '/api/super_admin/catalogo/cotizar', params: params
      JSON.parse(response.body)
    end

    it 'un pack en «Hasta 50 pacientes» son 200; los dos, 350' do
      expect(cotizar(plan: 'basico', suites: %w[cultivo])['total']).to eq(200)
      expect(cotizar(plan: 'basico', suites: %w[cultivo produccion_dispensa])['total']).to eq(350)
    end

    it '«Hasta 100 pacientes»: 400 un pack, 700 los dos' do
      expect(cotizar(plan: 'total', suites: %w[produccion_dispensa])['total']).to eq(400)
      expect(cotizar(plan: 'total', suites: %w[cultivo produccion_dispensa])['total']).to eq(700)
    end

    # El caso de la conversación: 53 pacientes no paga el escalón de 100, suma un pack de 10.
    it '53 pacientes: el escalón de 50 más un pack de 10 (8 por paciente)' do
      r = cotizar(plan: 'basico', suites: %w[cultivo produccion_dispensa], packs_pacientes: 1)
      expect(r['total']).to eq(350 + 80)
      expect(r['moneda']).to eq('USD')
    end

    it 'cada sede extra suma 50' do
      expect(cotizar(plan: 'total', suites: %w[cultivo produccion_dispensa], sedes_extra: 2)['total']).to eq(800)
    end

    it 'el autocultivo son 8, y no compra extras' do
      expect(cotizar(plan: 'personal', suites: %w[cultivo], packs_pacientes: 3, sedes_extra: 1)['total']).to eq(8)
    end

    it 'los extras en desarrollo se listan sin cargo' do
      r = cotizar(plan: 'basico', suites: %w[produccion_dispensa], extras: %w[bar vista_paciente])
      expect(r['total']).to eq(200)
      expect(r['lineas'].map { |l| l['clave'] }).to include('bar', 'vista_paciente')
    end

    it 'un admin de organización no puede pedirla' do
      sign_in_as(create(:user, :admin, club: club))
      get '/api/super_admin/catalogo/cotizar', params: { plan: 'basico' }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'quién puede verlo' do
    it 'un admin de club no accede al catálogo de la plataforma' do
      sign_in_as(create(:user, :admin, club: club))

      get '/api/super_admin/catalogo'

      expect(response).to have_http_status(:forbidden)
    end

    it 'sin sesión tampoco' do
      get '/api/super_admin/catalogo'

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
