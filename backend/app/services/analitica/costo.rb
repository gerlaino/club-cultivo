module Analitica
  # ¿CUÁNTO CUESTA PRODUCIR UN GRAMO? Sólo lotes cerrados con costo y rendimiento: el costo de un
  # lote abierto no se divide por gramos que todavía no existen (el viejo cálculo sumaba el costo
  # de TODOS los lotes con costo y lo dividía por los gramos de los cerrados). Por sede y por
  # genética. El detalle lote por lote sigue en Contabilidad → Ganancia por lote.
  class Costo
    def initialize(universo)
      @u = universo
    end

    def call
      con_costo = @u.lotes.select { |l| l.costo_lote && l.costo_lote.costo_total.to_f.positive? }
      {
        total:        agregado(con_costo).merge(lotes_sin_costo: @u.lotes.size - con_costo.size),
        por_sede:     con_costo.group_by { |l| @u.sede_de(l) }.map { |sede, ls| agregado(ls).merge(nombre: sede&.nombre || 'Sin sede') }
                               .sort_by { |f| f[:costo_por_gramo] || Float::INFINITY },
        por_genetica: con_costo.group_by(&:genetica).map { |g, ls| agregado(ls).merge(nombre: g&.nombre || 'Sin variedad', automatica: g&.automatica == true) }
                               .sort_by { |f| f[:costo_por_gramo] || Float::INFINITY },
      }
    end

    private

    def agregado(ls)
      costo  = ls.sum { |l| l.costo_lote.costo_total.to_f }
      gramos = ls.sum { |l| l.rendimiento_real_g.to_f }
      { lotes: ls.size, suficientes: @u.suficientes?(ls.size), costo_total: costo.round(2), gramos: gramos.round(1),
        costo_por_gramo: gramos.positive? ? (costo / gramos).round(2) : nil }
    end
  end
end
