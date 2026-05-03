require 'rails_helper'

RSpec.describe Ambiente::VpdCalculator do
  describe '.call' do
    it 'returns correct VPD for 25°C and 60%RH' do
      result = described_class.call(temperatura: 25, humedad: 60)
      expect(result).to be_within(0.01).of(1.267)
    end

    it 'returns 0 at 100% humidity' do
      result = described_class.call(temperatura: 25, humedad: 100)
      expect(result).to eq(0.0)
    end

    it 'returns higher VPD at lower humidity' do
      low_hr  = described_class.call(temperatura: 25, humedad: 40)
      high_hr = described_class.call(temperatura: 25, humedad: 70)
      expect(low_hr).to be > high_hr
    end
  end
end
