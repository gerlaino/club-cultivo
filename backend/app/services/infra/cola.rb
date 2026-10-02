# LOS TRABAJOS EN SEGUNDO PLANO: cuántos esperan, cuánto hace que espera el más viejo, cuántos
# fallaron, y si cada tarea programada (cron) corrió cuando tenía que correr.
#
# Vivía adentro del Pulso del super admin; ahora la leen también el panel de Estado. Un cron que
# no corre no avisa, y este es el único lugar donde se ve.
module Infra
  class Cola
    # Un trabajo que lleva más que esto esperando en la cola es un worker que no da abasto.
    ESPERA_ATENCION_SEG = 5.minutes.to_i

    def self.call = new.call

    def call
      { trabajos: trabajos, cron: cron }
    end

    def trabajos
      require 'sidekiq/api'
      stats  = Sidekiq::Stats.new
      espera = Sidekiq::Queue.all.map(&:latency).max.to_f.round
      muertos = Sidekiq::DeadSet.new.size
      {
        disponible: true,
        encolados:  stats.enqueued,
        espera_seg: espera,
        reintentos: stats.retry_size,
        fallidos:   stats.failed,
        muertos:    muertos,
        workers:    Sidekiq::ProcessSet.new.size,
        estado:     espera > ESPERA_ATENCION_SEG || muertos.positive? ? 'atencion' : 'ok',
      }
    rescue StandardError => e
      # Sin Redis el panel no puede reventar: que no haya cola es un dato, no un error de la página.
      Rails.logger.warn("[infra] Sidekiq no disponible: #{e.class} #{e.message}")
      { disponible: false, estado: 'mal', error: 'No se pudo consultar la cola de trabajos.' }
    end

    # Cada job programado con su última corrida. `atrasado` cuando pasó más del doble de su
    # período sin encolarse.
    def cron
      require 'sidekiq/cron/job'
      Sidekiq::Cron::Job.all.map do |j|
        ultima   = j.last_enqueue_time
        periodo  = self.class.periodo_de(j.cron)
        atrasado = periodo.present? && (ultima.nil? || ultima < Time.current - (periodo * 2))
        { nombre: j.name, cron: j.cron, descripcion: j.description, ultima: ultima, atrasado: atrasado }
      end.sort_by { |c| [c[:atrasado] ? 0 : 1, c[:nombre]] }
    rescue StandardError => e
      Rails.logger.warn("[infra] cron no disponible: #{e.class} #{e.message}")
      []
    end

    # Cuánto tarda en volver a correr, a partir del cron. Con lo justo para los que hay: por
    # minutos, por hora, por día, por semana. Lo anual (los informes semestrales) no se vigila.
    def self.periodo_de(cron)
      m, h, dom, mon, dow = cron.to_s.split
      return nil if mon != '*' || dom != '*'
      return 1.week if dow != '*'
      return 1.day  if h != '*'
      return 1.hour if m != '*' && !m.start_with?('*/')
      return m.delete_prefix('*/').to_i.minutes if m.start_with?('*/')

      nil
    end
  end
end
