module Nutricion
  # CORREGIR LOS NUTRIENTES DE UN RIEGO YA GUARDADO (Germán, 13-oct-2026).
  #
  # El dictado se puede equivocar —«vege» era Kawsay, o la cantidad no era esa— y no había forma
  # de arreglarlo: lo descontado quedaba descontado. Editar es DESHACER el riego entero (lo
  # descontado vuelve al depósito y el costo sale de los lotes, `Aplicar.revertir!`) y volver a
  # aplicarlo con lo nuevo. Queda el rastro en el depósito (consumo borrado + consumo nuevo).
  #
  # El riego entero y no la parte de un lote: regar la sala crea un registro por lote y descuenta
  # UNA vez (`Aplicar`, `registro_ids` en la copia). Corregir desde un lote corrige todos.
  #
  # Qué NO se edita: un riego de un lote que ya salió del cultivo (cosechado en adelante). Su costo
  # ya pasó a la cosecha, y moverlo cambiaría el costo de un producto ya hecho.
  class Editar
    Error = Class.new(StandardError)
    Resultado = Struct.new(:registros, :nutricion, :faltantes, keyword_init: true)

    VENTANA = 10.seconds # riegos de sala viejos, sin `registro_ids`: los hermanos se crearon juntos

    def self.call(**kwargs) = new(**kwargs).call

    # Por qué no se puede editar este riego, o nil.
    def self.bloqueo(registro, usuario)
      return 'Sólo quien lo registró o un administrador puede corregirlo.' unless usuario.admin? || usuario.super_admin? || registro.user_id == usuario.id

      afuera = grupo_de(registro).map(&:lote).compact.reject { |l| Lote::CULTIVO_ESTADOS.include?(l.estado) }
      return "#{afuera.first.codigo} ya se cosechó: su costo pasó a la cosecha y no se mueve." if afuera.any?

      nil
    end

    def self.grupo_de(registro)
      ids = Array(registro.nutricion.to_h['registro_ids']).map(&:to_i)
      if ids.any?
        RegistroAmbiental.where(club_id: registro.club_id, id: ids).includes(:lote).to_a.presence || [registro]
      elsif registro.nutricion.present?
        RegistroAmbiental.where(club_id: registro.club_id, user_id: registro.user_id, nutricion: registro.nutricion)
                         .where(registrado_en: (registro.registrado_en - VENTANA)..(registro.registrado_en + VENTANA))
                         .includes(:lote).to_a.presence || [registro]
      else
        [registro]
      end
    end

    def initialize(registro:, usuario:, nutricion:)
      @registro  = registro
      @usuario   = usuario
      @nutricion = nutricion
    end

    def call
      if (motivo = self.class.bloqueo(@registro, @usuario))
        raise Error, motivo
      end

      grupo = self.class.grupo_de(@registro)
      sala  = @registro.lote&.sala
      plan  = DesdeDictado.para_aplicar(club: @registro.club, nutricion: @nutricion, sala: sala)

      ActiveRecord::Base.transaction do
        grupo.each { |r| Aplicar.revertir!(r) }
        if plan
          res = Aplicar.new(club: @registro.club, usuario: @usuario, registros: grupo, litros: plan[:litros],
                            receta: plan[:receta], items: plan[:items], sala: sala).call
          grupo.each { |r| r.update_columns(fertilizacion: true) }
          Resultado.new(registros: grupo, nutricion: res.nutricion, faltantes: res.faltantes)
        else
          # «Nada del depósito»: se deshace lo aplicado y el riego queda como riego con agua sola.
          grupo.each { |r| r.update_columns(nutricion: nil, receta_id: nil, fertilizacion: false) }
          Resultado.new(registros: grupo, nutricion: nil, faltantes: [])
        end
      end
    end

    # Lo aplicado, con la forma que edita la pantalla (`InsumosAplicados`): sueltos con su cantidad.
    # Se abre como sueltos aunque haya venido de una receta: lo que se corrige es lo que se usó.
    def self.para_editar(registro)
      n = registro.nutricion.to_h
      return { 'modo' => 'ninguno', 'items' => [] } if n.blank?

      { 'modo' => 'sueltos', 'receta_id' => n['receta_id'], 'base' => n['litros'].presence&.to_f,
        'items' => Array(n['items']).filter_map do |i|
          next if i['insumo_id'].blank?

          { 'insumo_id' => i['insumo_id'], 'cantidad' => i['cantidad'].to_f, 'modo_faltante' => 'descontar_disponible' }
        end }
    end
  end
end
