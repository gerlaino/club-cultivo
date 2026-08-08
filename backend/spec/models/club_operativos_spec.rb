require 'rails_helper'

# `activos` sólo mira deleted_at: un club SUSPENDIDO lo pasaba. Los jobs que producen efectos
# hacia afuera (alertas, mails, push) tienen que usar `operativos`.
RSpec.describe Club, type: :model do
  describe '.operativos' do
    let!(:normal)     { create(:club) }
    let!(:suspendido) { create(:club).tap(&:suspender!) }
    let!(:eliminado)  { create(:club).tap { |c| c.update!(deleted_at: Time.current) } }

    it 'incluye sólo al club que ni está suspendido ni eliminado' do
      expect(Club.operativos).to contain_exactly(normal)
    end

    it 'deja afuera al suspendido, que `activos` sí devolvía' do
      expect(Club.activos).to include(suspendido)
      expect(Club.operativos).not_to include(suspendido)
    end

    it 'vuelve a incluirlo cuando se reactiva' do
      suspendido.reactivar!
      expect(Club.operativos).to include(suspendido)
    end
  end
end
