require 'deep_clone'

require "http_pack/version"
require "http_pack/protocol"
require "http_pack/redis_connection"
require "http_pack/lua_scripts"

module HttpPack

  include Protocol::Constant
  include LuaScripts

  def self.configure
    yield self if block_given?
  end

  def self.redis_pool
    @redis ||= RedisConnection.create
  end

  def self.redis
    raise ArgumentError, 'requires a block' unless block_given?
    redis_pool.with do |conn|
      retryable = true
      begin
        yield conn
      rescue Redis::CommandError => ex
        (conn.disconnect!; retryable = false; retry) if retryable && ex.message =~ /READONLY/
        raise
      end
    end
  end

  def self.parse_body(scope, body)
    packs = split(body)
    packs.each do |pack|
      if pack[:msg_type] == MSG_TYPE_SEND
        if pack[:qos] == QoS0
          yield scope, pack[:payload]
        elsif pack[:qos] == QoS1
          reply = Protocol.encode(MSG_TYPE_ACK, QoS0, 0, pack[:msg_id])
          save(scope, reply)
          yield scope, pack[:payload]
        elsif pack[:qos] == QoS2
          receive(scope, pack[:msg_id], pack[:payload])
          reply = Protocol.encode(MSG_TYPE_RECEIVED, QoS0, 0, pack[:msg_id])
          save(scope, reply)
        end
      elsif pack[:msg_type] == MSG_TYPE_ACK
        confirm(scope, pack[:msg_id])
      elsif pack[:msg_type] == MSG_TYPE_RECEIVED
        confirm(scope, pack[:msg_id])
        reply = Protocol.encode(MSG_TYPE_RELEASE, QoS1, 0, pack[:msg_id])
        save(scope, reply)
      elsif pack[:msg_type] == MSG_TYPE_RELEASE
        payload = release(scope, pack[:msg_id])
        unless payload.nil?
          yield scope, payload
        end
        reply = Protocol.encode(MSG_TYPE_COMPLETED, QoS0, 0, pack[:msg_id])
        save(scope, reply)
      end
    end

    # reply

    replys = unconfirmed(scope, max_response_number)
    replys.each do |pack|
      retry_pack = retry_(pack)
      unless retry_pack.nil?
        save(scope, retry_pack)
      end
    end

    combine(replys)
  end

  def self.retry_(pack)
    unless pack[:qos] == QoS0
      retry_pack = nil
      if !pack[:retry_times].nil? && pack[:retry_times] > 0
        retry_pack = DeepClone.clone pack
        retry_pack[:retry_times]++
        retry_pack[:timestamp] = Time.now + retry_pack[:retry_times] * 5
      else
        retry_pack = Protocol.encode(pack.msg_type, pack[:qos], 1, pack[:msg_id], pack[:payload])
        retry_pack[:retry_times] = 1
        retry_pack[:timestamp] = Time.now + retry_pack[:retry_times] * 5
      end
      retry_pack
    end
  end

  def self.commit(scope, data, qos = 0)
    pack = Protocol.encode(MSG_TYPE_SEND, qos, 0, uniqueId, data)
    save(scope, pack)
  end

  def self.redis_url=(redis_url)
    @redis_url = redis_url
  end

  def self.redis_url
    @redis_url
  end

  def self.redis_namespace=(redis_namespace)
    @redis_namespace = redis_namespace
  end

  def self.redis_namespace
    @redis_namespace
  end

  def self.redis_size=(redis_size)
    @redis_size = redis_size
  end

  def self.redis_size
    @redis_size
  end

  def self.redis_pool_timeout=(redis_pool_timeout)
    @redis_pool_timeout = redis_pool_timeout
  end

  def self.redis_pool_timeout
    @redis_pool_timeout
  end

  def self.network_timeout=(network_timeout)
    @network_timeout = network_timeout
  end

  def self.network_timeout
    @network_timeout
  end

  def self.max_response_number=(max_response_number)
    @max_response_number = max_response_number
  end

  def self.max_response_number
    @max_response_number
  end

  private

  def self.split(buffer)
    packs = []
    buffer = buffer.force_encoding('ASCII-8BIT')
    offset = 0
    while buffer.bytesize > offset do
      pack, offset = Protocol.decode(buffer, offset)
      packs << pack
    end
    packs
  end

  def self.combine(packs)
    packs.map{ |pack| pack[:buffer] }.join('')
  end

  def self.max_response_number
    @max_response_number ||= 20
  end

  # Redis Operate

  def self._encode_redis_value(pack)
    confirm = pack[:confirm] || 0
    retry_times = pack[:retry_times] || 0
    timestamp = pack[:timestamp] || Time.at(0)
    timestamp = timestamp.to_i
    buffer = ''
    buffer << confirm << ':' << retry_times << ':'
    buffer << timestamp << ':' << pack[:buffer]
    buffer
  end

  def self._decode_redis_value(buffer)
    confirm, buffer = buffer.split(':', 2)
    if buffer.nil?
      raise 'Error encode string'
    end
    retry_times, buffer = buffer.split(':', 2)
    if buffer.nil?
      raise 'Error encode string'
    end
    timestamp, buffer = buffer.split(':', 2)
    if buffer.nil?
      raise 'Error encode string'
    end
    timestamp = Time.at(timestamp.to_i)
    buffer = buffer.force_encoding('ASCII-8BIT')
    pack, _ = Protocol.decode(buffer)
    pack[:confirm] = confirm
    pack[:retry_times] = retry_times
    pack[:timestamp] = timestamp
    pack
  end

  def self.eval_score(pack)
    confirm = pack[:confirm] || 0
    timestamp = pack[:timestamp] || Time.at(0)
    timestamp = timestamp.to_i
    if confirm then timestamp else 0 end
  end

  def self.uniqueId(scope)
    redis do |conn|
      conn.incr("#{scope}:uniqueid")
    end
  end

  def self.save(scope, pack)
    pack[:confirm] = false
    redis do |conn|
      conn.eval(PQADD, [scope], [eval_score(pack), pack[:msg_id], _encode_redis_value(pack)])
    end
  end

  def self.unconfirmed(scope, limit)
    redis do |conn|
      buffers = conn.eval(PQPOP, [scope], [limit])
      buffers.map do |buffer|
        _decode_redis_value(buffer)
      end
    end
  end

  def self.confirm(scope, msg_id)
    redis do |conn|
      conn.eval(PQREM, [scope], [msg_id])
    end
  end

  def self.receive(scope, msg_id, payload)
    redis do |conn|
      conn.hset("#{scope}:payloads", msg_id, payload)
    end
  end

  def self.release(scope, msg_id)
    redis do |conn|
      conn.hget("#{scope}:payloads", msg_id)
    end
  end

end
