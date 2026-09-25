require 'rails_helper'

# Qué avisos quiere cada persona en el teléfono (20-sep-2026). La regla: cada uno ve SÓLO los
# avisos que su rol puede recibir y SÓLO de los módulos que su organización tiene; lo que no se
# ofrece no se manda. La lista la arma el backend (`Notificaciones::Catalogo`), la pantalla la
# muestra.
RSpec.describe 'Mi perfil → Notificaciones', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club) { create(:club, features: { 'cultivo' => true, 'produccion_dispensa' => true }) }

  describe 'qué ve cada rol' do
    def claves_de(user)
      sign_in_as(user)
      get '/profile/notificaciones', headers: auth_headers
      json['tipos'].map { |t| t['clave'] }
    end

    it 'el admin de una organización con cultivo y dispensa ve todo lo suyo' do
      expect(claves_de(create(:user, :admin, club: club))).to match_array(
        %w[pesaje_para_confirmar reposicion_mostrador caja_sin_cerrar tarea_asignada plan_vence
           recordatorio_tarea hitos_cultivo camas cosecha_pendiente tarea_vencida lote_critico ambiente reponer_insumos saldo_cc_bajo]
      )
    end

    it 'sin dispensa, el admin no ve mostrador ni pacientes' do
      solo_cultivo = create(:club, features: { 'cultivo' => true })
      claves = claves_de(create(:user, :admin, club: solo_cultivo))
      expect(claves).to include('hitos_cultivo', 'plan_vence')
      expect(claves).not_to include('caja_sin_cerrar', 'reposicion_mostrador', 'saldo_cc_bajo')
    end

    # Las camas de suelo vivo las trabaja quien cultiva: el aviso de sus camas le llega también a él.
    it 'el cultivador ve sus tareas, el aviso de sus camas y nada del admin' do
      expect(claves_de(create(:user, :cultivador, club: club))).to match_array(%w[tarea_asignada recordatorio_tarea camas])
    end

    it 'el supervisor ve la reposición y su tarea' do
      expect(claves_de(create(:user, :supervisor, club: club))).to match_array(%w[reposicion_mostrador tarea_asignada recordatorio_tarea reponer_insumos])
    end

    it 'la manicura ve dos filas: la tarea que le asignan y sus recordatorios' do
      expect(claves_de(create(:user, :manicura, club: club))).to match_array(%w[tarea_asignada recordatorio_tarea])
    end

    it 'el cultivador de casa ve lo de cultivo y sus recordatorios, sin manicura ni tareas asignadas por otro' do
      personal = create(:club, plan: 'personal', features: { 'cultivo' => true, 'iot' => true })
      claves = claves_de(create(:user, :admin, club: personal))
      expect(claves).to match_array(%w[plan_vence recordatorio_tarea hitos_cultivo camas cosecha_pendiente tarea_vencida lote_critico ambiente reponer_insumos])
    end

    it 'viene en dos familias, con su explicación' do
      sign_in_as(create(:user, :admin, club: club))
      get '/profile/notificaciones', headers: auth_headers
      expect(json['tipos'].map { |t| t['grupo'] }.uniq).to eq(['Te piden algo', 'Recordatorios'])
      expect(json['grupos']).to include('Te piden algo', 'Recordatorios')
    end
  end

  describe 'defaults' do
    it '«te piden algo» prendido, «recordatorios» apagado en una organización' do
      admin = create(:user, :admin, club: club)
      expect(admin.quiere_push?('pesaje_para_confirmar')).to be true
      expect(admin.quiere_push?('caja_sin_cerrar')).to be true
      expect(admin.quiere_push?('hitos_cultivo')).to be false
      expect(admin.quiere_push?('ambiente')).to be false
      # El recordatorio de una tarea lo pidió la persona al crearla: sale.
      expect(admin.quiere_push?('recordatorio_tarea')).to be true
    end

    it 'en uso personal los próximos pasos del ciclo y la cosecha vienen prendidos' do
      personal = create(:club, plan: 'personal', features: { 'cultivo' => true })
      yo = create(:user, :admin, club: personal)
      expect(yo.quiere_push?('hitos_cultivo')).to be true
      expect(yo.quiere_push?('cosecha_pendiente')).to be true
      expect(yo.quiere_push?('tarea_vencida')).to be false
    end
  end

  describe 'guardar' do
    let(:admin) { create(:user, :admin, club: club) }
    before { sign_in_as(admin) }

    it 'apaga un tipo y lo devuelve apagado' do
      patch '/profile/notificaciones', params: { tipos: { caja_sin_cerrar: false } }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json['tipos'].find { |t| t['clave'] == 'caja_sin_cerrar' }['activo']).to be false
      expect(admin.reload.quiere_push?('caja_sin_cerrar')).to be false
      # Los demás siguen como estaban.
      expect(admin.quiere_push?('pesaje_para_confirmar')).to be true
    end

    it 'una clave que no se le ofrece no se guarda' do
      patch '/profile/notificaciones', params: { tipos: { pesaje_para_confirmar_de_otro: true, inventada: true } }, headers: auth_headers, as: :json

      expect(admin.reload.notificaciones_config['tipos']).to eq({})
    end

    it 'no molestar se prende y se apaga' do
      patch '/profile/notificaciones', params: { no_molestar: true }, headers: auth_headers, as: :json
      expect(json['no_molestar']).to be true
      patch '/profile/notificaciones', params: { no_molestar: false }, headers: auth_headers, as: :json
      expect(json['no_molestar']).to be false
    end
  end
end
