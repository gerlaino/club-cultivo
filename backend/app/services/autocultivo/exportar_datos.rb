require 'zip'

# «EXPORTAR MIS DATOS» del autocultivo (11-oct-2026): todo lo que la persona cargó, en un ZIP que
# se lleva. Es tranquilidad para quien cultiva en casa —sus datos son suyos— y, siendo datos de
# salud, también la forma concreta de cumplir el derecho de acceso.
#
# Adentro:
#   informes/  — Mi cosecha, De dónde salió y Mis gastos de TODO el historial, en PDF y Excel: los
#                mismos que se bajan de «Mis informes» (`Informes::AutocultivoDocumentos`).
#   mis_plantas.xlsx — cada planta, con su genética, espacio, fase y fechas.
#   diario.xlsx      — cada registro (riego, ambiente, notas) con lo que se anotó.
#   fotos/<genética>/ — las fotos, con la fecha en el nombre.
#   LEEME.txt
#
# Se arma en segundo plano (`ExportarDatosJob`): con cientos de fotos no entra en un request.
module Autocultivo
  class ExportarDatos
    def initialize(club:, usuario:)
      @club, @usuario = club, usuario
    end

    # Devuelve la ruta de un archivo temporal con el ZIP; quien llama lo sube y lo borra.
    def call
      archivo = Tempfile.new(['mis-datos', '.zip'], binmode: true)
      archivo.close
      ActsAsTenant.with_tenant(@club) do
        Zip::OutputStream.open(archivo.path) do |zip|
          agregar(zip, 'LEEME.txt', leeme)
          informes(zip)
          agregar(zip, 'mis_plantas.xlsx', plantas_xlsx)
          agregar(zip, 'diario.xlsx', diario_xlsx)
          fotos(zip)
        end
      end
      archivo.path
    end

    private

    def agregar(zip, nombre, contenido)
      zip.put_next_entry(nombre)
      zip.write(contenido)
    end

    def desde = @club.created_at.to_date
    def hasta = Time.zone.today
    def periodo = "#{desde.strftime('%d/%m/%Y')} — #{hasta.strftime('%d/%m/%Y')}"

    def informes(zip)
      docs = Informes::AutocultivoDocumentos.new(club: @club, desde: desde, hasta: hasta)
      Informes::AutocultivoDocumentos::TIPOS.each do |tipo|
        d = docs.para(tipo)
        pdf = InformeDocument.new(club: @club, usuario: @usuario, titulo: d[:titulo], kpis: d[:kpis],
                                  secciones: d[:secciones], periodo: periodo).render
        agregar(zip, "informes/#{d[:nombre]}.pdf", pdf)
        principal = d[:secciones].first
        xlsx = XlsxExport.new(club: @club, titulo: d[:titulo], subtitulo: periodo, headers: principal[:headers],
                              rows: principal[:rows], formatos: principal[:formatos],
                              resumen: d[:kpis].to_h { |k| [k[:label], k[:valor]] }).render
        agregar(zip, "informes/#{d[:nombre]}.xlsx", xlsx)
      end
    end

    def fecha(f) = f ? f.strftime('%d/%m/%Y') : ''

    def plantas_xlsx
      plantas = Plant.joins(:lote).where(lotes: { club_id: @club.id }).includes(lote: [:genetica, :sala]).order(:created_at)
      rows = plantas.map do |p|
        l = p.lote
        [p.nombre, l.genetica&.nombre, l.sala&.nombre, Lote.etiqueta_estado(p.state, l.origen) || p.state,
         fecha(l.start_date), fecha(p.fecha_vegetativo), fecha(p.fecha_floracion), fecha(p.fecha_cosecha),
         p.peso_seco&.to_f, p.notas]
      end
      XlsxExport.new(club: @club, titulo: 'Mis plantas', subtitulo: "Al #{fecha(hasta)}",
                     headers: ['Planta', 'Genética', 'Espacio', 'Estado', 'Inicio', 'Vegetativo', 'Floración', 'Cosecha', 'Seco (g)', 'Notas'],
                     rows: rows).render
    end

    def diario_xlsx
      regs = RegistroAmbiental.where(club_id: @club.id).includes(lote: :genetica).order(:registrado_en)
      rows = regs.map do |r|
        [r.registrado_en.in_time_zone.strftime('%d/%m/%Y %H:%M'), r.lote&.genetica&.nombre,
         r.volumen_l&.to_f || r.litros&.to_f, r.ph&.to_f, r.ec&.to_f, r.temperatura&.to_f, r.humedad&.to_f,
         [r.notas_fertilizacion, r.notas_nutricion, r.observaciones].reject(&:blank?).join(' · ')]
      end
      XlsxExport.new(club: @club, titulo: 'Diario', subtitulo: periodo,
                     headers: ['Fecha', 'Plantas', 'Agua (L)', 'pH', 'EC', 'Temp. (°C)', 'Humedad (%)', 'Notas'],
                     rows: rows).render
    end

    def fotos(zip)
      usados = Hash.new(0)
      LoteFoto.where(club_id: @club.id).includes(lote: :genetica, imagen_attachment: :blob).find_each do |f|
        next unless f.imagen.attached?
        foto(zip, usados, f.lote&.genetica&.nombre, f.tomada_el, f.imagen.blob)
      end
      Plant.joins(:lote).where(lotes: { club_id: @club.id }).includes(lote: :genetica).find_each do |p|
        p.fotos.blobs.each { |b| foto(zip, usados, p.lote.genetica&.nombre, b.created_at.to_date, b) }
      end
    end

    def foto(zip, usados, genetica, dia, blob)
      carpeta = (genetica.presence || 'sin_genetica').parameterize(separator: '_')
      base = "fotos/#{carpeta}/#{dia.strftime('%Y-%m-%d')}"
      ext = File.extname(blob.filename.to_s).presence || '.jpg'
      usados[base] += 1
      agregar(zip, "#{base}-#{usados[base]}#{ext}", blob.download)
    rescue ActiveStorage::FileNotFoundError
      nil # una foto que se perdió del almacenamiento no frena el resto
    end

    def leeme
      <<~TXT
        Tus datos de Cultivo Espacial — #{@club.name}
        Exportado el #{Time.zone.now.strftime('%d/%m/%Y %H:%M')}.

        informes/          Mi cosecha, De dónde salió y Mis gastos de todo tu historial (PDF y Excel).
        mis_plantas.xlsx   Cada planta con su genética, espacio, estado y fechas.
        diario.xlsx        Cada registro: riegos, pH, EC, ambiente y notas.
        fotos/             Tus fotos, por genética y con la fecha en el nombre.

        Estos datos son tuyos. Este archivo no se guarda en ningún lado: se borra de nuestros
        servidores 48 horas después de armarlo.
      TXT
    end
  end
end
