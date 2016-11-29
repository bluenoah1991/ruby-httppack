require "http_pack/version"

module HttpPack
  
  include Protocol::Constant

  def self.configure
    yield self if block_given?
  end

  def self.redis_pool
    @redis ||= RedisConnection.create
  end

  def self.parse_body(scope, body)
    packs = split(body)
    packs.each do |pack|
      if pack.msg_type == MSG_TYPE_SEND
        if pack.qos == QoS0
          yield scope, pack.payload
        elsif pack.qos == QoS1
          reply = Protocol.encode(MSG_TYPE_ACK, QoS0, 0, pack.msg_id)
          save(scope, reply)
        elsif pack.qos == QoS2
          receive(scope, pack.msg_id, pack.payload)
          reply = Protocol.encode(MSG_TYPE_RECEIVED, QoS0, 0, pack.msg_id)
          save(scope, reply)
        end
      elsif pack.msg_type == MSG_TYPE_ACK
        confirm(scope, pack.msg_id)
      elsif pack.msg_type == MSG_TYPE_RECEIVED
        confirm(scope, pack.msg_id)
        reply = Protocol.encode(MSG_TYPE_RELEASE, QoS1, 0, pack.msg_id)
        save(scope, reply)
      elsif pack.msg_type == MSG_TYPE_RELEASE
        payload = release(scope, pack.msg_id)
        if payload.present?
          yield scope, payload
        end
        reply = Protocol.encode(MSG_TYPE_COMPLETED, QoS0, 0, pack.msg_id)
        save(scope, reply)
      end
    end

    # reply

    replys = unconfirmed(scope, max_response_number)
    replys.each do |pack|
      retry_pack = retry(pack)
      if retry_pack.present?
        save(scope, retry_pack)
      end
    end

    combine(replys)
  end

  def self.commit(scope, data, qos = 0)
    pack = Protocol.encode(MSG_TYPE_SEND, qos, 0, uniqueId, data)
    save(scope, pack)
  end

  private

  def self.split(buffer)
    packs = []
    buffer = buffer.force_encoding('ASCII-8BIT')
    while buffer.bytesize > 0 do
      pack = Protocol.decode(buffer)
      packs << pack
    end
    packs
  end

  def self.combine(packs)
    packs.map{ |pack| Protocol.encode(pack).buffer }.join('')
  end

  def self.max_response_number
    @max_response_number ||= 20
  end

  def retry(pack)
    unless pack.qos == QoS0
      if pack.retry_times.present? && pack.retry_times > 0
        retry_pack = DeepClone.clone pack
        retry_pack.retry_times++
        retry_pack.timestamp = Time.now + retry_pack.retry_times * 5
      else
        retry_pack = Protocol.encode(pack.msg_type, pack.qos, 1, pack.msg_id, pack.payload)
        retry_pack.retry_times = 1
        retry_pack.timestamp = Time.now + retry_pack.retry_times * 5
      end
    end
  end

  # Redis Operate

  def self.uniqueId(scope)

  end

  def self.save(scope, pack)

  end

  def self.unconfirmed(scope, limit)

  end

  def self.confirm(scope, msg_id)

  end

  def self.receive(scope, msg_id, payload)

  end

  def self.release(scope, msg_id)

  end

end
