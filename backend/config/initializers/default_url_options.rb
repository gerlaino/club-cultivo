# Host para las URLs que se generan FUERA de un request: mails, jobs, PDFs. Dentro de un request
# Rails usa el host real, así que esto solo aplica a lo que corre en segundo plano.
#
# Los initializers cargan DESPUÉS de `config/environments/*.rb`, así que este archivo pisaba lo que
# producción ya había configurado: los mails salían con links a `localhost:3001`.
#
# `APP_HOST` es el que manda (ej. cultivoespacial.com). Solo se cae a localhost si no está definido,
# que es el caso de desarrollo.
host = ENV['APP_HOST'].presence

if host
  # Con dominio propio siempre es HTTPS: un link http en un mail dispara la advertencia del cliente
  # de correo y encima pierde la cookie (que es `secure`).
  Rails.application.routes.default_url_options[:host]     = host
  Rails.application.routes.default_url_options[:protocol] = 'https'
  Rails.application.config.action_mailer.default_url_options = { host: host, protocol: 'https' }
else
  Rails.application.routes.default_url_options[:host] = 'localhost:3001'
  Rails.application.config.action_mailer.default_url_options = { host: 'localhost', port: 3001 }
end
