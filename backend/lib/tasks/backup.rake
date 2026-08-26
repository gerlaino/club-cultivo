# frozen_string_literal: true

# ─────────────────────────────────────────────────────────────────────────────
# Backups de PostgreSQL → Cloudflare R2 (S3-compatible).
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
#   rake 'backup:restore[<key>]'          # restaura un backup (emergencia)
# ─────────────────────────────────────────────────────────────────────────────

require "time"
require "fileutils"

module ClubBackup
  PREFIX         = "postgres/"
  RETENTION_DAYS = 30

  module_function

  # Un bucket dedicado es lo ideal —así una filtración del backup no da acceso a los documentos
  # clínicos ni al revés— pero si no hay, se usa el de la app: los dumps van bajo el prefijo
  # `postgres/` y quedan separados de los archivos. Mejor un backup mezclado que ningún backup.
  def bucket
    v = ENV["BACKUP_BUCKET"].to_s.strip
    v = ENV["S3_BUCKET"].to_s.strip if v.empty?
    v = ENV["AWS_BUCKET"].to_s.strip if v.empty?
    abort "✗ Falta BACKUP_BUCKET (o S3_BUCKET): el nombre del bucket donde guardar los dumps." if v.empty?
    v
  end

  # Connection string. `var` permite usar RESTORE_DATABASE_URL en el restore.
  def database_url(var = "DATABASE_URL")
    v = ENV[var].to_s.strip
    abort "✗ Falta la variable #{var} (connection string de Postgres)." if v.empty?
    v
  end

  # Primera de varias ENV que exista; aborta si ninguna está seteada.
  def env_first(*keys)
    keys.each do |k|
      v = ENV[k].to_s.strip
      return v unless v.empty?
    end
    abort "✗ Falta alguna de estas variables: #{keys.join(' / ')}."
  end

  def client
    require "aws-sdk-s3"
    endpoint = ENV["S3_ENDPOINT"].to_s.strip
    opts = {
      # Credenciales dedicadas de backup si existen; si no, las mismas del app storage.
      # Las mismas alternativas que acepta `storage.yml`, incluidas las `AWS_*`.
      #
      # La app cae en `AWS_ACCESS_KEY_ID` cuando no hay `S3_ACCESS_KEY_ID`, y el backup no: con
      # producción configurada así, las fotos subían y el backup abortaba diciendo que faltaba una
      # variable que sí estaba, con otro nombre. La misma regla escrita en dos lados con distinto
      # alcance, que es de donde salen estas diferencias.
      access_key_id:     env_first("BACKUP_S3_ACCESS_KEY_ID", "S3_ACCESS_KEY_ID", "AWS_ACCESS_KEY_ID"),
      secret_access_key: env_first("BACKUP_S3_SECRET_ACCESS_KEY", "S3_SECRET_ACCESS_KEY", "AWS_SECRET_ACCESS_KEY"),
      # `auto` es un valor de R2 y S3 no lo entiende. Sólo se usa como default cuando HAY endpoint
      # —o sea, cuando el destino es R2 o compatible—; sin endpoint el destino es AWS S3 de verdad
      # y hace falta una región real, que sale de las mismas variables que usa la app.
      #
      # La app lee `AWS_REGION` y esto leía sólo `S3_REGION`: producción está configurada con las
      # `AWS_*`, así que el cron tenía puesta una `S3_REGION` que no servía para nada.
      region:            region_para(endpoint),
      # R2: los checksums nuevos del SDK rompen la firma ("AuthorizationHeaderMalformed").
      request_checksum_calculation: "when_required",
      response_checksum_validation: "when_required",
    }
    unless endpoint.empty?
      opts[:endpoint]         = endpoint
      opts[:force_path_style] = true
    end
    Aws::S3::Client.new(opts)
  end

  def region_para(endpoint)
    v = env_first_opcional("BACKUP_S3_REGION", "S3_REGION", "AWS_REGION")
    return v unless v.empty?
    # Sin endpoint el destino es AWS S3: adivinar la región da un error críptico de firma, así
    # que mejor decir qué falta.
    abort "✗ Falta la región del bucket (AWS_REGION o S3_REGION)." if endpoint.to_s.strip.empty?
    "auto"
  end

  def env_first_opcional(*keys)
    keys.each do |k|
      v = ENV[k].to_s.strip
      return v unless v.empty?
    end
    ""
  end

  def tmp_dir
    dir = File.expand_path("../../tmp", __dir__) # → backend/tmp
    FileUtils.mkdir_p(dir)
    dir
  end

  def mb(bytes) = (bytes.to_f / 1024 / 1024).round(1)

  # Oculta la password del connection string en los logs.
  def redact(url) = url.to_s.sub(%r{://([^:@/]+):[^@/]+@}, '://\1:****@')

  def all_objects(cli)
    objs  = []
    token = nil
    loop do
      resp = cli.list_objects_v2(bucket: bucket, prefix: PREFIX, continuation_token: token)
      objs.concat(Array(resp.contents))
      token = resp.next_continuation_token
      break unless resp.is_truncated
    end
    objs
  end

  def prune(cli)
    cutoff = Time.now.utc - RETENTION_DAYS * 86_400
    viejos = all_objects(cli).select { |o| o.last_modified < cutoff }
    viejos.each do |o|
      cli.delete_object(bucket: bucket, key: o.key)
      puts "🗑  retención: borrado #{o.key}"
    end
    puts "Retención: #{viejos.size} backup(s) de más de #{RETENTION_DAYS} días eliminados."
  end
end

namespace :backup do
  desc "pg_dump (formato custom, comprimido) + subida a R2 + retención 30d. Cron diario."
  task :create do
    ts   = Time.now.utc.strftime("%Y-%m-%d_%H%M%S")
    key  = "#{ClubBackup::PREFIX}club_cultivo_#{ts}.dump"
    file = File.join(ClubBackup.tmp_dir, "club_cultivo_#{ts}.dump")

    puts "⏳ pg_dump → #{file}"
    ok = system("pg_dump", "--format=custom", "--no-owner", "--no-privileges",
                "--file=#{file}", ClubBackup.database_url)
    abort "✗ pg_dump falló (revisá pg_dump/DATABASE_URL)." unless ok && File.exist?(file) && File.size(file).positive?

    cli = ClubBackup.client
    puts "⏳ subiendo a s3://#{ClubBackup.bucket}/#{key} (#{ClubBackup.mb(File.size(file))} MB)…"
    File.open(file, "rb") { |f| cli.put_object(bucket: ClubBackup.bucket, key: key, body: f) }
    puts "✓ Backup subido: #{key}"

    ClubBackup.prune(cli)
  ensure
    File.delete(file) if defined?(file) && file && File.exist?(file)
  end

  desc "Borra del bucket los backups de más de 30 días."
  task :prune do
    ClubBackup.prune(ClubBackup.client)
  end

  desc "Lista los backups disponibles en el bucket (el más nuevo, último)."
  task :list do
    objs = ClubBackup.all_objects(ClubBackup.client).sort_by(&:last_modified)
    objs.each do |o|
      puts "#{o.last_modified.utc.strftime('%Y-%m-%d %H:%M')} UTC  #{format('%8.1f', ClubBackup.mb(o.size))} MB  #{o.key}"
    end
    puts "(#{objs.size} backup(s) en s3://#{ClubBackup.bucket}/#{ClubBackup::PREFIX})"
  end

  desc "Restaura un backup del bucket. Uso: rake 'backup:restore[postgres/club_cultivo_YYYY-MM-DD_HHMMSS.dump]'"
  task :restore, [:key] do |_t, args|
    key = args[:key].to_s.strip
    abort "✗ Pasá la key del backup. Listalas con: bundle exec rake backup:list" if key.empty?

    db_var = ENV["RESTORE_DATABASE_URL"].to_s.strip.empty? ? "DATABASE_URL" : "RESTORE_DATABASE_URL"
    db     = ClubBackup.database_url(db_var)
    file   = File.join(ClubBackup.tmp_dir, File.basename(key))

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
  ensure
    File.delete(file) if defined?(file) && file && File.exist?(file)
  end
end
