# Multi-tenancy a nivel modelo (TEN-01) — barrera primaria.
#
# require_tenant = true (TEN-01c, jul-2026): toda query a un modelo con acts_as_tenant
# SIN tenant fijado lanza ActsAsTenant::Errors::NoTenantSet en vez de devolver datos de
# todos los clubes. Convierte el "me olvidé de scopear" (bug silencioso, el peor en
# multi-tenant) en un error ruidoso e inmediato.
#
# Los contextos que corren legítimamente sin tenant están blindados explícitamente:
#   - jobs de Sidekiq → ActsAsTenant.with_tenant(club) { ... } (los 16 con datos de club)
#   - endpoints públicos → Public::BaseController (with_tenant(current_club) o without_tenant
#     según el modo :club/:token), Public::BenchmarkController → without_tenant
#   - super_admin → SuperAdmin::BaseController → without_tenant (cross-club a propósito)
#   - webhooks → Webhooks::LecturasController → without_tenant
#   - benchmark de plataforma → BenchmarkController#metricas_plataforma → without_tenant
#   - ActionCable → AmbienteChannel fija el tenant del usuario
#   - papelera (restauración cross-club) → without_tenant + verificación manual de club
#   - login / super_admin → set_tenant_from_current_user retorna sin fijar tenant
# En consola/rake/seeds usar: ActsAsTenant.with_tenant(Club.find(id)) { ... }.
ActsAsTenant.configure do |config|
  config.require_tenant = true
end
