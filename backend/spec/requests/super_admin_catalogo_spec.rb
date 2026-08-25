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

    it 'devuelve los dos planes con sus límites' do
      planes = catalogo['planes']

      expect(planes.map { |p| p['clave'] }).to contain_exactly('basico', 'total')

      basico = planes.find { |p| p['clave'] == 'basico' }
      expect(basico['limites']['salas']).to    eq(3)
      expect(basico['limites']['plantas']).to  eq(450)
      # Los lotes NO se limitan: el lote organiza, no mide capacidad.
      expect(basico['limites']['lotes']).to    be_nil
      # El de usuarios no es un número: es uno de cada rol, y viaja aparte para poder decirlo
      # con palabras en vez de con una barra que no significa nada.
      expect(basico['usuarios_por_rol']).to    eq(1)

      total = planes.find { |p| p['clave'] == 'total' }
      expect(total['limites'].values).to all(be_nil)
      expect(total['usuarios_por_rol']).to be_nil
    end

    it 'arma el resumen del plan para que el frontend no invente el vocabulario' do
      basico = catalogo['planes'].find { |p| p['clave'] == 'basico' }

      expect(basico['resumen']).to include('1 sedes', '3 salas', '450 plantas')

      total = catalogo['planes'].find { |p| p['clave'] == 'total' }
      expect(total['resumen']).to all(match(/sin límite/))
    end

    it 'separa los módulos en los cajones que el panel muestra' do
      c = catalogo

      expect(c['suites'].map  { |s| s['clave'] }).to contain_exactly('cultivo', 'produccion_dispensa')
      expect(c['addons'].map  { |a| a['clave'] }).to include('bar', 'iot', 'ia', 'whatsapp', 'mailer', 'vista_paciente')
      # El médico no es add-on: viene dentro de la suite. El correo SÍ pasó a serlo cuando dejó
      # de ser "mandar un mail desde la ficha" y se volvió un espacio propio que se vende.
      expect(c['addons'].map  { |a| a['clave'] }).not_to include('medico')
      expect(c['incluidos'].map { |i| i['clave'] }).to contain_exactly('medico')
      # El cajón de "en construcción" está vacío hoy: `vista_paciente` salió a add-on cuando el
      # paciente pudo entrar. Que el catálogo lo siga informando (aunque vacío) es lo que hace
      # que el panel no se rompa el día que entre el próximo.
      expect(c).to have_key('en_construccion')
    end

    it 'dice de qué suite depende cada módulo incluido' do
      medico = catalogo['incluidos'].find { |i| i['clave'] == 'medico' }

      expect(medico['incluido_en']).to       eq('produccion_dispensa')
      expect(medico['incluido_en_label']).to eq('Producción y dispensa')
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
    it 'devuelve los tramos de IA con sus dos topes' do
      tiers = catalogo['ia_tiers']

      # DOS, y con la clave del plan: el tramo de IA sale del plan y no de una perilla aparte,
      # que era la misma decisión escrita en dos lugares que dejaban de coincidir.
      expect(tiers.map { |t| t['clave'] }).to eq(%w[basico total])
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
