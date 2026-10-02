# frozen_string_literal: true

# ─────────────────────────────────────────────────────────────────────────────
# Backups de PostgreSQL → bucket S3 (AWS hoy; también R2 o cualquier S3-compatible).
#
# A propósito, estas tareas NO dependen de :environment: no bootean la app (no
# necesitan SECRET_KEY_BASE / DEVISE_JWT_SECRET_KEY ni el resto de los secrets de
# prod), sólo usan ENV + pg_dump/pg_restore + aws-sdk-s3.
#
# Requisitos del entorno donde corren:
#   - pg_dump / pg_restore (postgresql-client) en el PATH.
#   - Gema aws-sdk-s3 (ya está en el Gemfile).
#   - Variables de entorno (ver docs/DEPLOY.md §3.3 — de dónde sale cada valor).
#
# Tareas:
#   rake backup:create                    # cron diario: dump + subida + retención
#   rake backup:list                      # lista los backups del bucket
#   rake backup:prune                     # borra los de > 30 días
#   rake backup:verificar                 # cron diario: ¿el último dump se lee y trae las tablas clave?
#   rake 'backup:restore[<key>]'          # restaura un backup (emergencia)
# ─────────────────────────────────────────────────────────────────────────────

require_relative "../club_backup"

# Los errores de configuración (falta el bucket, la región…) salen como `ClubBackup::Error`: acá se
# convierten en el `abort` de siempre, con el mismo mensaje.
def con_backup
  yield
rescue ClubBackup::Error => e
  abort "✗ #{e.message}"
end

namespace :backup do
  desc "pg_dump (formato custom, comprimido) + subida al bucket + retención 30d. Cron diario."
  task :create do
    ts   = Time.now.utc.strftime("%Y-%m-%d_%H%M%S")
    key  = "#{ClubBackup::PREFIX}club_cultivo_#{ts}.dump"
    file = File.join(ClubBackup.tmp_dir, "club_cultivo_#{ts}.dump")

    con_backup do
      puts "⏳ pg_dump → #{file}"
      ok = system("pg_dump", "--format=custom", "--no-owner", "--no-privileges",
                  "--file=#{file}", ClubBackup.database_url)
      abort "✗ pg_dump falló (revisá pg_dump/DATABASE_URL)." unless ok && File.exist?(file) && File.size(file).positive?

      cli = ClubBackup.client
      puts "⏳ subiendo a s3://#{ClubBackup.bucket}/#{key} (#{ClubBackup.mb(File.size(file))} MB)…"
      File.open(file, "rb") { |f| cli.put_object(bucket: ClubBackup.bucket, key: key, body: f) }
      puts "✓ Backup subido: #{key}"

      ClubBackup.prune(cli)
    end
  ensure
    File.delete(file) if defined?(file) && file && File.exist?(file)
  end

  desc "Borra del bucket los backups de más de 30 días."
  task :prune do
    con_backup { ClubBackup.prune(ClubBackup.client) }
  end

  desc "Lista los backups disponibles en el bucket (el más nuevo, último)."
  task :list do
    con_backup do
      objs = ClubBackup.all_objects(ClubBackup.client).sort_by(&:last_modified)
      objs.each do |o|
        puts "#{o.last_modified.utc.strftime('%Y-%m-%d %H:%M')} UTC  #{format('%8.1f', ClubBackup.mb(o.size))} MB  #{o.key}"
      end
      puts "(#{objs.size} backup(s) en s3://#{ClubBackup.bucket}/#{ClubBackup::PREFIX})"
    end
  end

  desc "Restaura un backup del bucket. Uso: rake 'backup:restore[postgres/club_cultivo_YYYY-MM-DD_HHMMSS.dump]'"
  task :restore, [:key] do |_t, args|
    key = args[:key].to_s.strip
    abort "✗ Pasá la key del backup. Listalas con: bundle exec rake backup:list" if key.empty?

    file = File.join(ClubBackup.tmp_dir, File.basename(key))
    con_backup do
      db_var = ENV["RESTORE_DATABASE_URL"].to_s.strip.empty? ? "DATABASE_URL" : "RESTORE_DATABASE_URL"
      db     = ClubBackup.database_url(db_var)

      puts "⏳ descargando #{key}…"
      ClubBackup.client.get_object(response_target: file, bucket: ClubBackup.bucket, key: key)
      abort "✗ No se pudo descargar el backup." unless File.exist?(file) && File.size(file).positive?
      puts "✓ Descargado (#{ClubBackup.mb(File.size(file))} MB)"

      puts "⚠  Se va a RESTAURAR sobre #{ClubBackup.redact(db)}"
      puts "⚠  Esto PISA los datos actuales de esa base (--clean --if-exists)."
      ok = system("pg_restore", "--clean", "--if-exists", "--no-owner", "--no-privileges",
                  "--dbname=#{db}", file)
      # pg_restore puede devolver != 0 por warnings de objetos inexistentes al hacer --clean.
      if ok
        puts "✓ Restore completo."
      else
        puts "⚠  pg_restore terminó con warnings/errores. Revisá el log de arriba: si son sólo"
        puts "   'does not exist, skipping' del --clean, el restore igual se aplicó."
      end
    end
  ensure
    File.delete(file) if defined?(file) && file && File.exist?(file)
  end

  # EL CHEQUEO BARATO DE TODOS LOS DÍAS: baja el último dump y lee su índice (`pg_restore --list`,
  # sin ninguna base) para ver que tenga datos de las tablas clave. Deja el resultado en el bucket
  # (`verificaciones/ultima.json`) y el panel de plataforma lo muestra. Sale con error si el dump
  # no sirve, así el cron de Render queda en rojo y avisa.
  #
  # No reemplaza a restaurarlo de verdad en preproducción una vez por mes (docs/INFRA.md).
  desc "Verifica que el último backup se pueda leer y tenga las tablas clave. Cron diario, después del backup."
  task :verificar do
    con_backup do
      cli    = ClubBackup.client
      ultimo = ClubBackup.all_objects(cli).max_by(&:last_modified)
      abort "✗ No hay ningún backup en s3://#{ClubBackup.bucket}/#{ClubBackup::PREFIX}" if ultimo.nil?

      file = File.join(ClubBackup.tmp_dir, File.basename(ultimo.key))
      begin
        puts "⏳ descargando #{ultimo.key} (#{ClubBackup.mb(ultimo.size)} MB)…"
        cli.get_object(response_target: file, bucket: ClubBackup.bucket, key: ultimo.key)
        listado = IO.popen(["pg_restore", "--list", file], err: [:child, :out], &:read)
        ok_cmd  = $?.success?
        v = ClubBackup.veredicto(ClubBackup.tablas_con_datos(listado))
        v[:ok] &&= ok_cmd
        resultado = v.merge(key: ultimo.key, tamano_mb: ClubBackup.mb(ultimo.size),
                            verificado_at: Time.now.utc.iso8601)
        ClubBackup.guardar_verificacion(cli, resultado)

        if resultado[:ok]
          puts "✓ El backup se lee y trae datos de #{resultado[:tablas]} tablas, incluidas las clave."
        else
          puts listado.to_s.lines.first(5).join unless ok_cmd
          abort "✗ El backup NO pasa la verificación: #{ok_cmd ? "faltan #{v[:faltan].join(', ')}" : 'pg_restore no lo pudo leer'}."
        end
      ensure
        File.delete(file) if File.exist?(file)
      end
    end
  end
end
