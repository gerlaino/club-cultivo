# Una cama de suelo vivo, para la tarjeta (`resumen`) y para la ficha (`detalle`). El estado, el
# «qué viene», los m² y los litros los calcula el modelo: la pantalla sólo los muestra.
class CamaSerializer
  def self.resumen(c, hoy = Time.zone.today)
    ciclo = c.ciclo_actual
    en_cultivo = c.lotes_en_cultivo.includes(:genetica).to_a
    {
      id: c.id, nombre: c.nombre, sala_id: c.sala_id, sala_nombre: c.sala&.nombre, sala_kind: c.sala&.kind,
      estado: c.estado(hoy), estado_label: Cama::ESTADO_LABELS[c.estado(hoy)],
      largo_m: c.largo_m&.to_f, ancho_m: c.ancho_m&.to_f, profundidad_cm: c.profundidad_cm&.to_f,
      m2: c.m2&.to_f, litros_suelo: c.litros_suelo&.to_f,
      armada_el: c.armada_el, semanas_coccion: c.semanas_coccion, cocina_hasta: c.cocina_hasta,
      dias_descanso: c.dias_descanso, frecuencia_top_dress_dias: c.frecuencia_top_dress_dias,
      descansa_desde: c.descansa_desde, descansa_hasta: c.descansa_hasta, retirada_el: c.retirada_el,
      edad_dias: c.edad_dias(hoy),
      ciclos_count: c.ciclos.size,
      ciclo_actual: ciclo && { id: ciclo.id, numero: ciclo.numero, desde: ciclo.desde, dias: ciclo.dias(hoy) },
      proximo_paso: c.proximo_paso(hoy),
      ultimo_top_dress_el: c.ultimo_top_dress_el,
      # Lo que ocupan sus lotes: la pantalla precarga los m² libres al plantar otro.
      m2_ocupados_lotes: en_cultivo.sum { |l| l.m2_ocupados.to_f }.round(2),
      lotes: en_cultivo.map { |l|
        { id: l.id, codigo: l.codigo, estado: l.estado, genetica: l.genetica&.nombre,
          plants_count: l.plants_count, m2_ocupados: l.m2_ocupados&.to_f, automatica: l.automatica? }
      },
      notas: c.notas,
    }
  end

  # `con_costo`: la plata es de administración (misma regla que «Cómo salió» y la tarjeta P&L del
  # lote): un cultivador ve la cama, sus ciclos y lo que se le puso, sin pesos.
  def self.detalle(c, hoy = Time.zone.today, con_costo: true)
    resumen(c, hoy).merge(
      mezcla: con_costo ? c.mezcla : sin_plata(c.mezcla),
      con_costo: con_costo,
      invertido_ars: con_costo ? c.invertido_ars.to_f.round(2) : nil,
      gramos_cosechados: c.gramos_cosechados.to_f.round(1),
      costo_por_gramo: con_costo ? c.costo_por_gramo&.to_f : nil,
      # Cosecha tras cosecha de la misma cama: ¿el suelo mejora?
      ciclos: c.ciclos.includes(lotes: :genetica).map { |ci|
        { id: ci.id, numero: ci.numero, desde: ci.desde, hasta: ci.hasta, dias: ci.dias(hoy),
          gramos: ci.gramos.to_f.round(1), g_m2: ci.g_m2&.to_f,
          registros: ci.registros.count,
          costo_ars: con_costo ? ci.registros.sum { |r| r.costo_ars }.round(2) : nil,
          lotes: ci.lotes.map { |l|
            { id: l.id, codigo: l.codigo, estado: l.estado, genetica: l.genetica&.nombre,
              rendimiento_real_g: l.rendimiento_real_g&.to_f }
          } }
      }.reverse,
      analisis: c.analisis_suelo.map { |a| analisis(a) },
    )
  end

  def self.sin_plata(nutricion)
    return nutricion if nutricion.blank?
    n = nutricion.deep_dup
    n.delete('costo_ars')
    Array(n['items']).each { |i| i.delete('costo_ars') }
    n
  end

  def self.registro(r, con_costo: true)
    {
      id: r.id, tipo: r.tipo, tipo_label: CamaRegistro::TIPO_LABELS[r.tipo], registrado_en: r.registrado_en,
      recarga: r.recarga, detalle: r.detalle, cantidad: r.cantidad&.to_f, unidad: r.unidad,
      litros: r.litros&.to_f, agua: r.agua, humedad_suelo: r.humedad_suelo&.to_f,
      temperatura_suelo: r.temperatura_suelo&.to_f, observaciones: r.observaciones,
      nutricion: con_costo ? r.nutricion : sin_plata(r.nutricion), costo_ars: con_costo ? r.costo_ars : nil,
      ciclo_numero: r.cama_ciclo&.numero,
      usuario: r.user && { id: r.user.id, nombre: r.user.nombre_completo },
    }
  end

  def self.analisis(a)
    AnalisisSuelo::VALORES.to_h { |v| [v.to_sym, a[v]&.to_f] }.merge(
      id: a.id, fecha: a.fecha, laboratorio: a.laboratorio, notas: a.notas,
      archivo_url: a.archivo.attached? ? Rails.application.routes.url_helpers.rails_blob_path(a.archivo, only_path: true) : nil,
    )
  end
end
