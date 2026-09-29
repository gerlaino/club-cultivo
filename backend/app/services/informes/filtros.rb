module Informes
  # LOS FILTROS DE UN INFORME: el admin arma el informe que necesita en el momento —estos lotes,
  # estos pacientes, sólo el stock externo— sin que haya un informe por cada combinación (Germán,
  # 29-sep-2026). Todos los informes los leen del mismo lado y la descarga manda los mismos
  # parámetros que la pantalla.
  #
  # Tres reglas:
  #   · Un filtro que no vino es «todos». Un filtro que vino con ids ajenos (de otra organización, o
  #     inventados) NO se ignora: queda vacío y el informe sale vacío. Ignorarlo mostraría toda la
  #     organización cuando se pidió otra cosa.
  #   · Un informe filtrado lo dice: `descripcion` va en la pantalla, en el PDF y en el Excel. Un
  #     PDF de tres lotes que no lo dice se lee como el total de la organización.
  #   · Cada informe aplica los filtros que le corresponden; la pantalla sólo ofrece esos.
  class Filtros
    ORIGENES = %w[todo propio externo].freeze
    # «Externo» es el stock `compra_externa`: la app lo llama así en todos lados («Nuevo stock externo»).
    ORIGEN_LABEL = { 'propio' => 'sólo stock propio', 'externo' => 'sólo stock externo' }.freeze
    # Del informe de stock: sólo lo que tiene saldo hoy, o sólo lo agotado.
    SALDOS = { 'con_saldo' => 'sólo con saldo', 'agotados' => 'sólo agotados' }.freeze
    # Hasta cuántos nombres se listan en la descripción; con más, se dice cuántos.
    NOMBRES_MAX = 4

    attr_reader :lote_ids, :paciente_ids, :genetica_ids, :sede_ids, :dispensador_ids, :formas, :origen, :saldo

    def self.desde_params(params, club)
      lista = ->(k) { params.key?(k) ? Array(params[k]).map(&:to_s).reject(&:blank?) : nil }
      new(club: club,
          lote_ids: lista.call(:lote_ids), paciente_ids: lista.call(:paciente_ids),
          genetica_ids: lista.call(:genetica_ids), sede_ids: lista.call(:sede_ids),
          dispensador_ids: lista.call(:dispensador_ids), formas: lista.call(:formas),
          origen: params[:origen], saldo: params[:saldo])
    end

    def initialize(club:, lote_ids: nil, paciente_ids: nil, genetica_ids: nil, sede_ids: nil,
                   dispensador_ids: nil, formas: nil, origen: nil, saldo: nil)
      @club = club
      # Cada lista se cruza con lo que es de la organización: lo ajeno se cae acá.
      @lote_ids        = propios(lote_ids)        { |ids| club.lotes.where(id: ids) }
      @paciente_ids    = propios(paciente_ids)    { |ids| Paciente.unscoped.where(club_id: club.id, id: ids) }
      @genetica_ids    = propios(genetica_ids)    { |ids| Genetica.unscoped.where(id: ids).where(club_id: [club.id, nil]) }
      @sede_ids        = propios(sede_ids)        { |ids| club.sedes.where(id: ids) }
      @dispensador_ids = propios(dispensador_ids) { |ids| User.where(club_id: club.id, id: ids) }
      @formas          = formas && (formas & Stock::FORMAS_PRODUCTO)
      @origen          = origen.to_s.presence_in(ORIGENES) || 'todo'
      @saldo           = saldo.to_s.presence_in(SALDOS.keys)
    end

    def activo?
      [@lote_ids, @paciente_ids, @genetica_ids, @sede_ids, @dispensador_ids, @formas, @saldo].any? || @origen != 'todo'
    end

    def propio?  = @origen != 'externo'
    def externo? = @origen != 'propio'

    # «Lotes: L-26-001, L-26-004 · 12 pacientes · sólo stock externo». nil sin filtros.
    def descripcion
      return nil unless activo?

      partes = []
      partes << nombres('Lotes', 'lotes', @lote_ids) { |ids| @club.lotes.where(id: ids).order(:codigo).pluck(:codigo) }
      partes << nombres('Pacientes', 'pacientes', @paciente_ids) { |ids| Paciente.unscoped.where(id: ids).map(&:nombre_completo).sort }
      partes << nombres('Genéticas', 'genéticas', @genetica_ids) { |ids| Genetica.unscoped.where(id: ids).order(:nombre).pluck(:nombre) }
      partes << nombres('Sedes', 'sedes', @sede_ids) { |ids| @club.sedes.where(id: ids).order(:nombre).pluck(:nombre) }
      partes << nombres('Dispensó', 'personas', @dispensador_ids) { |ids| User.where(id: ids).map(&:nombre_completo).sort }
      partes << nombres('Productos', 'productos', @formas) { |fs| fs.map { |f| f.tr('_', ' ') }.sort }
      partes << ORIGEN_LABEL[@origen]
      partes << SALDOS[@saldo]
      partes.compact.join(' · ')
    end

    def to_h
      { activo: activo?, descripcion: descripcion }
    end

    private

    def propios(ids)
      return nil if ids.nil?

      ids.empty? ? [] : yield(ids).pluck(:id)
    end

    def nombres(etiqueta, plural, ids)
      return nil if ids.nil?
      return "#{etiqueta}: ninguno válido" if ids.empty?
      return "#{ids.size} #{plural}" if ids.size > NOMBRES_MAX

      "#{etiqueta}: #{yield(ids).join(', ')}"
    end
  end
end
