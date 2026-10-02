require Rails.root.join('lib/club_backup').to_s

# Cuándo fue el último backup que llegó al bucket, y si se verificó. Lo miran el panel de
# plataforma (Pulso y Estado) y el monitor externo (`GET /salud/backup`): los backups existen
# (`rake backup:create`, un cron de Render), pero que CORRAN sólo se sabía entrando al bucket a
# mano — y un cron que se rompe no avisa.
#
# El bucket se lee con `ClubBackup` (las mismas variables que el cron), con timeout corto y
# cacheado: el panel no puede quedarse colgado del bucket, y un backup es diario.
#
# Sin credenciales o sin bucket devuelve `disponible: false` con el motivo: en desarrollo no
# hay nada configurado y eso es un dato, no un error del panel.
module Backups
  class Ultimo
    CACHE = 'plataforma/ultimo_backup'.freeze
    TTL   = 15.minutes
    # Corre una vez por día (04:00 ART). Pasadas 26 horas, el de hoy no corrió: hay que mirarlo.
    # Pasadas 48, son dos días seguidos sin backup: está roto.
    HORAS_ATENCION = 26
    HORAS_ATRASADO = 48
    CUANTOS = 7

    def self.call = new.call

    def call
      Rails.cache.fetch(CACHE, expires_in: TTL) { consultar }
    rescue StandardError => e
      Rails.logger.warn("[backups] #{e.class} #{e.message}")
      { disponible: false, estado: 'desconocido', motivo: 'No se pudo consultar el bucket.' }
    end

    private

    def consultar
      return { disponible: false, estado: 'desconocido', motivo: 'Sin bucket de backups configurado.' } unless ClubBackup.configurado?

      cli     = ClubBackup.client(rapido: true)
      objetos = ClubBackup.all_objects(cli).sort_by(&:last_modified).reverse
      ultimo  = objetos.first
      base = { disponible: true, bucket_compartido: ClubBackup.bucket_compartido?, total: objetos.size,
               retencion_dias: ClubBackup::RETENTION_DAYS }
      if ultimo.nil?
        return base.merge(ultimo: nil, atrasado: true, estado: 'mal', motivo: 'El bucket está vacío: nunca corrió un backup.')
      end

      horas = ((Time.current - ultimo.last_modified) / 3600).round(1)
      base.merge(
        ultimo:      ultimo.last_modified,
        horas_desde: horas,
        tamano_mb:   ClubBackup.mb(ultimo.size),
        atrasado:    horas > HORAS_ATRASADO,
        estado:      horas > HORAS_ATRASADO ? 'mal' : horas > HORAS_ATENCION ? 'atencion' : 'ok',
        ultimos:     objetos.first(CUANTOS).map { |o| { fecha: o.last_modified, tamano_mb: ClubBackup.mb(o.size) } },
        verificacion: ClubBackup.leer_verificacion(cli),
      )
    rescue ClubBackup::Error => e
      { disponible: false, estado: 'desconocido', motivo: e.message }
    end
  end
end
