module Public
  class BenchmarkController < ActionController::API
    # Agregación cross-club anonimizada, sin usuario → sin tenant. Con require_tenant=true
    # (TEN-01c) los queries a modelos tenant explotarían; lo corremos explícito sin tenant.
    around_action :sin_tenant_benchmark_publico

    # GET /api/public/benchmark
    # Endpoint público para investigadores — datos totalmente anonimizados y agregados
    # Solo incluye clubes con benchmark_opt_in: true
    def show
      # `reales`: los clubes demo tienen datos inventados y no pueden entrar en un endpoint
      # público para investigadores.
      opted = Club.reales.where(benchmark_opt_in: true)
      total_clubes = opted.count

      unless total_clubes >= 3
        return render json: {
          disponible: false,
          razon: 'Se necesitan al menos 3 clubes participantes para publicar datos de benchmark.',
          clubes_participantes: total_clubes,
        }
      end

      hoy        = Date.today
      inicio_mes = hoy.beginning_of_month

      rendimientos = opted.flat_map do |c|
        c.lotes.where.not(estado: 'enraizado')
         .select { |l| l.rendimiento_real_g.present? }
         .map { |l| l.rendimiento_real_g.to_f }
      end

      dispens_mes_total = Dispensacion
        .joins(stock: :sede)
        .joins("INNER JOIN clubs ON sedes.club_id = clubs.id")
        .where(clubs: { benchmark_opt_in: true, demo: false })
        .where(fecha_dispensacion: inicio_mes..hoy)

      pacientes_total = Paciente
        .joins(:club)
        .where(clubs: { benchmark_opt_in: true, demo: false })
        .where(deleted_at: nil)
        .count

      gramos_mes = dispens_mes_total.sum(:cantidad).to_f.round(2)
      dispens_count = dispens_mes_total.count

      geneticas_distintas = opted.flat_map { |c|
        c.lotes.where.not(estado: 'enraizado').pluck(:genetica_id)
      }.uniq.size

      render json: {
        disponible:              true,
        generado_en:             Time.current.iso8601,
        clubes_participantes:    total_clubes,
        metricas: {
          pacientes_activos_total:   pacientes_total,
          rendimiento_promedio_g:    rendimientos.any? ? (rendimientos.sum / rendimientos.size).round(1) : nil,
          rendimiento_mediana_g:     rendimientos.any? ? mediana(rendimientos).round(1) : nil,
          rendimiento_min_g:         rendimientos.any? ? rendimientos.min.round(1) : nil,
          rendimiento_max_g:         rendimientos.any? ? rendimientos.max.round(1) : nil,
          gramos_dispensados_mes:    gramos_mes,
          dispensaciones_mes:        dispens_count,
          geneticas_distintas:       geneticas_distintas,
        },
        nota: 'Datos agregados y anonimizados. Ningún club es identificable individualmente.',
      }
    end

    private

    def sin_tenant_benchmark_publico
      ActsAsTenant.without_tenant { yield }
    end

    def mediana(arr)
      sorted = arr.sort
      mid    = sorted.length / 2
      sorted.length.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
    end
  end
end
