module Bar
  # Provisión de un evento: qué productos y cuánto se necesitan, con reserva del depósito.
  # Flujo: armar lista (prevista) → comprar faltante → reservar (sale del depósito) → cerrar
  # (el sobrante = reservada − consumida vuelve al depósito). Gestión: admin/supervisor.
  class EventoProvisionesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action -> { require_feature!(:eventos) }
    before_action :require_gestion
    before_action :set_evento
    before_action :set_provision, only: [:update, :destroy]

    # GET /bares/:bar_id/eventos/:evento_id/provisiones
    def index
      render json: { provisiones: serialize_todas }
    end

    # POST .../provisiones  { provisionable_type, provisionable_id, cantidad_prevista }
    #   (compat: acepta bar_producto_id como BarProducto)
    # Upsert: si el producto ya está en la lista, actualiza la cantidad prevista.
    def create
      obj = resolver_provisionable
      return if obj.nil? # ya renderizó el error

      prov = @evento.provisiones.find_or_initialize_by(provisionable: obj)
      prov.club ||= current_user.club
      prov.cantidad_prevista = params[:cantidad_prevista].to_d
      if prov.save
        render json: serialize(prov), status: :created
      else
        render json: { errors: prov.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH .../provisiones/:id  { cantidad_prevista }
    def update
      if @provision.update(cantidad_prevista: params[:cantidad_prevista].to_d)
        render json: serialize(@provision)
      else
        render json: { errors: @provision.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE .../provisiones/:id — solo si no tiene stock reservado sin devolver
    def destroy
      if @provision.cantidad_reservada.to_d > @provision.cantidad_consumida.to_d
        return render json: { error: 'Tiene stock reservado. Cerrá o cancelá el evento para devolver el sobrante al depósito, y después sacá la provisión.' }, status: :unprocessable_entity
      end
      @provision.destroy
      head :no_content
    end

    # POST .../provisiones/reservar — aparta del depósito lo previsto aún no reservado.
    # RESERVA PARCIAL: de cada ítem aparta lo que haya (antes era todo-o-nada y un solo faltante
    # bloqueaba la reserva completa del evento). Lo que no se pudo apartar vuelve como
    # `advertencias` para que el organizador compre el faltante y vuelva a reservar.
    def reservar
      advertencias = []

      ActiveRecord::Base.transaction do
        @evento.provisiones.includes(:provisionable).each do |prov|
          pendiente = prov.cantidad_prevista.to_d - prov.cantidad_reservada.to_d
          next if pendiente <= 0

          posible = [pendiente, prov.stock_disponible].min
          if posible <= 0
            advertencias << "#{prov.provisionable_nombre}: sin stock disponible, no se reservó nada (faltan #{fmt(pendiente)} #{prov.unidad})."
            next
          end

          prov.aplicar_reserva!(cantidad: posible, usuario: current_user)
          prov.update!(cantidad_reservada: prov.cantidad_reservada.to_d + posible)

          if posible < pendiente
            advertencias << "#{prov.provisionable_nombre}: se reservaron #{fmt(posible)} de #{fmt(pendiente)} #{prov.unidad} (faltan #{fmt(pendiente - posible)})."
          end
        end
      end
      render json: { provisiones: serialize_todas, advertencias: advertencias }
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST .../provisiones/cerrar
    #   { consumos: [{ id, cantidad_consumida, consumo_interno }], finalizar? }
    #
    # Cierra cada provisión. Dos caminos según qué se haya provisionado:
    #
    # • APARTADO (Stock): lo DISPENSADO durante el evento ya se imputó solo (cada dispensa desde
    #   lo reservado sube cantidad_consumida) — acá no se toca. Lo que se consumió sin dispensar
    #   a nadie (degustación, muestra) llega como `consumo_interno`: descuenta ahora de verdad,
    #   con movimiento `consumo_evento`, y es COGS del evento. El resto se libera.
    # • DEPÓSITO (BarProducto / Insumo): ya salió al reservar; se registra lo consumido y el
    #   sobrante vuelve al depósito.
    def cerrar
      consumos = Array(params[:consumos]).index_by { |c| c[:id].to_i }

      ActiveRecord::Base.transaction do
        @evento.provisiones.includes(:provisionable).each do |prov|
          fila = consumos[prov.id]

          if prov.apartado?
            prov.registrar_consumo_interno!(cantidad: fila[:consumo_interno].to_d, usuario: current_user) if fila
            # Libera lo que quedó apartado: lo dispensado y lo consumido ya salieron del inventario.
            prov.update!(cantidad_reservada: prov.consumido_total)
          else
            consumida = (fila ? fila[:cantidad_consumida].to_d : prov.cantidad_consumida.to_d)
            consumida = consumida.clamp(0, prov.cantidad_reservada.to_d)
            sobrante  = prov.cantidad_reservada.to_d - consumida

            prov.aplicar_devolucion!(cantidad: sobrante, usuario: current_user) if sobrante.positive?
            prov.update!(cantidad_consumida: consumida, cantidad_reservada: consumida) # queda saldado
          end
        end
        @evento.update!(estado: 'finalizado') if ActiveModel::Type::Boolean.new.cast(params[:finalizar])
      end
      index
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # GET .../provisiones/buscar?q=texto
    # Búsqueda unificada de mercadería para proveer, entre TODOS los depósitos: salón
    # (BarProducto) + cultivo/general (Insumo) + dispensario/externo (Stock).
    # Devuelve el shape que espera create.
    def buscar
      q = params[:q].to_s.strip
      bp_scope  = @bar.bar_productos
      ins_scope = current_user.club.insumos.activos
      if q.present?
        like = "%#{q}%"
        bp_scope  = bp_scope.where('nombre ILIKE ?', like)
        ins_scope = ins_scope.where('nombre ILIKE ?', like)
      end

      resultados =
        bp_scope.map { |bp| item_busqueda('BarProducto', bp.id, bp.nombre, 'salon',
                                          bp.stock, (bp.respond_to?(:unidad_medida) ? bp.unidad_medida : 'u'), bp.costo_ars) } +
        ins_scope.map { |ins| item_busqueda('Insumo', ins.id, ins.nombre, ins.tipo,
                                            ins.stock_actual, ins.unidad_medida, ins.costo_promedio_ars) } +
        # Todo Stock se APARTA (bloquea sin descontar): su salida del inventario es la dispensación.
        stocks_provisionables(q).map { |s| item_busqueda('Stock', s.id, s.etiqueta,
                                                         s.regulatorio? ? 'dispensacion' : 'externo',
                                                         s.cantidad_disponible_real, s.unidad, s.costo_unitario_ars,
                                                         apartado: true) }

      render json: { resultados: resultados.sort_by { |r| r[:nombre].to_s.downcase } }
    end

    private

    # Stock provisionable para el evento: el de la sede del bar (o del pool del club), con
    # existencias y habilitado para salir (disponibilidad != 'ninguna' — lo apartado en
    # cuarentena/testeo no se compromete). El filtro por texto se hace en Ruby porque la
    # etiqueta se arma de genética/descripción/forma.
    def stocks_provisionables(q)
      base = Stock.where(club_id: current_user.club_id)
                  .where(sede_id: [@bar.sede_id, nil])
                  .where.not(disponibilidad: 'ninguna')
                  .disponibles.includes(:lote, :genetica)
      base = base.to_a
      return base if q.blank?

      base.select { |s| s.etiqueta.to_s.downcase.include?(q.downcase) }
    end

    def item_busqueda(tipo, id, nombre, deposito, stock, unidad, costo, apartado: false)
      { provisionable_type: tipo, provisionable_id: id, nombre: nombre, deposito: deposito,
        en_deposito: stock.to_f, unidad: unidad, costo_ars: costo.to_f, apartado: apartado }
    end

    def fmt(n) = n.to_d.round(2).to_s('F').sub(/\.0$/, '')

    def serialize_todas
      @evento.provisiones.includes(:provisionable).map { |p| serialize(p) }
    end

    def set_evento
      @bar = current_user.club.bares.find(params[:bar_id])
      @evento = @bar.eventos_bar.find(params[:evento_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Evento no encontrado' }, status: :not_found
    end

    def set_provision
      @provision = @evento.provisiones.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Provisión no encontrada' }, status: :not_found
    end

    def require_feature_bar!
      render json: { error: 'El bar no está habilitado.' }, status: :forbidden unless current_user.club.feature?(:bar)
    end

    def require_gestion
      render json: { error: 'No autorizado' }, status: :forbidden unless %w[admin supervisor].include?(current_user&.role)
    end

    # Resuelve el provisionable (BarProducto | Insumo) del payload, validando pertenencia al
    # club. Compat: si llega bar_producto_id (UI vieja), se toma como BarProducto.
    def resolver_provisionable
      tipo = params[:provisionable_type].presence
      id   = params[:provisionable_id].presence || params[:bar_producto_id].presence
      tipo ||= 'BarProducto' if params[:bar_producto_id].present?

      obj = case tipo
            when 'BarProducto' then @bar.bar_productos.find_by(id: id)
            when 'Insumo'      then current_user.club.insumos.find_by(id: id)
            when 'Stock'       then Stock.where(club_id: current_user.club_id).find_by(id: id)
            end
      render json: { error: 'Producto no válido' }, status: :unprocessable_entity if obj.nil?
      obj
    end

    def serialize(p)
      {
        id:                 p.id,
        provisionable_type: p.provisionable_type,
        provisionable_id:   p.provisionable_id,
        bar_producto_id:    (p.provisionable_type == 'BarProducto' ? p.provisionable_id : nil), # compat UI vieja
        nombre:             p.provisionable_nombre,
        deposito:           p.deposito,   # salon | cultivo | general | dispensacion | externo
        apartado:           p.apartado?,  # true = bloquea gramos, no descuenta (flor regulatoria)
        unidad:             p.unidad,
        en_deposito:        p.stock_disponible.to_f,
        cantidad_prevista:  p.cantidad_prevista.to_f,
        cantidad_reservada: p.cantidad_reservada.to_f,
        cantidad_consumida: p.cantidad_consumida.to_f,       # apartado: lo ya DISPENSADO en el evento
        consumo_interno:    p.cantidad_consumo_interno.to_f, # consumido sin dispensar
        saldo_apartado:     p.saldo_apartado.to_f,
        faltante:           p.faltante.to_f,
        sobrante:           p.sobrante.to_f,
        costo_ars:          p.costo_unitario.to_f,
      }
    end
  end
end
