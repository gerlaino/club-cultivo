# Genera un Club Modelo desde el panel de plataforma. Corre en segundo plano porque sembrar doce
# meses de historia en todos los módulos tarda más que lo que aguanta un request: quien lo pidió
# recibe la contraseña en el acto y la organización aparece en la lista cuando termina.
#
# Si falla, queda en la cola de muertos de Sidekiq (se ve en Salud del panel) y no queda una
# organización a medio sembrar: `Clubs::SembrarDemo` es todo o nada.
class SembrarDemoJob < ApplicationJob
  queue_as :default

  def perform(nombre:, slug:, admin_password:)
    ActsAsTenant.without_tenant do
      Clubs::SembrarDemo.call(nombre: nombre, slug: slug, admin_password: admin_password)
    end
  end
end
