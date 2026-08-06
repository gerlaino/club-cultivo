module Bar
  # Eventos de un bar (anidado bajo /bares/:bar_id/eventos). Gestión: admin/supervisor.
  # Feature flag :bar. Borrado = soft (recuperable desde la papelera).
  class EventosController < ApplicationController
    before_action :authenticate_user!
    before_action :require_feature_bar!
    before_action -> { require_feature!(:eventos) }
    before_action :require_gestion
    before_action :set_bar
    before_action :set_evento, only: [:show, :update, :destroy]

    # GET /bares/:bar_id/eventos
    def index
      eventos = @bar.eventos_bar.order(Arel.sql('fecha IS NULL, fecha DESC'))
      render json: eventos.map { |e| serialize(e) }
    end

    # GET /bares/:bar_id/eventos/:id
    def show
      render json: serialize(@evento, full: true)
    end

    # POST /bares/:bar_id/eventos
    def create
      evento = @bar.eventos_bar.build(evento_params.merge(club: current_user.club))
      if evento.save
        render json: serialize(evento, full: true), status: :created
      else
        render json: { errors: evento.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /bares/:bar_id/eventos/:id
    def update
      estado_previo = @evento.estado
      if @evento.update(evento_params)
        # Al finalizar o cancelar por CUALQUIER camino (incluido el desplegable de estado),
        # el sobrante reservado vuelve a su depósito. Evita que quede stock atrapado fuera.
        if @evento.estado != estado_previo && EventoBar::ESTADOS_SIN_VENTA.include?(@evento.estado)
          @evento.devolver_sobrante_reservado!(usuario: current_user)
        end
        render json: serialize(@evento.reload, full: true)
      else
        render json: { errors: @evento.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /bares/:bar_id/eventos/:id — soft-delete (recuperable)
    def destroy
      @evento.update!(deleted_by_id: current_user.id)
      @evento.destroy
      head :no_content
    end

    private

    def set_bar
      @bar = current_user.club.bares.find(params[:bar_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Bar no encontrado' }, status: :not_found
    end

    def set_evento
      @evento = @bar.eventos_bar.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Evento no encontrado' }, status: :not_found
    end

    def require_feature_bar!
      return if current_user.club.feature?(:bar)

      render json: { error: 'El bar no está habilitado para este club.' }, status: :forbidden
    end

    def require_gestion
      render json: { error: 'No autorizado' }, status: :forbidden unless %w[admin supervisor].include?(current_user&.role)
    end

    def evento_params
      params.require(:evento_bar).permit(:nombre, :fecha, :horario, :estado, :descripcion, :aforo, :presupuesto_ingresos, :notas)
    end

    def serialize(e, full: false)
      base = {
        id: e.id, nombre: e.nombre, fecha: e.fecha, horario: e.horario, estado: e.estado,
        aforo: e.aforo, presupuesto_ingresos: e.presupuesto_ingresos.to_f,
        resultado: e.resultado, resultado_proyectado: e.resultado_proyectado,
        costos_comprometidos: e.costos_comprometidos, costos_pagados: e.costos_pagados,
      }
      return base unless full

      base.merge(
        descripcion: e.descripcion, notas: e.notas,
        transiciones: e.transiciones_validas,
        costos: e.costos.order(:created_at).map { |c| serialize_costo(c) },
        tareas: e.tareas.ordenadas.map { |t| serialize_tarea(t) },
        tipos_entrada: e.tipos_entrada.ordenados.map { |t| serialize_tipo(t) },
        entradas_vendidas:     e.entradas_vendidas,
        recaudacion_entradas:  e.recaudacion_entradas,
        break_even_entradas:   e.break_even_entradas,
      )
    end

    def serialize_tipo(t)
      { id: t.id, nombre: t.nombre, precio_ars: t.precio_ars.to_f, cupo: t.cupo,
        vendidas: t.vendidas, disponibles: t.disponibles, agotado: t.agotado?,
        recaudado: t.recaudado, activo: t.activo }
    end

    def serialize_costo(c)
      { id: c.id, concepto: c.concepto, proveedor: c.proveedor, monto_ars: c.monto_ars.to_f,
        pagado: c.pagado, fecha: c.fecha }
    end

    def serialize_tarea(t)
      { id: t.id, titulo: t.titulo, hecha: t.hecha, vence_el: t.vence_el, orden: t.orden }
    end
  end
end
