# QUIÉNES CAMBIAN DE ESTADO CON LOS TRES EJES (19-oct-2026). Sólo lee: compara lo que la lista
# mostraba antes (`reprocann_categoria`) con lo que muestra ahora (`Pacientes::Situacion`), para
# revisarlo con la organización antes de usarlo.
#
#   bin/rails pacientes:estados_nuevos            # todas las organizaciones
#   CLUB_ID=2 bin/rails pacientes:estados_nuevos  # una
namespace :pacientes do
  desc 'Lista los pacientes cuyo estado del REPROCANN se ve distinto con los tres ejes (sólo lee)'
  task estados_nuevos: :environment do
    ANTES = { 'vigente' => 'Vigente', 'por_vencer' => 'Vence en 30 días', 'vencido' => 'Vencido',
              'pendiente' => 'En trámite', 'sin_reprocann' => 'Sin REPROCANN' }.freeze
    AHORA = { 'pendiente_entrevista' => 'Pendiente de entrevista', 'pendiente_aprobacion' => 'Pendiente de aprobación',
              'activo' => 'Activo', 'vencido' => 'Vencido', 'no_indicado' => 'No indicado', 'rechazado' => 'Rechazado',
              'sin_dato' => 'Sin dato' }.freeze
    # Lo que es el mismo estado con otro nombre no cuenta como cambio.
    IGUALES = { 'vigente' => %w[activo], 'por_vencer' => %w[activo], 'vencido' => %w[vencido],
                'pendiente' => %w[pendiente_aprobacion], 'sin_reprocann' => %w[pendiente_entrevista] }.freeze

    clubs = ENV['CLUB_ID'].present? ? Club.where(id: ENV['CLUB_ID']) : Club.all
    clubs.find_each do |club|
      ActsAsTenant.with_tenant(club) do
        cambios = club.pacientes.order(:apellido, :nombre).filter_map do |p|
          antes = p.reprocann_categoria
          ahora = p.reprocann_situacion
          next if IGUALES[antes]&.include?(ahora)

          "  #{p.apellido}, #{p.nombre} (##{p.id}): #{ANTES[antes]} → #{AHORA[ahora]}" \
            "#{p.reprocann_vinculo.blank? ? ' · vínculo sin dato (cuenta como vinculado)' : ''}"
        end
        sin_dato = club.pacientes.where(reprocann_vinculo: [nil, '']).count
        next if cambios.empty? && sin_dato.zero?

        puts "\n#{club.name} (##{club.id}) — #{cambios.size} cambian · #{sin_dato} sin dato de vínculo"
        puts cambios
      end
    end
  end
end
