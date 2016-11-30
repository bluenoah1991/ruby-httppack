require 'rack'
require 'pry'

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'http_pack'

# configure
HttpPack.configure do |config|
    config.redis_url = 'redis://localhost:6379/0'
    config.redis_namespace = 'httppack_test'
    config.redis_size = 1
    config.redis_pool_timeout = 5
    config.network_timeout = 1000
    config.max_response_number = 20
end

app = Proc.new do |env|
    binding.pry
    req = Rack::Request.new(env)
    body = req.body.read
    HttpPack.parse_body('testuser', body) do |scope, payload|
        binding.pry
    end
end

Rack::Handler::WEBrick.run(app, :Host => '0.0.0.0', :Port => 8080)