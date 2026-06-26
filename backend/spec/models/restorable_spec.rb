require 'rails_helper'

# Fundación del soft-delete unificado: la papelera habla con RestorableInterface, que debe
# comportarse igual sobre los dos mecanismos que conviven — gema paranoia (modelos nuevos del
# set curado) y patrón manual deleted_at (legacy: lote/plant/sala/sede/club).
RSpec.describe 'RestorableInterface', type: :model do
  let(:club) { create(:club) }

  shared_examples 'soft-delete restaurable' do
    it 'se oculta del scope por defecto, aparece en soft_deleted_records y se restaura' do
      record = subject
      id = record.id

      borrar.call(record)

      expect(described_class.where(id: id)).to be_empty                 # default scope lo oculta
      expect(described_class.soft_deleted_records.where(id: id)).to exist
      expect(described_class.find_soft_deleted(id).soft_deleted?).to be true

      described_class.find_soft_deleted(id).restore_record!

      expect(described_class.where(id: id)).to exist                    # vuelve a estar vigente
    end
  end

  describe Genetica do # paranoia (gema)
    subject { create(:genetica, club: club) }
    let(:borrar) { ->(r) { r.destroy } }
    include_examples 'soft-delete restaurable'
  end

  describe Sala do # manual (deleted_at + default_scope)
    subject { create(:sala, club: club) }
    let(:borrar) { ->(r) { r.soft_delete! } }
    include_examples 'soft-delete restaurable'
  end
end
