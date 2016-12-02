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
    req = Rack::Request.new(env)
    body = req.body.read
    resp = HttpPack.parse_body('testuser', body) do |scope, payload|
        puts payload
        if payload == 'do you copy?'
            HttpPack.commit(scope, 'roger that', qos = 0)
            HttpPack.commit(scope, 'roger that', qos = 1)
            HttpPack.commit(scope, 'roger that', qos = 2)
        end
    end
    [200, {'Content-Type' => 'application/octet-stream'}, [resp]]
end

Rack::Handler::WEBrick.run(app, :Host => '0.0.0.0', :Port => 8080)