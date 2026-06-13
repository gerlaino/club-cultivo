# Contexto por-request (thread-safe). Hoy solo lleva el usuario actual,
# usado por el concern Auditable para registrar quién hizo cada cambio.
class Current < ActiveSupport::CurrentAttributes
  attribute :user
end
