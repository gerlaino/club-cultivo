# CÓMO CRECIÓ UNA PLANTA: todas sus fotos en orden, para verlas pasar una tras otra (11-oct-2026).
#
# Las fotos de una planta viven en dos lados, por historia: las que se sacan desde su ficha
# (`Plant#fotos`, Active Storage) y las de la galería del lote que dicen de qué planta son
# (`LoteFoto#plant_id`). Acá se juntan. Las fotos del lote que no nombran planta («todas») se
# suman marcadas: en una carpa con dos o tres plantas, muchas veces la foto es del conjunto.
#
# Cada foto lleva el día de vida (desde el inicio del lote) y la fase de ese día: es lo que se
# lee debajo mientras pasan.
module Plantas
  class LineaDeFotos
    def initialize(plant, url_para:)
      @plant = plant
      @lote  = plant.lote
      @url   = url_para
    end

    def call
      (de_la_ficha + de_la_galeria).sort_by { |f| [f[:fecha], f[:orden]] }.map { |f| f.except(:orden) }
    end

    private

    def de_la_ficha
      @plant.fotos.blobs.map do |b|
        fecha = b.created_at.in_time_zone.to_date
        foto(b.id, @url.call(b), fecha, b.created_at.to_i, de_todas: false, nota: b.metadata['descripcion'])
      end
    end

    def de_la_galeria
      return [] unless @lote
      LoteFoto.where(lote_id: @lote.id).where(plant_id: [@plant.id, nil]).with_attached_imagen.map do |f|
        next unless f.imagen.attached?
        foto("g#{f.id}", @url.call(f.imagen), f.tomada_el, f.created_at.to_i, de_todas: f.plant_id.nil?, nota: f.nota, fase: f.fase)
      end.compact
    end

    def foto(id, url, fecha, orden, de_todas:, nota: nil, fase: nil)
      fase ||= @lote&.estado_en(fecha)
      {
        id: id, url: url, fecha: fecha, orden: orden, de_todas: de_todas, nota: nota.presence,
        dia: @lote&.start_date ? (fecha - @lote.start_date).to_i + 1 : nil,
        fase: fase, fase_label: fase && Lote.etiqueta_estado(fase, @lote&.origen),
      }
    end
  end
end
