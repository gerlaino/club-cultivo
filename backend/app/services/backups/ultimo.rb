# Cuándo fue el último backup que llegó al bucket. Lo mira el panel de plataforma en Salud:
# los backups existen (`rake backup:create`, un cron de Render), pero que CORRAN sólo se sabía
# entrando al bucket a mano — y un cron que se rompe no avisa. Se lista el bucket con las
# mismas variables que usa el rake, con timeout corto y cacheado UNA HORA: el panel no puede
# quedarse colgado de R2, y un backup es diario.
#
# Sin credenciales o sin bucket devuelve `disponible: false` con el motivo: en desarrollo no
# hay nada configurado y eso es un dato, no un error del panel.
module Backups
  class Ultimo
    PREFIX  = 'postgres/'.freeze
    CACHE   = 'plataforma/ultimo_backup'.freeze
    TTL     = 1.hour
    # Un backup diario que no aparece en dos días está roto, no atrasado.
    HORAS_ATRASADO = 48

    def self.call = new.call

    def call
      Rails.cache.fetch(CACHE, expires_in: TTL) { consultar }
    rescue StandardError => e
      Rails.logger.warn("[backups] #{e.class} #{e.message}")
      { disponible: false, motivo: 'No se pudo consultar el bucket.' }
    end

    private

    def consultar
      bucket = env_first('BACKUP_BUCKET', 'S3_BUCKET', 'AWS_BUCKET')
      key    = env_first('BACKUP_S3_ACCESS_KEY_ID', 'S3_ACCESS_KEY_ID', 'AWS_ACCESS_KEY_ID')
      secret = env_first('BACKUP_S3_SECRET_ACCESS_KEY', 'S3_SECRET_ACCESS_KEY', 'AWS_SECRET_ACCESS_KEY')
      return { disponible: false, motivo: 'Sin bucket de backups configurado.' } if bucket.blank? || key.blank? || secret.blank?

      require 'aws-sdk-s3'
      endpoint = ENV['S3_ENDPOINT'].to_s.strip
      opts = {
        access_key_id: key, secret_access_key: secret,
        region: env_first('BACKUP_S3_REGION', 'S3_REGION', 'AWS_REGION').presence || 'auto',
        request_checksum_calculation: 'when_required', response_checksum_validation: 'when_required',
        http_open_timeout: 3, http_read_timeout: 5, retry_limit: 0,
      }
      opts.merge!(endpoint: endpoint, force_path_style: true) if endpoint.present?

      objetos = Aws::S3::Client.new(opts).list_objects_v2(bucket: bucket, prefix: PREFIX).contents.to_a
      ultimo  = objetos.max_by(&:last_modified)
      return { disponible: true, ultimo: nil, atrasado: true, motivo: 'El bucket está vacío: nunca corrió un backup.' } if ultimo.nil?

      {
        disponible: true,
        ultimo:     ultimo.last_modified,
        tamano_mb:  (ultimo.size.to_f / 1024 / 1024).round(1),
        atrasado:   ultimo.last_modified < HORAS_ATRASADO.hours.ago,
      }
    end

    def env_first(*keys)
      keys.each { |k| v = ENV[k].to_s.strip; return v unless v.empty? }
      ''
    end
  end
end
