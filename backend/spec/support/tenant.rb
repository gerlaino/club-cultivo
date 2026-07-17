# Multi-tenancy en tests (TEN-01c: require_tenant=true).
#
# Con require_tenant=true, crear/consultar cualquier modelo acts_as_tenant SIN un tenant
# fijado lanza ActsAsTenant::Errors::NoTenantSet. La enorme mayoría de los specs arma sus
# fixtures alrededor de un único `let(:club)`; este hook lo fija como tenant durante cada
# ejemplo, así no hay que repetir `before { ActsAsTenant.current_tenant = club }` en cada
# archivo (patrón que se venía copiando spec por spec desde el flip).
#
# Los specs que ejercitan varios clubes a la vez (aislamiento cross-tenant) NO definen un
# `let(:club)` — usan club_a/club_b y fijan el tenant a mano con ActsAsTenant.with_tenant —
# por eso este hook no los toca (respond_to?(:club) es false para ellos).
#
# En specs de request el controller vuelve a fijar el tenant real por-request; acá solo nos
# aseguramos de que el ARMADO de fixtures (los `let`/`before`) tenga un tenant válido.
# Usamos ActsAsTenant.test_tenant (no current_tenant): el TestTenantMiddleware lo guarda y
# restaura alrededor de cada request, así el tenant SOBREVIVE al request. Con current_tenant,
# el request lo limpia al terminar y las aserciones del body posteriores al `post`/`get`
# quedaban sin tenant (→ NoTenantSet). test_tenant es el mecanismo del gem justo para esto.
RSpec.configure do |config|
  config.before(:each) do
    if respond_to?(:club) && (c = club).is_a?(Club)
      ActsAsTenant.test_tenant = c
    end
  end

  config.after(:each) do
    ActsAsTenant.test_tenant = nil
  end
end
