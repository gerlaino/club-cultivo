module Nutricion
  # LO QUE SE DICTÓ DE NUTRIENTES, convertido en lo que se descuenta del depósito (13-oct-2026).
  #
  # El dictado guardaba «le puse vege» como texto y no descontaba nada (Germán). El modelo de IA
  # sólo ENTIENDE: qué nutrientes o qué receta nombró y, si lo dijo, cuánto («un pulso a cada
  # planta», «2 ml por litro», «la receta Floración con 3 litros»). La cuenta la hace el sistema
  # acá, con `Nutricion::Dosis`, nunca la IA.
  #
  # Si no se dijo cuánto, se usa la dosis de la ETIQUETA que la persona cargó en el nutriente para
  # la fase en que están las plantas. Si tampoco hay, la línea va sin cantidad y la pantalla la pide.
  # Lo que vuelve es una PROPUESTA: se muestra antes de guardar y se puede corregir. Lo que se
  # guarda es lo que la persona confirmó (`AsistenteController#aplicar_nutricion_dictada`).
  #
  # datos (del dictado):
  #   receta_nombre: 'Floración'
  #   nutrientes: [{ nombre: 'Vege', cantidad: 1, medida: 'medida', medida_nombre: 'pulso', por: 'planta' }]
  #   volumen_l: 3
  #
  # Si no se puede calcular, el riego SE GUARDA IGUAL con lo dicho y no se descuenta nada: la
  # pantalla no lo pide como un formulario, sólo avisa qué no se descontó y por qué (14-oct-2026).
  class DesdeDictado
    def self.call(**kwargs) = new(**kwargs).call

    POR_TEXTO = { 'planta' => 'por planta', 'litro' => 'por litro', 'total' => 'en total' }.freeze

    # «Vege: 1 pulso por planta · receta Floración»: lo dicho, para el registro.
    def self.texto_dicho(datos)
      d = datos.to_h.stringify_keys
      partes = Array(d['nutrientes']).map { |n| n.to_h.stringify_keys }.select { |n| n['nombre'].present? }.map do |n|
        next n['nombre'].to_s if n['cantidad'].blank?

        medida = n['medida'] == 'medida' ? n['medida_nombre'].presence || 'medida' : n['medida'].presence
        cant = n['cantidad'].to_s.sub(/\.0\z/, '').sub('.', ',')
        [n['nombre'].to_s + ':', cant, medida, POR_TEXTO[n['por'].to_s]].compact.join(' ')
      end
      partes << "receta #{d['receta_nombre']}" if d['receta_nombre'].present?
      partes.join(' · ')
    end

    # LO CONFIRMADO, listo para `Nutricion::Aplicar`: { receta:, litros:, items: } o nil.
    #
    # Viene de la pantalla con la forma de `InsumosAplicados` ({ modo, receta_id, base, items }).
    # Con receta, `items` trae sólo las cantidades que la persona CAMBIÓ: se abre la receta entera y
    # se pisan ésas, igual que lo que muestra la pantalla (`lineasDeReceta`). Pasarle a `Aplicar`
    # sólo las cambiadas descontaba sólo ésas.
    def self.para_aplicar(club:, nutricion:, sala: nil)
      n = nutricion.to_h.deep_stringify_keys
      return nil if n.blank? || n['modo'] == 'ninguno'

      litros = (n['base'].presence || n['litros'].presence)&.to_d
      dichos = Array(n['items']).map { |i| i.to_h.stringify_keys }
      ids    = club.insumos.where(id: dichos.map { |i| i['insumo_id'] }).pluck(:id).to_set
      dichos = dichos.select { |i| ids.include?(i['insumo_id'].to_i) } # nada de otra organización
      receta = n['receta_id'].present? ? club.recetas.find_by(id: n['receta_id']) : nil

      items = if n['modo'] == 'receta' && receta
                return nil unless litros&.positive?

                receta.calcular(litros, sede: sala&.sede).map do |l|
                  ov = dichos.find { |d| d['insumo_id'].to_i == l[:insumo_id] }
                  { insumo_id: l[:insumo_id], cantidad: ov&.dig('cantidad').presence || l[:cantidad],
                    modo_faltante: ov&.dig('modo_faltante') }
                end
              else
                dichos.map { |d| { insumo_id: d['insumo_id'].to_i, cantidad: d['cantidad'], modo_faltante: d['modo_faltante'] } }
              end
      items = items.select { |i| i[:cantidad].present? && i[:cantidad].to_d.positive? }
      return nil if items.empty?

      { receta: receta, litros: litros, items: items }
    end

    def initialize(club:, lotes:, datos:, sala: nil)
      @club  = club
      @lotes = Array(lotes)
      @datos = datos.to_h.stringify_keys
      @sala  = sala || @lotes.first&.sala
      @avisos = []
    end

    # nil si no se nombró ningún nutriente ni receta.
    def call
      dichos = Array(@datos['nutrientes']).map { |n| n.to_h.stringify_keys }.select { |n| n['nombre'].present? }
      receta_dicha = @datos['receta_nombre'].to_s.strip
      return nil if dichos.empty? && receta_dicha.blank?

      receta = receta_dicha.present? ? buscar(recetas, receta_dicha, 'receta') : nil
      items  = dichos.filter_map { |n| item_de(n) }

      if receta && items.empty?
        @avisos << 'Decí cuántos litros preparaste: la receta se dosifica por litro.' unless litros
        return propuesta(modo: 'receta', receta: receta, items: [])
      end
      if receta
        # Receta y además productos sueltos: se abre la receta en sus líneas y se suman los otros.
        if litros
          desde_receta = receta.calcular(litros, sede: sede).map do |l|
            { 'insumo_id' => l[:insumo_id], 'nombre' => l[:nombre], 'cantidad' => l[:cantidad].to_f, 'calculada' => l[:cantidad].to_f,
              'unidad_insumo' => l[:unidad_insumo], 'detalle' => "receta «#{receta.nombre}»", 'origen' => 'receta' }
          end
          items = desde_receta + items.reject { |i| desde_receta.any? { |r| r['insumo_id'] == i['insumo_id'] } }
        else
          @avisos << "Decí cuántos litros preparaste para calcular la receta «#{receta.nombre}»."
        end
      end
      return nil if items.empty? && receta.nil? && @avisos.empty?

      propuesta(modo: 'sueltos', receta: receta, items: items)
    end

    private

    def propuesta(modo:, receta:, items:)
      { 'modo' => modo, 'receta_id' => receta&.id, 'receta_nombre' => receta&.nombre,
        'litros' => litros&.to_f, 'base' => litros&.to_f, 'items' => items, 'avisos' => @avisos }
    end

    def item_de(dicho)
      insumo = buscar(nutrientes, dicho['nombre'], 'nutriente')
      return nil unless insumo

      base = { 'insumo_id' => insumo.id, 'nombre' => insumo.nombre, 'unidad_insumo' => insumo.unidad_medida }
      res, origen = calcular(insumo, dicho)
      if res&.cantidad
        # `calculada`: la cuenta original. Si la persona cambia la cantidad, el detalle deja de valer.
        return base.merge('cantidad' => res.cantidad.to_f, 'calculada' => res.cantidad.to_f,
                          'detalle' => res.detalle, 'origen' => origen)
      end

      @avisos << falta_aviso(insumo, res&.falta, dicho)
      base.merge('cantidad' => nil, 'detalle' => nil, 'origen' => origen)
    end

    # Lo dicho manda; si no se dijo cuánto, la etiqueta de la fase.
    def calcular(insumo, dicho)
      if dicho['cantidad'].present?
        medida = dicho['medida'].presence || (insumo.medida_casera.present? ? 'medida' : 'ml')
        return [Dosis.calcular(insumo: insumo, valor: dicho['cantidad'], medida: medida,
                               por: dicho['por'], litros: litros, plantas: plantas), 'dicho']
      end
      return [nil, 'etiqueta'] unless fase && insumo.dosis_de(fase).present? && insumo.dosis_unidad.present?

      medida, por = Dosis.partes_de(insumo.dosis_unidad)
      [Dosis.calcular(insumo: insumo, valor: insumo.dosis_de(fase), medida: medida, por: por,
                      litros: litros, plantas: plantas), 'etiqueta']
    end

    # Qué no se descontó y por qué. No es un pedido: el riego se guarda igual con lo dicho.
    def falta_aviso(insumo, falta, dicho = {})
      no = "#{insumo.nombre} no se descuenta"
      case falta
      when 'litros'  then "#{no}: se dosifica por litro y no dijiste cuántos litros."
      when 'plantas' then "#{no}: no encontré plantas en cultivo para calcular por planta."
      when 'medida'
        medida = insumo.medida_casera.presence || dicho['medida_nombre'].presence || 'medida'
        "#{no}: falta cargar cuánto es 1 #{medida} (en Nutrientes)."
      else
        if fase.nil? && @lotes.map(&:estado).uniq.size > 1
          "#{no}: las plantas están en fases distintas y no dijiste cuánto."
        else
          "#{no}: no dijiste cuánto y no tiene cargada la dosis de la etiqueta."
        end
      end
    end

    # Por nombre: igual (sin mayúsculas ni espacios de más) y si no, el ÚNICO que lo contiene. Lo
    # ambiguo no se adivina: descontar el producto equivocado es peor que preguntar.
    def buscar(scope, nombre, que)
      dicho = normal(nombre)
      todos = scope.to_a
      exacto = todos.find { |x| normal(x.nombre) == dicho }
      return exacto if exacto

      parecidos = todos.select { |x| normal(x.nombre).include?(dicho) || dicho.include?(normal(x.nombre)) }
      return parecidos.first if parecidos.size == 1

      @avisos << if parecidos.empty?
                   "No encontré «#{nombre}» entre tus #{que == 'receta' ? 'recetas' : 'nutrientes'}."
                 else
                   "«#{nombre}» puede ser #{parecidos.map(&:nombre).join(' o ')}: elegilo a mano."
                 end
      nil
    end

    # Sin tildes ni mayúsculas: el dictado puede traer «floracion» para la receta «Floración».
    def normal(texto) = ActiveSupport::Inflector.transliterate(texto.to_s).strip.downcase.squeeze(' ')

    def nutrientes = @club.insumos.activos.por_tipo('cultivo').para_sede(sede&.id)
    def recetas    = @club.recetas.where(activa: true, uso: 'riego')
    def sede       = @sala&.sede

    def litros
      v = @datos['volumen_l']
      v.present? && v.to_d.positive? ? v.to_d : nil
    end

    def plantas
      @plantas ||= Plant.where(lote_id: @lotes.map(&:id)).where(state: %w[enraizado vegetativo floracion]).count
    end

    # La fase de las plantas, si es una sola. Con fases mezcladas no hay UNA dosis de etiqueta.
    def fase
      estados = @lotes.map(&:estado).uniq
      estados.size == 1 && Insumo::FASES_DOSIS.include?(estados.first) ? estados.first : nil
    end
  end
end
