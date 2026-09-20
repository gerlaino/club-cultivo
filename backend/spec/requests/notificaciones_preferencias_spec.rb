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
        %w[hitos_cultivo ambiente cosecha_pendiente tarea_vencida lote_critico pesaje_para_confirmar
           caja_sin_cerrar reposicion_mostrador saldo_cc_bajo plan_vence tarea_asignada]
      )
    end

    it 'sin dispensa, el admin no ve mostrador ni pacientes' do
      solo_cultivo = create(:club, features: { 'cultivo' => true })
      claves = claves_de(create(:user, :admin, club: solo_cultivo))
      expect(claves).to include('hitos_cultivo', 'plan_vence')
      expect(claves).not_to include('caja_sin_cerrar', 'reposicion_mostrador', 'saldo_cc_bajo')
    end

    it 'el cultivador ve sus tareas y nada del admin' do
      expect(claves_de(create(:user, :cultivador, club: club))).to match_array(%w[tarea_asignada tareas_del_dia])
    end

    it 'el supervisor ve la reposición y su tarea' do
      expect(claves_de(create(:user, :supervisor, club: club))).to match_array(%w[reposicion_mostrador tarea_asignada])
    end

    it 'la manicura ve una sola fila' do
      expect(claves_de(create(:user, :manicura, club: club))).to eq(%w[tarea_asignada])
    end

    it 'el cultivador de casa ve lo de cultivo y el resumen del día, sin manicura ni tareas asignadas por otro' do
      personal = create(:club, plan: 'personal', features: { 'cultivo' => true, 'iot' => true })
      claves = claves_de(create(:user, :admin, club: personal))
      expect(claves).to match_array(%w[hitos_cultivo ambiente cosecha_pendiente tarea_vencida lote_critico plan_vence tareas_del_dia])
    end
  end

  describe 'defaults' do
    it 'ambiente viene apagado sin IoT y prendido con IoT' do
      sin  = create(:user, :admin, club: club)
      con  = create(:user, :admin, club: create(:club, features: { 'cultivo' => true, 'iot' => true }))
      expect(sin.quiere_push?('ambiente')).to be false
      expect(con.quiere_push?('ambiente')).to be true
      expect(sin.quiere_push?('hitos_cultivo')).to be true
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
      expect(admin.quiere_push?('hitos_cultivo')).to be true
    end

    it 'una clave que no se le ofrece no se guarda' do
      patch '/profile/notificaciones', params: { tipos: { tareas_del_dia: true, inventada: true } }, headers: auth_headers, as: :json

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
