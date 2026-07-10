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
      render json: { provisiones: @evento.provisiones.includes(:bar_producto).map { |p| serialize(p) } }
    end

    # POST .../provisiones  { bar_producto_id, cantidad_prevista }
    # Upsert: si el producto ya está en la lista, actualiza la cantidad prevista.
    def create
      prod = @bar.bar_productos.find(params[:bar_producto_id])
      prov = @evento.provisiones.find_or_initialize_by(bar_producto_id: prod.id)
      prov.club ||= current_user.club
      prov.cantidad_prevista = params[:cantidad_prevista].to_d
      if prov.save
        render json: serialize(prov), status: :created
      else
        render json: { errors: prov.errors.full_messages }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Producto no encontrado' }, status: :not_found
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
        return render json: { error: 'Tiene stock reservado. Cerrá el evento (para devolver el sobrante) o desreservá primero.' }, status: :unprocessable_entity
      end
      @provision.destroy
      head :no_content
    end

    # POST .../provisiones/reservar — aparta del depósito lo previsto aún no reservado.
    # Requiere stock suficiente (comprar el faltante primero).
    def reservar
      faltos = @evento.provisiones.includes(:bar_producto).select { |p| p.faltante.positive? }
      if faltos.any?
        return render json: { error: "Falta stock para reservar: #{faltos.map { |p| p.bar_producto.nombre }.join(', ')}. Comprá el faltante primero." },
                      status: :unprocessable_entity
      end

      ActiveRecord::Base.transaction do
        @evento.provisiones.each do |prov|
          pendiente = prov.cantidad_prevista.to_d - prov.cantidad_reservada.to_d
          next if pendiente <= 0

          prov.bar_producto.registrar_salida!(cantidad: pendiente, tipo: 'reserva_evento',
                                               created_by: current_user, evento_bar: @evento,
                                               motivo: "Reserva evento «#{@evento.nombre}»")
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

          if sobrante.positive?
            prov.bar_producto.registrar_ingreso!(cantidad: sobrante, tipo: 'devolucion_evento',
                                                 created_by: current_user, evento_bar: @evento,
                                                 motivo: "Sobrante evento «#{@evento.nombre}»")
          end
          prov.update!(cantidad_consumida: consumida, cantidad_reservada: consumida) # queda saldado
        end
        @evento.update!(estado: 'finalizado') if ActiveModel::Type::Boolean.new.cast(params[:finalizar])
      end
      index
    end

    private

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

    def serialize(p)
      prod = p.bar_producto
      {
        id:                 p.id,
        bar_producto_id:    prod.id,
        nombre:             prod.nombre,
        categoria:          prod.categoria,
        en_deposito:        prod.stock.to_f,
        cantidad_prevista:  p.cantidad_prevista.to_f,
        cantidad_reservada: p.cantidad_reservada.to_f,
        cantidad_consumida: p.cantidad_consumida.to_f,
        faltante:           p.faltante.to_f,
        sobrante:           p.sobrante.to_f,
        costo_ars:          prod.costo_ars&.to_f,
      }
    end
  end
end
