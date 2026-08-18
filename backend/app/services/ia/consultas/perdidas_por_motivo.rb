module Ia
  module Consultas
    # Qué se muere y por qué.
    #
    # Sale de `plants.motivo_descarte`, que ya se carga al descartar. Contesta dos cosas que un
    # admin no puede ver hoy sin hacer cuentas: cuánto se pierde en total, y si hay una genética o
    # una sala que pierde mucho más que el resto — que suele ser un problema estructural (una sala
    # con humedad, una genética delicada) y no mala suerte.
    class PerdidasPorMotivo < Base
      # Un porcentaje sobre cinco plantas es ruido: con dos descartes daría 40% y no significa
      # nada. Treinta es el piso para que el número se pueda mirar. Como todos los umbrales de
      # acá, es un piso elegido a mano y conviene calibrarlo con datos propios.
      MINIMO_PLANTAS = 30

      def resolver(**)
        total = club.plants.count
        return insuficiente(
          "hacen falta al menos #{MINIMO_PLANTAS} plantas registradas para que un porcentaje de " \
          "pérdidas signifique algo; hay #{total}"
        ) if total < MINIMO_PLANTAS

        descartadas = club.plants.descartadas
        perdidas    = descartadas.count

        suficiente(
          plantas_totales:  total,
          descartadas:      perdidas,
          porcentaje:       (perdidas * 100.0 / total).round(1),
          por_motivo:       agrupar(descartadas, :motivo_descarte),
          por_genetica:     por_genetica(descartadas, total),
          # Sin esto, "18% de pérdidas" no se puede juzgar: puede ser normal o un desastre según
          # de qué se trate. `no_prendio` en esquejes es esperable; `plaga` no.
          nota: 'Un descarte por "no prendió" en propagación es esperable; por plaga o enfermedad ' \
                'no. Mirá el desglose por motivo antes que el total.'
        )
      end

      private

      def agrupar(scope, campo)
        scope.group(campo).count
             .map { |valor, n| { motivo: valor || 'sin especificar', plantas: n } }
             .sort_by { |f| -f[:plantas] }
      end

      # Por genética, con su propio denominador: lo que importa no es cuántas se murieron sino
      # QUÉ PROPORCIÓN de las que se plantaron. Una genética con 50 descartes sobre 500 plantas
      # está mejor que otra con 20 sobre 40.
      def por_genetica(descartadas, _total)
        plantadas = club.plants.joins(lote: :genetica).group('geneticas.nombre').count
        muertas   = descartadas.joins(lote: :genetica).group('geneticas.nombre').count

        plantadas.filter_map do |nombre, n|
          next if n.zero?

          perdidas = muertas[nombre].to_i
          {
            genetica:   nombre,
            plantadas:  n,
            descartadas: perdidas,
            porcentaje: (perdidas * 100.0 / n).round(1),
          }
        end.sort_by { |f| -f[:porcentaje] }
      end
    end
  end
end
