require 'spec_helper'
ENV['RAILS_ENV'] = 'test'
require_relative '../config/environment'
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'factory_bot_rails'
require 'faker'
require 'shoulda/matchers'
require 'database_cleaner/active_record'

Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

ActiveRecord::Encryption.configure(
  primary_key:         'test_primary_key_32_bytes_pad00000',
  deterministic_key:   'test_deterministic_key_32bytes000',
  key_derivation_salt: 'test_key_derivation_salt_32bytes0'
)

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::IntegrationHelpers, type: :request

  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library        :rails
  end
end
