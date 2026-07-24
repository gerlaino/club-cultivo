module Bar
  # Provisión de un evento: qué productos y cuánto se necesitan, con reserva del depósito.
  # Flujo: armar lista (prevista) → comprar faltante → reservar (sale del depósito) → cerrar
  # (el sobrante = reservada − consumida vuelve al depósito). Gestión: admin/supervisor.
  class EventoProvisionesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action :require_gestion
    before_action :set_evento
    before_action :set_provision, only: [:update, :destroy]

    # GET /bares/:bar_id/eventos/:evento_id/provisiones
    def index
      render json: { provisiones: @evento.provisiones.includes(:provisionable).map { |p| serialize(p) } }
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
    # Requiere stock suficiente (comprar el faltante primero).
    def reservar
      faltos = @evento.provisiones.includes(:provisionable).select { |p| p.faltante.positive? }
      if faltos.any?
        return render json: { error: "Falta stock para reservar: #{faltos.map(&:provisionable_nombre).join(', ')}. Comprá el faltante primero." },
                      status: :unprocessable_entity
      end

      ActiveRecord::Base.transaction do
        @evento.provisiones.includes(:provisionable).each do |prov|
          pendiente = prov.cantidad_prevista.to_d - prov.cantidad_reservada.to_d
          next if pendiente <= 0

          prov.aplicar_reserva!(cantidad: pendiente, usuario: current_user)
          prov.update!(cantidad_reservada: prov.cantidad_reservada.to_d + pendiente)
        end
      end
      index
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST .../provisiones/cerrar  { consumos: [{ id, cantidad_consumida }], finalizar? }
    # Registra lo consumido y DEVUELVE el sobrante (reservada − consumida) al depósito.
    def cerrar
      consumos = Array(params[:consumos]).index_by { |c| c[:id].to_i }

      ActiveRecord::Base.transaction do
        @evento.provisiones.each do |prov|
          consumida = (consumos[prov.id] ? consumos[prov.id][:cantidad_consumida].to_d : prov.cantidad_consumida.to_d)
          consumida = consumida.clamp(0, prov.cantidad_reservada.to_d)
          sobrante  = prov.cantidad_reservada.to_d - consumida

          prov.aplicar_devolucion!(cantidad: sobrante, usuario: current_user) if sobrante.positive?
          prov.update!(cantidad_consumida: consumida, cantidad_reservada: consumida) # queda saldado
        end
        @evento.update!(estado: 'finalizado') if ActiveModel::Type::Boolean.new.cast(params[:finalizar])
      end
      index
    end

    # GET .../provisiones/buscar?q=texto
    # Búsqueda unificada de productos para proveer, entre los 3 depósitos: salón
    # (BarProducto) + cultivo/general (Insumo). Devuelve el shape que espera create.
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
                                            ins.stock_actual, ins.unidad_medida, ins.costo_promedio_ars) }

      render json: { resultados: resultados.sort_by { |r| r[:nombre].to_s.downcase } }
    end

    private

    def item_busqueda(tipo, id, nombre, deposito, stock, unidad, costo)
      { provisionable_type: tipo, provisionable_id: id, nombre: nombre, deposito: deposito,
        en_deposito: stock.to_f, unidad: unidad, costo_ars: costo.to_f }
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
        deposito:           p.deposito,   # salon | cultivo | general
        unidad:             p.unidad,
        en_deposito:        p.stock_disponible.to_f,
        cantidad_prevista:  p.cantidad_prevista.to_f,
        cantidad_reservada: p.cantidad_reservada.to_f,
        cantidad_consumida: p.cantidad_consumida.to_f,
        faltante:           p.faltante.to_f,
        sobrante:           p.sobrante.to_f,
        costo_ars:          p.costo_unitario.to_f,
      }
    end
  end
end
