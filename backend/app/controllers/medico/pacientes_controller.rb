module Medico
  class PacientesController < BaseController
    before_action :set_paciente, only: [:ficha]

    # GET /api/medico/pacientes
    def index
      pacientes = club.pacientes
                      .where(deleted_at: nil)
                      .order(:apellido, :nombre)
                      .select(:id, :nombre, :apellido, :dni, :fecha_nacimiento,
                              :reprocann_numero, :reprocann_vencimiento, :reprocann_estado,
                              :diagnostico_principal, :diagnostico_secundario,
                              :con_seguimiento_medico)

      render json: pacientes.map { |p| serialize_paciente_resumen(p) }
    end

    # GET /api/medico/pacientes/:id/ficha
    def ficha
      indicacion = @paciente.indicacion_medicas
                             .where(activa: true)
                             .order(fecha_emision: :desc)
                             .first

      proximo_turno = club.turnos
                          .del_medico(current_user.id)
                          .where(paciente_id: @paciente.id)
                          .proximos
                          .first

      dispensaciones = @paciente.dispensaciones
                                .includes(stock: :genetica)
                                .order(fecha_dispensacion: :desc)
                                .limit(20)

      check_ins_map = @paciente.check_ins
                               .where.not(dispensacion_id: nil)
                               .index_by(&:dispensacion_id)

      disp_serialized = dispensaciones.map do |d|
        genetica = d.stock&.genetica
        {
          id:              d.id,
          fecha:           d.fecha_dispensacion,
          cantidad_g:      d.cantidad.to_f,
          forma_producto:  d.stock&.forma_producto,
          genetica:        genetica ? serialize_genetica(genetica) : nil,
          check_in:        check_ins_map[d.id] ? serialize_check_in(check_ins_map[d.id]) : nil,
        }
      end

      # Resumen consumo últimos 90 días
      disp_90d = @paciente.dispensaciones.no_canceladas
                          .where('fecha_dispensacion >= ?', 90.days.ago)
      total_90d  = disp_90d.sum(:cantidad).to_f
      prom_mens  = (total_90d / 3.0).round(1)

      render json: {
        paciente:           serialize_paciente_ficha(@paciente),
        indicacion_activa:  indicacion ? serialize_indicacion(indicacion) : nil,
        proximo_turno:      proximo_turno ? serialize_turno(proximo_turno) : nil,
        dispensaciones:     disp_serialized,
        total_dispensaciones: @paciente.dispensaciones.no_canceladas.count,
        resumen_consumo: {
          total_g_90d:          total_90d,
          promedio_mensual_g:   prom_mens,
          total_dispensaciones: disp_90d.count,
        },
      }
    end

    private

    def set_paciente
      @paciente = club.pacientes.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Paciente no encontrado' }, status: :not_found
    end

    def serialize_paciente_resumen(p)
      hoy = Date.today
      venc = p.reprocann_vencimiento
      dias = venc ? (venc - hoy).to_i : nil
      {
        id:                   p.id,
        nombre:               p.nombre,
        apellido:             p.apellido,
        nombre_completo:      "#{p.nombre} #{p.apellido}",
        dni:                  p.dni,
        edad:                 hoy.year - p.fecha_nacimiento.year - (hoy < p.fecha_nacimiento + (hoy.year - p.fecha_nacimiento.year).years ? 1 : 0),
        diagnostico_principal: p.diagnostico_principal,
        reprocann_estado:     p.reprocann_estado,
        reprocann_vencimiento: venc,
        dias_hasta_vencimiento: dias,
        con_seguimiento:      p.con_seguimiento_medico,
      }
    end

    def serialize_paciente_ficha(p)
      hoy = Date.today
      venc = p.reprocann_vencimiento
      dias = venc ? (venc - hoy).to_i : nil
      {
        id:                       p.id,
        nombre:                   p.nombre,
        apellido:                 p.apellido,
        nombre_completo:          "#{p.nombre} #{p.apellido}",
        dni:                      p.dni,
        email:                    p.email,
        telefono:                 p.telefono,
        fecha_nacimiento:         p.fecha_nacimiento,
        edad:                     hoy.year - p.fecha_nacimiento.year,
        reprocann_numero:         p.reprocann_numero,
        reprocann_vencimiento:    venc,
        reprocann_estado:         p.reprocann_estado,
        dias_hasta_vencimiento:   dias,
        diagnostico_principal:    p.diagnostico_principal,
        diagnostico_secundario:   p.diagnostico_secundario,
        motivo_consulta:          p.motivo_consulta,
        anamnesis:                p.anamnesis,
        antecedentes_personales:  p.antecedentes_personales,
        antecedentes_familiares:  p.antecedentes_familiares,
        medicacion_habitual:      p.medicacion_habitual,
        alergias:                 p.alergias,
        notas_clinicas:           p.notas_clinicas,
        grupo_sanguineo:          p.grupo_sanguineo,
        con_seguimiento:          p.con_seguimiento_medico,
      }
    end

    def serialize_genetica(g)
      quimiotipo = calcular_quimiotipo(g.thc, g.cbd)
      {
        id:         g.id,
        nombre:     g.nombre,
        thc:        g.thc&.to_f,
        cbd:        g.cbd&.to_f,
        tipo:       g.tipo,
        terpenos:   g.terpenos,
        quimiotipo: quimiotipo,
      }
    end

    def calcular_quimiotipo(thc, cbd)
      return nil unless thc && cbd
      thc_f = thc.to_f
      cbd_f = cbd.to_f
      return 'III' if thc_f < 1.0 && cbd_f >= 1.0
      return 'I'   if thc_f >= 1.0 && cbd_f < 1.0
      return 'II'  if thc_f >= 1.0 && cbd_f >= 1.0
      nil
    end

    def serialize_check_in(ci)
      {
        id:               ci.id,
        escala_bienestar: ci.escala_bienestar,
        sintomas:         ci.sintomas,
        notas:            ci.notas,
        via_registro:     ci.via_registro,
        fecha:            ci.created_at.to_date,
      }
    end

    def serialize_indicacion(ind)
      {
        id:                  ind.id,
        patologia:           ind.patologia,
        dosificacion:        ind.dosificacion,
        via_administracion:  ind.via_administracion,
        fecha_emision:       ind.fecha_emision,
        fecha_vencimiento:   ind.fecha_vencimiento,
        observaciones:       ind.observaciones,
      }
    end

    def serialize_turno(t)
      {
        id:          t.id,
        fecha_hora:  t.fecha_hora,
        tipo:        t.tipo,
        estado:      t.estado,
        motivo:      t.motivo,
      }
    end
  end
end
