# Multi-tenancy a nivel modelo (TEN-01) — defensa en profundidad.
#
# require_tenant = false a propósito: el scoping es ADITIVO. Cuando hay un tenant
# seteado (todo request autenticado de un usuario de club), las queries de los
# modelos con acts_as_tenant se filtran automáticamente por club_id. Cuando NO hay
# tenant (jobs de Sidekiq, endpoints públicos/webhooks, super_admin cross-club, login),
# las queries quedan sin scope → mismo comportamiento que hoy, sin romper nada.
#
# Endurecer a require_tenant = true es un paso posterior que exige envolver los 18
# jobs en ActsAsTenant.with_tenant(club) { ... }. Ver SECURITY_AUDIT.md (TEN-01b).
ActsAsTenant.configure do |config|
  config.require_tenant = false
end
