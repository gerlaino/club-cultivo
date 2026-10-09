require 'zip'

# Leer lo que se descargó (`DescargaProfesional`): las filas de un Excel como texto, y si un PDF es
# un PDF. Así un spec afirma lo que dice el archivo, no sólo que respondió 200.
module DescargasHelper
  XLSX = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze

  # Cada fila de la primera hoja como un array de textos (los números como los guarda Excel).
  def filas_xlsx(body)
    filas = nil
    Zip::File.open_buffer(StringIO.new(body)) do |zip|
      compartidos = if (ss = zip.find_entry('xl/sharedStrings.xml'))
                      Nokogiri::XML(ss.get_input_stream.read).remove_namespaces!.xpath('//si').map { |si| si.xpath('.//t').map(&:text).join }
                    else
                      []
                    end
      hoja = Nokogiri::XML(zip.find_entry('xl/worksheets/sheet1.xml').get_input_stream.read).remove_namespaces!
      filas = hoja.xpath('//row').map do |row|
        row.xpath('c').map do |c|
          v = c.at_xpath('v')&.text || c.at_xpath('.//t')&.text
          c['t'] == 's' ? compartidos[v.to_i] : v.to_s
        end
      end
    end
    filas
  end

  def texto_xlsx(body) = filas_xlsx(body).flatten.join(' | ')

  def es_pdf?(body) = body.to_s.start_with?('%PDF')
end

RSpec.configure { |c| c.include DescargasHelper, type: :request }
