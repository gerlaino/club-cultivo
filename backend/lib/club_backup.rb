# frozen_string_literal: true

# DÓNDE VIVEN LOS BACKUPS Y CÓMO SE LLEGA A ELLOS — en UN solo lugar.
#
# Lo usan dos lados que no pueden compartir otra cosa:
#   · `lib/tasks/backup.rake` (el cron de Render): corre SIN bootear la app —no tiene las claves de
#     cifrado ni las necesita— así que esto es Ruby plano, sin Rails.
#   · el panel de plataforma (`Backups::Ultimo`, `Infra::Backups`), que lee el bucket para decir
#     cuándo fue el último backup y si se verificó.
#
# Estaba escrito dos veces y ya se habían separado: el panel caía a la región `auto` (que es de R2 y
# AWS no entiende) donde el rake decía qué faltaba. La misma regla en dos lados es de donde salen
# esas diferencias.
#
# Nunca `abort`: esto corre también adentro del servidor web, y un `abort` ahí mata el proceso.
# Los errores son `ClubBackup::Error`; el rake los convierte en `abort` con el mismo mensaje.
require "time"
require "json"
require "fileutils"

module ClubBackup
  class Error < StandardError; end

  PREFIX         = "postgres/"
  # El resultado de la última verificación (`rake backup:verificar`). Fuera de `postgres/` para
  # que no lo cuente la retención ni el listado de dumps.
  VERIFICACION   = "verificaciones/ultima.json"
  RETENTION_DAYS = 30

  # Un dump sano tiene adentro las tablas sin las que la app no existe. Si falta alguna, el archivo
  # está cortado o es de otra base: que exista no alcanza.
  TABLAS_CLAVE = %w[clubs users pacientes dispensaciones stocks lotes].freeze

  module_function

  # Un bucket dedicado es lo ideal —así una filtración del backup no da acceso a los documentos
  # clínicos ni al revés— pero si no hay, se usa el de la app: los dumps van bajo `postgres/`.
  def bucket
    v = env_first_opcional("BACKUP_BUCKET", "S3_BUCKET", "AWS_BUCKET")
    raise Error, "Falta BACKUP_BUCKET (o S3_BUCKET): el nombre del bucket donde guardar los dumps." if v.empty?

    v
  end

  # ¿Hay con qué llegar al bucket? Para el panel: sin credenciales no es un error, es un dato.
  def configurado?
    !env_first_opcional("BACKUP_BUCKET", "S3_BUCKET", "AWS_BUCKET").empty? &&
      !env_first_opcional("BACKUP_S3_ACCESS_KEY_ID", "S3_ACCESS_KEY_ID", "AWS_ACCESS_KEY_ID").empty? &&
      !env_first_opcional("BACKUP_S3_SECRET_ACCESS_KEY", "S3_SECRET_ACCESS_KEY", "AWS_SECRET_ACCESS_KEY").empty?
  end

  # ¿El bucket de backups es el MISMO que el de la app? Para el panel: funciona, pero una
  # filtración de uno es una filtración del otro.
  def bucket_compartido?
    propio = ENV["BACKUP_BUCKET"].to_s.strip
    app    = env_first_opcional("S3_BUCKET", "AWS_BUCKET")
    propio.empty? || propio == app
  end

  # Connection string. `var` permite usar RESTORE_DATABASE_URL en el restore.
  def database_url(var = "DATABASE_URL")
    v = ENV[var].to_s.strip
    raise Error, "Falta la variable #{var} (connection string de Postgres)." if v.empty?

    v
  end

  # `rapido: true` es para el panel: no puede quedarse colgado esperando al bucket.
  def client(rapido: false)
    require "aws-sdk-s3"
    endpoint = ENV["S3_ENDPOINT"].to_s.strip
    opts = {
      # Credenciales dedicadas de backup si existen; si no, las mismas del app storage, con las
      # mismas alternativas que acepta `storage.yml`, incluidas las `AWS_*`.
      access_key_id:     env_first("BACKUP_S3_ACCESS_KEY_ID", "S3_ACCESS_KEY_ID", "AWS_ACCESS_KEY_ID"),
      secret_access_key: env_first("BACKUP_S3_SECRET_ACCESS_KEY", "S3_SECRET_ACCESS_KEY", "AWS_SECRET_ACCESS_KEY"),
      region:            region_para(endpoint),
      # R2: los checksums nuevos del SDK rompen la firma ("AuthorizationHeaderMalformed").
      request_checksum_calculation: "when_required",
      response_checksum_validation: "when_required",
    }
    opts.merge!(http_open_timeout: 3, http_read_timeout: 5, retry_limit: 0) if rapido
    opts.merge!(endpoint: endpoint, force_path_style: true) unless endpoint.empty?
    Aws::S3::Client.new(opts)
  end

  # `auto` es un valor de R2 y S3 no lo entiende: sólo vale cuando HAY endpoint (R2 o compatible).
  # Sin endpoint el destino es AWS S3 y hace falta una región real.
  def region_para(endpoint)
    v = env_first_opcional("BACKUP_S3_REGION", "S3_REGION", "AWS_REGION")
    return v unless v.empty?
    raise Error, "Falta la región del bucket (AWS_REGION o S3_REGION)." if endpoint.to_s.strip.empty?

    "auto"
  end

  def env_first(*keys)
    v = env_first_opcional(*keys)
    raise Error, "Falta alguna de estas variables: #{keys.join(' / ')}." if v.empty?

    v
  end

  def env_first_opcional(*keys)
    keys.each do |k|
      v = ENV[k].to_s.strip
      return v unless v.empty?
    end
    ""
  end

  def tmp_dir
    dir = File.expand_path("../tmp", __dir__) # → backend/tmp
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

  # ── Verificación ──────────────────────────────────────────────────────────
  #
  # Que el archivo exista no dice que sirva. Esto lee el índice del dump (`pg_restore --list`, que
  # no necesita ninguna base) y comprueba que tenga datos de las tablas clave. No reemplaza a
  # restaurarlo de verdad en preproducción una vez por mes: es el chequeo barato de todos los días.

  # El índice de `pg_restore --list` → qué tablas traen datos. Cada línea de datos es
  # «123; 0 16385 TABLE DATA public pacientes owner».
  def tablas_con_datos(listado)
    listado.to_s.each_line.filter_map do |l|
      m = l.match(/TABLE DATA\s+\S+\s+(\S+)/)
      m && m[1]
    end.uniq
  end

  def veredicto(tablas)
    faltan = TABLAS_CLAVE - tablas
    { ok: faltan.empty? && tablas.size >= TABLAS_CLAVE.size, tablas: tablas.size, faltan: faltan }
  end

  def guardar_verificacion(cli, resultado)
    cli.put_object(bucket: bucket, key: VERIFICACION, body: JSON.generate(resultado),
                   content_type: "application/json")
  end

  def leer_verificacion(cli)
    JSON.parse(cli.get_object(bucket: bucket, key: VERIFICACION).body.read)
  rescue Aws::S3::Errors::NoSuchKey
    nil
  end
end
