require 'rails_helper'
require 'yaml'

# TODA FILA QUE USE UN JOB TIENE QUE ESTAR EN LO QUE ATIENDE EL WORKER (2-oct-2026).
#
# `PushNotificationJob`, `RecordatoriosTareasJob` y `OutgoingWebhookJob` iban a la fila `medium`, que
# `config/sidekiq.yml` no listaba: el worker no la miraba, los trabajos esperaban para siempre y no
# había ningún error en ningún lado. En producción las notificaciones push quedaron 14 días sin salir.
# Se lee la fuente real (los `queue_as` de app/), no una lista escrita de memoria.
RSpec.describe 'Filas de Sidekiq' do
  let(:atendidas) do
    YAML.load_file(Rails.root.join('config/sidekiq.yml'))[:queues].map { |q| Array(q).first.to_s }
  end

  let(:usadas) do
    Dir[Rails.root.join('app/{jobs,mailers}/**/*.rb')].flat_map do |f|
      File.read(f).scan(/queue_as\s+:(\w+)|sidekiq_options\s+.*queue:\s*:?['"]?(\w+)/).flatten.compact
    end.uniq
  end

  it 'el worker atiende todas las filas que usan los jobs' do
    expect(usadas - atendidas).to eq([]), "filas que nadie atiende: #{(usadas - atendidas).join(', ')}"
  end

  it 'y la de los mails de ActiveJob (deliver_later)' do
    expect(atendidas).to include('mailers', 'default')
  end
end
