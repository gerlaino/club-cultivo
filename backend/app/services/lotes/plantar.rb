module Lotes
  # PLANTAR: dar de alta un lote con sus plantas.
  #
  # Una regla para las dos puertas que crean plantas: el formulario (`LotesController#create`) y
  # el dictado del asistente en autocultivo («puse dos semillas de Ananda en la carpa chica»,
  # 9-oct-2026). Las dos tienen que dejar lo mismo: los días objetivo heredados de la genética,
  # la carga «ya la tenía» con sus pasos de fase en la fecha real, cada planta con la fecha de la
  # fase en que entra y el nombre que corresponde. Escrito dos veces, ya divergía.
  #
  # Lo que es del pedido —permisos, cupo del plan, cama, sede, el 422 con el mensaje— queda en
  # cada puerta: acá llega un lote armado y válido para guardar.
  class Plantar
    # La fase de la planta según la del lote al entrar. 'esqueje' no existe como fase.
    STATE_POR_ESTADO = {
      'enraizado'  => 'enraizado',
      'vegetativo' => 'vegetativo',
      'floracion'  => 'floracion',
      'cosecha'    => 'cosechado',
      'curado'     => 'cosechado',
      'finalizado' => 'cosechado',
    }.freeze

    # El campo de fecha de la planta que corresponde a la fase en que entra: la planta hereda la
    # fecha real de inicio del lote, no la del día que se cargó (si no, «días en fase» arranca en 0).
    FECHA_POR_STATE = {
      'enraizado' => :fecha_germinacion,
      'vegetativo' => :fecha_vegetativo,
      'floracion' => :fecha_floracion,
      'cosechado' => :fecha_cosecha,
    }.freeze

    FASE_LABEL = { 'enraizado' => 'Enraizado', 'vegetativo' => 'Vegetativo', 'floracion' => 'Floración', 'cosecha' => 'Cosecha' }.freeze

    def self.state_de(estado) = STATE_POR_ESTADO[estado] || 'vegetativo'
    def self.fecha_de(state)  = FECHA_POR_STATE[state]

    # Los días objetivo por fase los toma de la genética, salvo que el alta los haya escrito.
    def self.heredar_objetivos(lote)
      g = lote.genetica
      return unless g

      lote.dias_vegetativo_objetivo ||= g.dias_vegetativo_objetivo
      lote.dias_floracion_objetivo  ||= g.tiempo_floracion
      lote.dias_cosecha_objetivo    ||= g.dias_cosecha_objetivo
      lote.dias_ciclo_objetivo      ||= g.dias_ciclo_objetivo
    end

    # «Ya lo tenía»: cuántos días lleva en cada fase. Devuelve cuándo arrancó, o nil si no cargó días.
    def self.inicio_heredado(estado, dias)
      total = total_dias(estado, dias)
      total.positive? ? total.days.ago.to_date : nil
    end

    def self.total_dias(estado, dias)
      d = dias.to_h.transform_keys(&:to_s)
      s, v, f, c = %w[semilla_esqueje vegetativo floracion cosecha].map { |k| d[k].to_i }
      case estado
      when 'enraizado'  then s
      when 'vegetativo' then s + v
      when 'floracion'  then s + v + f
      when 'cosecha'    then s + v + f + c
      else 0
      end
    end

    # `heredado`: los días por fase ({ semilla_esqueje:, vegetativo:, floracion:, cosecha: }) si el
    # lote ya existía; nil si nace hoy (o en la fecha que trae).
    def initialize(lote:, usuario:, plantas:, heredado: nil)
      @lote     = lote
      @usuario  = usuario
      @plantas  = plantas.to_i
      @heredado = heredado
    end

    def call
      ActiveRecord::Base.transaction do
        @lote.save!
        registrar_herencia! if @heredado
        crear_plantas! if @plantas.positive?
      end
      @lote
    end

    # Cómo se llaman las plantas que nacen con el lote. En una organización, por el código del lote
    # (L-26-002-P001): es lo que va en la etiqueta y lo que se busca en la sala. En autocultivo la
    # persona piensa en plantas y no en lotes (8-oct-2026, Germán): se llaman por su genética y
    # siguen la numeración que ya haya («Ananda 3» si ya existe una «Ananda 2»). Se renombran a gusto.
    def self.nombres_plantas(lote, cantidad)
      base = lote.genetica&.nombre.to_s.strip.presence
      unless lote.club&.personal? && base
        return Array.new(cantidad) { |i| "#{lote.codigo}-P#{(i + 1).to_s.rjust(3, '0')}" }
      end

      patron = /\A#{Regexp.escape(base)} (\d+)\z/
      ultimo = Plant.joins(:lote).where(lotes: { club_id: lote.club_id })
                    .where('plants.nombre LIKE ?', "#{Plant.sanitize_sql_like(base)} %")
                    .pluck(:nombre).filter_map { |n| n[patron, 1]&.to_i }.max || 0
      Array.new(cantidad) { |i| "#{base} #{ultimo + i + 1}" }
    end

    private

    def crear_plantas!
      state  = self.class.state_de(@lote.estado)
      campo  = self.class.fecha_de(state)
      nombres = self.class.nombres_plantas(@lote, @plantas)
      @plantas.times do |i|
        attrs = { nombre: nombres[i], state: state }
        attrs[campo] = @lote.start_date if campo
        @lote.plants.create!(attrs)
      end
    end

    # Los pasos de fase de un lote que ya existía, en la fecha en que pasaron: sin ellos el lote
    # cuenta los días de vegetativo o de floración desde hoy.
    def registrar_herencia!
      inicio = self.class.inicio_heredado(@lote.estado, @heredado)
      return unless inicio

      @lote.update_column(:start_date, inicio)
      d = @heredado.to_h.transform_keys(&:to_s)
      s, v, f = %w[semilla_esqueje vegetativo floracion].map { |k| d[k].to_i }

      paso!('enraizado', 'vegetativo', inicio + s)          if %w[vegetativo floracion cosecha].include?(@lote.estado)
      paso!('vegetativo', 'floracion', inicio + s + v)      if %w[floracion cosecha].include?(@lote.estado)
      paso!('floracion', 'cosecha', inicio + s + v + f)     if @lote.estado == 'cosecha'
    end

    def paso!(desde, hacia, fecha)
      @lote.lote_eventos.create!(
        tipo: 'cambio_estado', estado_anterior: desde, estado_nuevo: hacia,
        descripcion: "#{FASE_LABEL[desde]} → #{FASE_LABEL[hacia]} (carga heredada)",
        user: @usuario, club: @lote.club, registrado_en: fecha.to_time,
      )
    end
  end
end
