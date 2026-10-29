# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn
]

# LOS DATOS DE LAS PERSONAS NO VAN A LOS LOGS (LOG-01, 29-oct-2026).
#
# Rails escribe los parámetros de cada pedido en el log, y el log de Render lo lee cualquiera con
# acceso al panel y se guarda fuera de la base cifrada. Hasta hoy, cargar o editar un paciente dejaba
# ahí su DNI, nombre, teléfono y diagnósticos en texto plano. Coincidencia parcial: `diagnostico`
# tapa `diagnostico_principal` y `diagnostico_secundario`.
Rails.application.config.filter_parameters += [
  # Quién es y dónde vive
  :dni, :documento, :cuit, :cbu, :telefono, :phone, :celular, :whatsapp,
  :domicilio, :direccion, :envio_, :fecha_nacimiento, :reprocann,
  /\A(paciente|socio)\.(nombre|apellido|apodo)\z/,
  # Lo clínico
  :notas_clinicas, :motivo_consulta, :anamnesis, :antecedentes, :diagnostico, :evolucion_clinica,
  :alergias, :medicacion, :grupo_sanguineo, :patologia, :dosificacion, :via_administracion,
  :contenido_html, :firma,
  # Lo que escribe la persona (chat del portal, búsquedas por nombre o DNI)
  :texto, :mensaje, /\Aq\z/
]
