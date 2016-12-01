require 'connection_pool'
require 'redis'
require 'redis-namespace'

class HttpPack::RedisConnection

    class << self
        def symbolize_keys(h)
            h.inject({}) do |memo, (k, v)|
                memo[k.to_sym] = v
            end
        end

        def create(options={})
            options = symbolize_keys(options)

            options[:url] = determine_redis_provider

            namespace = HttpPack.redis_namespace || 'httppack'; 
            size = HttpPack.redis_size || 5;
            pool_timeout = HttpPack.redis_pool_timeout || 1;
            unless HttpPack.network_timeout.nil?
                options[:timeout] = HttpPack.network_timeout
            end

            ConnectionPool.new(:timeout => pool_timeout, :size => size) do
                client = Redis.new options

                unless namespace.nil? && namespace.empty?
                    Redis::Namespace.new(namespace, :redis => client)
                else
                    client
                end
            end
        end

        private

        def determine_redis_provider
            HttpPack.redis_url ||= (ENV['REDIS_URL'] || 'redis://localhost:6379/0')
        end
    end

end