module Lotes
  # Registra un trasplante de un lote: crea un PlantActivity 'transplant' por planta
  # (incluidas las ya cosechadas, porque un trasplante pasado se registra sobre el
  # lote tal como estaba) con la maceta origen→destino que muestra la timeline.
  # Si el lote sigue en cultivo, actualiza además su tamaño de maceta actual y el medio en el
  # que queda. Se puede backdatear (fecha pasada). Es la ÚNICA puerta del trasplante: la usan el
  # historial del lote, el registro rápido del teléfono y la completación de la tarea.
  class RegistrarTrasplante
    # Estados en los que el lote ya salió del cultivo: registrar un trasplante pasado
    # sigue siendo válido (es historia), pero NO se toca la "maceta actual".
    ESTADOS_POST_COSECHA = %w[cosecha en_manicura curado finalizado].freeze
    ESTADOS_RAICES = %w[excelente buena regular rootbound].freeze

    Result = Struct.new(:ok, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # medio: en qué queda (Lote::TIPOS_CULTIVO); sin él, no cambia. sustrato: cuál (texto libre).
    # plant_ids: si se trasplantó sólo una parte; sin él, todas.
    def initialize(lote:, usuario:, destino:, origen: nil, fecha: nil, medio: nil, sustrato: nil,
                   estado_raices: nil, observaciones: nil, plant_ids: nil)
      @lote          = lote
      @usuario       = usuario
      @destino       = destino.to_d
      @origen        = origen.presence&.to_d
      @fecha         = fecha
      @medio         = medio.presence
      @sustrato      = sustrato.to_s.strip.presence
      @estado_raices = estado_raices.presence
      @observaciones = observaciones.to_s.strip.presence
      @plant_ids     = Array(plant_ids).reject(&:blank?).map(&:to_i).presence
    end

    def call
      # Suelo vivo: plantado en la cama no hay más trasplantes (las raíces están en la tierra).
      if @lote.en_cama?
        return Result.new(ok: false, error: "El lote está plantado en la #{@lote.cama.nombre}: en la cama no hay trasplantes.")
      end
      return Result.new(ok: false, error: 'Indicá la maceta destino (en litros).') if @destino <= 0

      dia = @fecha.present? ? (Date.parse(@fecha.to_s) rescue nil) : Time.zone.today
      # Una fecha ilegible no se convierte en «hoy»: el lote quedaría prendido un día inventado.
      return Result.new(ok: false, error: 'La fecha del trasplante no es válida.') if dia.nil?
      return Result.new(ok: false, error: 'La fecha del trasplante no puede ser futura.') if dia > Time.zone.today
      if @medio && !Lote::TIPOS_CULTIVO.include?(@medio)
        return Result.new(ok: false, error: 'El medio tiene que ser sustrato o hidroponía.')
      end
      if @estado_raices && !ESTADOS_RAICES.include?(@estado_raices)
        return Result.new(ok: false, error: 'Estado de raíces inválido.')
      end

      occurred = dia.in_time_zone.change(hour: 12)
      # Incluimos cosechadas (NO descartadas): un trasplante pasado se registra sobre
      # las plantas que vivieron ese trasplante, aunque el lote ya esté cosechado.
      vivas  = @lote.plants.where.not(state: 'descartada')
      plants = @plant_ids ? vivas.where(id: @plant_ids) : vivas
      return Result.new(ok: false, error: 'El lote no tiene plantas para registrar el trasplante.') if plants.empty?
      if @plant_ids && plants.size != @plant_ids.uniq.size
        return Result.new(ok: false, error: 'Alguna de las plantas elegidas no es de este lote.')
      end

      parcial = @plant_ids && plants.size < vivas.count
      # Poner en maceta prende el lote entero (ver Lote#prender_al_ponerlo_en_maceta): si sólo van
      # algunas, las otras seguirían enraizando adentro de un lote en vegetativo.
      if parcial && @lote.estado == 'enraizado'
        return Result.new(ok: false, error: 'Para pasar a maceta sólo algunas plantas, separalas del lote con «Desprender».')
      end

      medio_antes = @lote.estado == 'enraizado' && @lote.metodo_enraizado.present? ? @lote.metodo_enraizado : @lote.grow_type

      ActiveRecord::Base.transaction do
        plants.find_each do |p|
          p.activities.create!(
            user:          @usuario,
            activity_type: 'transplant',
            description:   "Trasplante#{@origen ? " de #{@origen.to_f}L" : ''} a #{@destino.to_f}L",
            occurred_at:   occurred,
            metadata:      { 'maceta_origen_l' => @origen&.to_f, 'maceta_destino_l' => @destino.to_f },
          )
        end

        # Rastro en el historial unificado (categoria=trasplante con la maceta en metadata).
        @lote.lote_eventos.create!(
          tipo: 'actividad', categoria: 'trasplante', user: @usuario, club: @lote.club,
          registrado_en: occurred,
          descripcion: @observaciones,
          metadata: {
            'maceta_origen_l'  => @origen&.to_f,
            'maceta_destino_l' => @destino.to_f,
            'plantas'          => plants.size,
            'medio_origen'     => medio_antes,
            'medio_destino'    => @medio || @lote.grow_type,
            'sustrato'         => @sustrato,
            'estado_raices'    => @estado_raices,
          }.compact,
        )

        # Sólo se actualiza lo "actual" del lote si sigue en cultivo y se trasplantó entero: con
        # una parte, el lote sigue teniendo plantas en la maceta de antes.
        # Si venía enraizando, sacarlo de la bandeja a maceta lo pasa a vegetativo: es el mismo
        # acto físico que "prender" (ver Lote#prender_al_ponerlo_en_maceta). El actor va explícito
        # porque el evento que lo registra necesita autor y acá no hay request garantizado.
        unless ESTADOS_POST_COSECHA.include?(@lote.estado) || parcial
          cambios = { tamanio_maceta: @destino }
          cambios[:grow_type]           = @medio    if @medio
          cambios[:sustrato_especifico] = @sustrato if @sustrato
          @lote.actor_del_prendido = @usuario
          @lote.prendido_en        = occurred
          @lote.update!(cambios)
        end
      end
      Result.new(ok: true)
    rescue => e
      Result.new(ok: false, error: e.message)
    end
  end
end
