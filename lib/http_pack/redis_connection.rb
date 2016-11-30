class HttpPack::RedisConnection

    class << self
        def create(options={})
            options = options.symbolize_keys

            options[:url] = determine_redis_provider

            namespace = HttpPack.redis_namespace || 'httppack'; 
            size = HttpPack.redis_size || 5;
            pool_timeout = HttpPack.redis_pool_timeout || 1;
            if HttpPack.network_timeout.present?
                options[:timeout] = HttpPack.network_timeout
            end

            ConnectionPool.new(:timeout => pool_timeout, :size => size) do
                client = Redis.new options

                if namespace.present?
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