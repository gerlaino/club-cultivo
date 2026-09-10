class InformeSemestralController < ApplicationController
  include DeclaracionInaseGuard
  before_action :authenticate_user!
  before_action :require_admin_or_autorizado!

  # GET /informe_semestral
  def show
    hoy      = Time.zone.today
    anio     = (params[:anio]     || hoy.year).to_i
    semestre = (params[:semestre] || (hoy.month <= 6 ? 1 : 2)).to_i

    datos = InformeSemestralService.new(current_user.club, anio: anio, semestre: semestre).call
             .merge(generado_por: "#{current_user.first_name} #{current_user.last_name}".strip)

    respond_to do |format|
      format.json { render json: datos }
      # PDF de servidor: se generaba con html2canvas (una foto de la pantalla) y este es el
      # documento que se presenta ante la autoridad.
      format.pdf do
        # Este es EL documento que se presenta ante la autoridad — pero presentarlo es un acto
        # aparte, y la app no lo hace. Sale igual, con la salvedad; sólo frena si quien descarga
        # dijo que es para presentar.
        next if bloquear_descarga_si_falta_declarar!

        pdf = InformeSemestralDocument.new(club: current_user.club, usuario: current_user, datos: datos,
                                           salvedad_inase: salvedad_inase).render
        send_data pdf,
                  filename: "REPROCANN_#{semestre}S_#{anio}_#{current_user.club.slug}.pdf",
                  type: 'application/pdf', disposition: 'attachment'
      end
      format.xlsx do
        next if bloquear_descarga_si_falta_declarar!

        nomina = Array(datos[:pacientes][:nomina])
        xlsx = XlsxExport.new(
          club: current_user.club,
          titulo: "Informe semestral REPROCANN — #{semestre}° semestre #{anio}",
          subtitulo: "Período #{datos[:periodo][:desde]} — #{datos[:periodo][:hasta]}",
          # La salvedad viaja también en el Excel: el recuadro del PDF no existe acá, y el que se
          # baja el Excel tiene que enterarse igual.
          resumen: {
            'Pacientes'      => datos[:pacientes][:total],
            'Con REPROCANN'  => datos[:pacientes][:con_reprocann],
            'Vencidos'       => datos[:pacientes][:vencidos],
            'Gramos dispensados' => datos[:dispensaciones][:total_gramos],
          }.merge(
            salvedad_inase ? { 'Variedades sin acreditar ante el INASE' => salvedad_inase.join(', ') } : {}
          ),
          headers: ['Paciente', 'DNI', 'Nacimiento', 'N° REPROCANN', 'Vence', 'Estado'],
          formatos: [:texto, :texto, :fecha, :texto, :fecha, :texto],
          rows: nomina.map { |s|
            [s[:nombre_completo], s[:dni], s[:fecha_nacimiento], s[:reprocann_numero],
             s[:reprocann_vencimiento], s[:reprocann_vigente] ? 'Vigente' : 'No vigente']
          },
        ).render
        send_data xlsx,
                  filename: "REPROCANN_#{semestre}S_#{anio}_#{current_user.club.slug}.xlsx",
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  disposition: 'attachment'
      end
    end
  end

  private

  def require_admin_or_autorizado!
    unless current_user.admin? || current_user.role.in?(%w[auditor])
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end
end
