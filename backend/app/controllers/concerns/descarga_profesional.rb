# TODA DESCARGA ES UN INFORME (Germán, 9-oct-2026, al abrir el CSV de un plan: «ningún archivo
# descargado puede ser así, ninguno»). Un listado se baja en Excel —para trabajar los números:
# tipos reales, totales, filtros— o en PDF —para leerlo o presentarlo—, los dos con el membrete de
# la organización (`XlsxExport`, `InformeDocument`). No hay más CSV: era un archivo crudo, con
# separadores que Excel en castellano no siempre entendía y textos partidos en celdas.
#
#   responder_descarga(
#     titulo: 'Pacientes', nombre: 'pacientes',
#     headers: ['Nombre', 'Alta', 'Saldo'], rows: [['Ana', Date.today, 1500.0]],
#     formatos: [:texto, :fecha, :moneda], totales: [2],
#     kpis: [{ label: 'Pacientes', valor: 1 }], periodo: 'Octubre 2026',
#   )
#
# `columnas_pdf`: qué columnas (índices) van en el PDF, cuando el Excel lleva más de las que se
# leen en una hoja (el mail de cada paciente sirve para trabajar, no para leer).
#
# `antes`: secciones del PDF que van antes de la tabla (un resumen por categoría), con la forma de
# las de `InformeDocument`. El Excel lleva la tabla y el resumen de arriba.
#
# `formatos` dice el tipo de cada columna (:texto, :fecha, :moneda, :numero): el Excel lo usa para
# el formato de celda y el PDF para escribirlo como se lee en Argentina.
module DescargaProfesional
  extend ActiveSupport::Concern

  XLSX = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze

  private

  def responder_descarga(titulo:, nombre:, headers:, rows:, formatos: nil, totales: nil, kpis: nil,
                         periodo: nil, filtros: nil, nota: nil, vacio: nil, apaisado: nil,
                         titulo_tabla: nil, antes: [], columnas_pdf: nil, formato: params[:formato])
    archivo = "#{nombre}_#{Time.zone.today.strftime('%Y%m%d')}"
    if formato.to_s == 'pdf'
      formatos ||= []
      if columnas_pdf
        totales  = Array(totales).filter_map { |i| columnas_pdf.index(i) }
        headers  = columnas_pdf.map { |i| headers[i] }
        formatos = columnas_pdf.map { |i| formatos[i] }
        rows     = rows.map { |r| columnas_pdf.map { |i| r[i] } }
      end
      seccion = {
        titulo: titulo_tabla, headers: headers, rows: rows.map { |r| r.each_with_index.map { |v, i| celda_pdf(v, formatos[i]) } },
        aligns: formatos.each_with_index.to_h { |f, i| [i, %i[moneda numero].include?(f) ? :right : :left] },
        anchos: :contenido, vacio: vacio || 'No hay nada para mostrar con lo elegido.',
      }
      if Array(totales).any? && rows.any?
        seccion[:rows] << fila_total_pdf(headers, rows, formatos, totales)
        seccion[:fila_total] = true
      end
      antes = antes.map { |a| { anchos: :contenido }.merge(a) }
      pdf = InformeDocument.new(club: current_user.club, usuario: current_user, titulo: titulo,
                                kpis: kpis, periodo: periodo, filtros: filtros, nota: nota,
                                secciones: antes + [seccion], apaisado: apaisado.nil? ? headers.size > 6 : apaisado).render
      send_data pdf, filename: "#{archivo}.pdf", type: 'application/pdf', disposition: 'attachment'
    else
      xlsx = XlsxExport.new(club: current_user.club, titulo: titulo,
                            subtitulo: [periodo, ("Filtrado — #{filtros}" if filtros.present?)].compact.join(' · ').presence,
                            headers: headers, rows: rows, formatos: formatos, totales: totales,
                            resumen: kpis.presence&.to_h { |k| [k[:label], k[:valor]] }).render
      send_data xlsx, filename: "#{archivo}.xlsx", type: XLSX, disposition: 'attachment'
    end
  end

  def celda_pdf(valor, formato)
    return '—' if valor.nil? || valor == ''

    case formato
    when :moneda then pesos_ar(valor, 2)
    when :numero then numero_ar(valor, valor.to_f == valor.to_i ? 0 : 1)
    when :fecha  then valor.respond_to?(:strftime) ? valor.strftime('%d/%m/%Y') : valor.to_s
    else
      valor.respond_to?(:strftime) ? valor.strftime('%d/%m/%Y') : valor.to_s
    end
  end

  # «-$ 16.500», no «$ -16.500».
  def pesos_ar(valor, decimales = 0)
    "#{'-' if valor.to_f.negative?}$ #{numero_ar(valor.to_f.abs, decimales)}"
  end

  def numero_ar(valor, decimales)
    ActiveSupport::NumberHelper.number_to_rounded(valor.to_f, precision: decimales, delimiter: '.', separator: ',')
  end

  def fila_total_pdf(headers, rows, formatos, totales)
    fila = Array.new(headers.size, '')
    fila[0] = "Total (#{rows.size} #{rows.size == 1 ? 'fila' : 'filas'})"
    Array(totales).each { |i| fila[i] = celda_pdf(rows.sum { |r| r[i].to_f }, formatos[i] || :numero) }
    fila
  end
end
