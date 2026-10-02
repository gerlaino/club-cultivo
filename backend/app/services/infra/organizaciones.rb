# CUÁNTO PESA CADA ORGANIZACIÓN, y cuánto pesa todo.
#
# Es lo que hace crecer la cuenta de Render: filas en la base y archivos en el bucket. No es un
# informe de negocio (eso es Informes): es para saber quién usa cuánto antes de que el servidor
# avise, y cuándo hay que subir de plan.
#
# Todo agregado y por organización. Ni un dato de un paciente.
module Infra
  class Organizaciones
    CACHE = 'plataforma/organizaciones'.freeze
    TTL   = 15.minutes
    TABLAS_MAS_GRANDES = 8

    def self.call
      Rails.cache.fetch(CACHE, expires_in: TTL) { new.call }
    end

    def call
      ActsAsTenant.without_tenant do
        { base: base, archivos: archivos, organizaciones: organizaciones }
      end
    end

    private

    def base
      con = ActiveRecord::Base.connection
      tablas = con.select_rows(<<~SQL)
        SELECT relname, pg_total_relation_size(relid)
        FROM pg_catalog.pg_statio_user_tables
        ORDER BY pg_total_relation_size(relid) DESC
        LIMIT #{TABLAS_MAS_GRANDES}
      SQL
      {
        tamano_mb: mb(con.select_value('SELECT pg_database_size(current_database())')),
        tablas: tablas.map { |nombre, bytes| { nombre: nombre, tamano_mb: mb(bytes) } },
      }
    end

    def archivos
      { cantidad: ActiveStorage::Blob.count, tamano_mb: mb(ActiveStorage::Blob.sum(:byte_size)) }
    end

    def organizaciones
      clubes = Club.activos.order(:name).to_a
      ids    = clubes.map(&:id)
      desde  = 30.days.ago
      conteo = ->(rel) { rel.where(club_id: ids).group(:club_id).count }

      pacientes = conteo.call(Paciente.unscoped.where(deleted_at: nil))
      usuarios  = conteo.call(User.unscoped)
      # La dispensa no lleva `club_id`: es de la organización de su paciente.
      dispensas = Dispensacion.unscoped.where(deleted_at: nil).where('dispensaciones.created_at >= ?', desde)
                              .joins('INNER JOIN pacientes ON pacientes.id = dispensaciones.paciente_id')
                              .where(pacientes: { club_id: ids }).group('pacientes.club_id').count
      lotes     = conteo.call(Lote.unscoped.where(deleted_at: nil))
      visto     = User.unscoped.where(club_id: ids).group(:club_id).maximum(:visto_at)

      clubes.map do |c|
        { id: c.id, nombre: c.name, slug: c.slug, plan: c.try(:plan),
          pacientes: pacientes[c.id].to_i, usuarios: usuarios[c.id].to_i,
          dispensas_30d: dispensas[c.id].to_i, lotes: lotes[c.id].to_i,
          ultimo_uso: visto[c.id] }
      end.sort_by { |o| -(o[:pacientes] + o[:dispensas_30d]) }
    end

    def mb(bytes) = (bytes.to_f / 1024 / 1024).round(1)
  end
end
