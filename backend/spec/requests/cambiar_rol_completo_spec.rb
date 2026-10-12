require 'rails_helper'

# AC (Germán, 12-oct-2026): «chequear que al cambiar de rol a algún miembro del equipo se cambie
# todo como corresponde». No alcanza con cambiar la columna: lo que no se puede dejar colgado se
# bloquea, lo que deja de tener sentido se limpia, la persona con la app abierta se entera, y la
# confirmación dice antes exactamente lo que va a pasar.
RSpec.describe 'Cambiar el rol de alguien del equipo, entero', type: :request do
  let(:club)   { create(:club, features: { 'produccion_dispensa' => true, 'cultivo' => true }) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:social) { create(:sede, club: club, tipo: 'social', nombre: 'Centro') }
  let(:prod)   { create(:sede, club: club, tipo: 'produccion', nombre: 'Quinta') }
  let(:mixta)  { create(:sede, club: club, tipo: 'mixta', nombre: 'Norte') }

  before { sign_in_as(admin) }

  def json = JSON.parse(response.body)
  def cambiar(user, rol, **extra) = patch("/api/usuarios/#{user.id}", params: { user: { role: rol, **extra } }, as: :json)

  describe 'lo que deja de tener sentido se limpia' do
    let(:lucia) { create(:user, :dispensador, club: club, first_name: 'Lucía') }

    before do
      UserSede.create!(user: lucia, sede: social)
      UserSede.create!(user: lucia, sede: mixta)
    end

    it 'las sedes donde el rol nuevo no tiene nada que hacer se quitan; las que sirven quedan' do
      cambiar(lucia, 'cultivador')
      expect(response).to have_http_status(:ok)
      expect(lucia.reload.role).to eq('cultivador')
      expect(lucia.sedes_asignadas.map(&:nombre)).to eq(['Norte'])
    end

    it 'si el admin elige sedes para el rol nuevo, quedan esas (y sólo las de un tipo que el rol atiende)' do
      cambiar(lucia, 'cultivador', sede_ids: [prod.id, social.id])
      expect(lucia.reload.sedes_asignadas.map(&:nombre)).to eq(['Quinta'])
    end

    it 'las salas de cultivo se quitan si el rol nuevo no cultiva' do
      cult = create(:user, :cultivador, club: club)
      sala = create(:sala, club: club, sede: prod, created_by: admin)
      SalaCultivador.create!(sala: sala, user: cult)
      cambiar(cult, 'dispensador')
      expect(cult.reload.sala_cultivadores).to be_empty
    end

    it 'las tareas activas quedan sin asignar si el rol nuevo no tiene pantalla de tareas; las cerradas no se tocan' do
      t_activa = ActsAsTenant.with_tenant(club) { create(:tarea, club: club, asignada_a: lucia, estado: 'pendiente') }
      t_hecha  = ActsAsTenant.with_tenant(club) { create(:tarea, club: club, asignada_a: lucia, estado: 'completada') }
      cambiar(lucia, 'delivery')
      expect(response).to have_http_status(:ok)
      expect(t_activa.reload.asignada_a_id).to be_nil
      expect(t_hecha.reload.asignada_a_id).to eq(lucia.id)
    end
  end

  describe 'lo que no se puede dejar colgado se bloquea' do
    it 'una caja abierta a su nombre: que la cierre antes' do
      lucia = create(:user, :dispensador, club: club, first_name: 'Lucía')
      ActsAsTenant.with_tenant(club) { Mostradores::AbrirCaja.call(mostrador: social.mostrador!, usuario: lucia, efectivo_contado_ars: 0) }
      cambiar(lucia, 'cultivador')
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].first).to include('tiene abierta la caja de Centro')
      expect(lucia.reload.role).to eq('dispensador')
    end

    it 'un médico con turnos por venir: que se reasignen antes' do
      medico = create(:user, :medico, club: club)
      paciente = create(:paciente, club: club, created_by: admin)
      ActsAsTenant.with_tenant(club) { create(:turno, club: club, medico: medico, paciente: paciente, fecha_hora: 3.days.from_now) }
      cambiar(medico, 'dispensador')
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].first).to include('turno')
      expect(medico.reload.role).to eq('medico')
    end
  end

  it 'la persona con la app abierta se entera: se avisa por el canal de su organización' do
    lucia = create(:user, :dispensador, club: club)
    expect { cambiar(lucia, 'cultivador') }
      .to have_broadcasted_to("club_#{club.id}").with(hash_including(recurso: 'usuarios', accion: 'rol', id: lucia.id))
  end

  it 'cambiar sólo el nombre no toca nada más ni avisa un cambio de rol' do
    lucia = create(:user, :dispensador, club: club)
    UserSede.create!(user: lucia, sede: social)
    expect { patch("/api/usuarios/#{lucia.id}", params: { user: { first_name: 'Lu' } }, as: :json) }
      .not_to have_broadcasted_to("club_#{club.id}").with(hash_including(accion: 'rol'))
    expect(lucia.reload.first_name).to eq('Lu')
    expect(lucia.sedes_asignadas.map(&:nombre)).to eq(['Centro'])
  end

  describe 'la confirmación dice antes lo que va a pasar' do
    it 'lista lo que se limpia y lo que bloquea, sin cambiar nada' do
      lucia = create(:user, :dispensador, club: club, first_name: 'Lucía')
      UserSede.create!(user: lucia, sede: social)
      get "/api/usuarios/#{lucia.id}/cambio_de_rol", params: { rol: 'cultivador' }
      expect(json['bloqueos']).to eq([])
      expect(json['cambios'].join(' ')).to include('Deja de estar asignado a Centro', 'va a ver toda la organización')
      expect(lucia.reload.role).to eq('dispensador')
      expect(lucia.sedes_asignadas.count).to eq(1)
    end
  end

  it 'el usuario de otra organización no existe para este admin' do
    otro = create(:user, :dispensador, club: create(:club))
    cambiar(otro, 'cultivador')
    expect(response).to have_http_status(:not_found)
    expect(otro.reload.role).to eq('dispensador')
  end
end
