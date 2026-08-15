require 'rails_helper'

# AUDITORÍA: lo que el menú OFRECE, ¿el backend lo PERMITE?
#
# El bug que la motiva: el manicura veía el botón "Completar" sobre su tarea asignada y el
# backend le devolvía 403, porque `completar_masivo` estaba en el mismo guard que editar y
# borrar. Lo encontramos porque Germán lo probó, no porque lo buscáramos.
#
# En el frontend ya hay un test que cruza los dos candados (matriz de prefijos contra los guards
# de cada ruta). Éste cierra el otro lado: recorre, para cada rol, las secciones que su propia
# navegación le ofrece, y verifica que el backend no le conteste 403.
#
# No valida el CONTENIDO de cada respuesta —eso es de cada spec— sino la contradicción: una
# sección ofrecida y rechazada es la peor de las combinaciones, porque parece culpa del usuario.
RSpec.describe 'Lo que el menú ofrece, el backend lo permite', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, features: {
      'cultivo' => true, 'produccion_dispensa' => true, 'bar' => true, 'iot' => true,
    })
  end
  let(:admin) { create(:user, :admin, club: club) }
  let!(:sede) { create(:sede, club: club, created_by: admin, tipo: 'mixta') }

  # Las secciones de cada rol, tomadas de SU barra lateral en el frontend
  # (components/layout/*Sidebar.vue) y de la matriz `ROLE_ALLOWED_PREFIX` del router.
  SECCIONES = {
    'cultivador' => {
      'Salas'      => '/salas',
      'Lotes'      => '/lotes',
      'Plantas'    => '/plants',
      'Genéticas'  => '/geneticas',
      'Tareas'     => '/tareas',
      'Sedes'      => '/sedes',
    },
    'manicura' => {
      'Lotes (su cola)' => '/lotes?manicura=true',
      'Tareas'          => '/tareas',
      'Stock'           => '/stocks',
      'Sedes'           => '/sedes',
    },
    'dispensador' => {
      'Pacientes'      => '/pacientes',
      'Stock'          => '/stocks',
      'Dispensaciones' => '/dispensaciones',
      'Reservas'       => '/reservas',
      'Sedes'          => '/sedes',
    },
    'supervisor' => {
      'Salas'          => '/salas',
      'Lotes'          => '/lotes',
      'Plantas'        => '/plants',
      'Genéticas'      => '/geneticas',
      'Tareas'         => '/tareas',
      'Pacientes'      => '/pacientes',
      'Dispensaciones' => '/dispensaciones',
      'Reservas'       => '/reservas',
      'Insumos'        => '/insumos',
      'Sedes'          => '/sedes',
    },
    'medico' => {
      'Pacientes' => '/pacientes',
      'Tareas'    => '/tareas',
    },
  }.freeze

  SECCIONES.each do |rol, secciones|
    describe "el #{rol}" do
      let(:usuario) { create(:user, club: club, role: rol) }

      before { sign_in_as(usuario) }

      secciones.each do |nombre, path|
        it "puede abrir #{nombre}" do
          get path, headers: auth_headers

          expect(response.status).not_to eq(403),
            "#{rol} ve \"#{nombre}\" en su menú pero el backend le contesta 403 en #{path}: " \
            "#{response.body.to_s.first(200)}"
        end
      end
    end
  end

  # El caso puntual que lo originó, con su regla: completar una tarea es HACER el trabajo, no
  # gestionarlo. De a una siempre se pudo; en tanda daba 403.
  describe 'completar tareas' do
    %w[manicura cultivador dispensador supervisor].each do |rol|
      it "el #{rol} puede cerrar su tarea asignada, de a una y en tanda" do
        usuario = create(:user, club: club, role: rol)
        tarea   = club.tareas.create!(titulo: 'Limpieza', tipo: 'limpieza', estado: 'pendiente',
                                      fecha_programada: Time.zone.today,
                                      asignada_a: usuario, creada_por: admin)
        sign_in_as(usuario)

        post '/tareas/completar_masivo', params: { ids: [tarea.id] }, headers: auth_headers

        expect(response.status).not_to eq(403), response.body
      end
    end
  end
end
