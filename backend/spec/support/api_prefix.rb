module ApiPrefix
  %w[get post put patch delete head].each do |verb|
    define_method(verb) do |path, **kwargs|
      prefixed = path.start_with?('/api', '/webhooks', '/p/', 'http') ? path : "/api#{path}"
      super(prefixed, **kwargs)
    end
  end
end

RSpec.configure do |config|
  config.include ApiPrefix, type: :request
end
