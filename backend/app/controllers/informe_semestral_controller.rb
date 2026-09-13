class InformeSemestralController < ApplicationController
  include DeclaracionInaseGuard
  before_action :authenticate_user!
  before_action :require_admin_or_autorizado!

  # GET /informe_semestral?anio=&semestre=
  #
  # La declaración jurada semestral. El cálculo vive en `Informes::Semestral`, que compone los
  # informes ya revisados con el semestre como período; acá sólo se arma cada salida.
  def show
    hoy      = Time.zone.today
    anio     = (params[:anio]     || hoy.year).to_i
    semestre = (params[:semestre] || (hoy.month <= 6 ? 1 : 2)).to_i

    datos = Informes::Semestral.new(club: current_user.club, anio: anio, semestre: semestre).call
             .merge(generado_por: current_user.nombre_completo)

    respond_to do |format|
      # EL DNI VA COMPLETO EN LO QUE SE DESCARGA Y PARCIAL EN LA PANTALLA, como en REPROCANN: la
      # pantalla la mira cualquiera que pase por atrás; el archivo se presenta.
      format.json { render json: sin_dni_completo(datos) }
      # Este es EL documento que se presenta ante la autoridad — pero presentarlo es un acto
      # aparte, y la app no lo hace. Sale igual, con la salvedad; sólo frena si quien descarga dijo
      # que es para presentar. La salvedad y el candado miran lo que APARECE en el documento.
      format.pdf do
        next if bloquear_descarga_si_falta_declarar!(ids: datos[:geneticas_sin_vincular_ids])

        pdf = InformeSemestralDocument.new(club: current_user.club, usuario: current_user, datos: datos,
                                           salvedad_inase: salvedad_inase(ids: datos[:geneticas_sin_vincular_ids])).render
        send_data pdf, filename: "#{nombre_archivo(anio, semestre)}.pdf",
                  type: 'application/pdf', disposition: 'attachment'
      end
      format.xlsx do
        next if bloquear_descarga_si_falta_declarar!(ids: datos[:geneticas_sin_vincular_ids])

        send_data xlsx(datos, anio, semestre), filename: "#{nombre_archivo(anio, semestre)}.xlsx",
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  disposition: 'attachment'
      end
    end
  end

  private

  def nombre_archivo(anio, semestre) = "declaracion_semestral_#{semestre}S_#{anio}_#{current_user.club.slug}"

  def sin_dni_completo(datos)
    pac = datos[:pacientes]
    datos.merge(pacientes: pac.merge(
      nomina:          pac[:nomina].first(Informes::Reprocann::LISTA_PANTALLA).map { |p| p.except(:dni) },
      nomina_omitidos: [pac[:nomina].size - Informes::Reprocann::LISTA_PANTALLA, 0].max,
    ))
  end

  ESTADO_LABEL = { 'vigente' => 'Vigente', 'por_vencer' => 'Vigente', 'vencido' => 'Vencido',
                   'pendiente' => 'En trámite', 'sin_reprocann' => 'Sin número' }.freeze

  def xlsx(datos, anio, semestre)
    pac = datos[:pacientes]
    per = datos[:periodo]
    ent = datos[:entregas]
    resumen = {
      'Pacientes registrados'   => pac[:registrados],
      'Vigentes al cierre'      => pac[:vigentes],
      'Vencidos al cierre'      => pac[:vencidos],
      'En trámite'              => pac[:en_tramite],
      'Sin registro (no se presentan)' => pac[:sin_registro],
      'Lotes cosechados'        => datos[:cultivo][:cosechados][:lotes],
      'Flor seca cosechada (g)' => datos[:cultivo][:cosechados][:gramos],
      'Entregas'                => ent[:entregas],
    }
    ent[:por_unidad].each { |u| resumen["Entregado (#{u[:unidad]})"] = u[:cantidad] }
    # La salvedad viaja también en el Excel: el recuadro del PDF no existe acá.
    pendientes = salvedad_inase(ids: datos[:geneticas_sin_vincular_ids])
    resumen['Variedades sin vinculación INASE'] = pendientes.join(', ') if pendientes

    XlsxExport.new(
      club: current_user.club,
      titulo: "Declaración jurada semestral REPROCANN — #{semestre}° semestre #{anio}",
      subtitulo: "Período #{per[:desde].strftime('%d/%m/%Y')} — #{per[:hasta].strftime('%d/%m/%Y')} · población al #{per[:al].strftime('%d/%m/%Y')}",
      resumen: resumen,
      headers: ['Paciente', 'DNI', 'Nacimiento', 'N° REPROCANN', 'Vence', 'Estado al cierre'],
      formatos: [:texto, :texto, :fecha, :texto, :fecha, :texto],
      rows: pac[:nomina].map { |s|
        [s[:nombre_completo], s[:dni], s[:fecha_nacimiento], s[:reprocann_numero] || '—',
         s[:reprocann_vencimiento], ESTADO_LABEL[s[:reprocann_estado]] || s[:reprocann_estado]]
      },
    ).render
  end

  def require_admin_or_autorizado!
    unless current_user.admin? || current_user.role.in?(%w[auditor])
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end
end
