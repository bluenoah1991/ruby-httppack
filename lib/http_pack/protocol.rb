module HttpPack::Protocol

    module Constant
        MSG_TYPE_SEND = 0x1
        MSG_TYPE_ACK = 0x2;
        MSG_TYPE_RECEIVED = 0x3;
        MSG_TYPE_RELEASE = 0x4;
        MSG_TYPE_COMPLETED = 0x5;

        QoS0 = 0;
        QoS1 = 1;
        QoS2 = 2;
    end

    include Constant

    # payload is string
    self.encode(msg_type = 0x1, qos = 0, dup = 0, msg_id = 0, payload = nil, offset = 0, remaining_length = nil)
        if payload.present?
            remaining_length ||= payload.bytesize
        else
            remaining_length = 0
        end
        buffer = ''
        fixed_header = (msg_type << 4) | (qos << 2) | (dup << 1)
        buffer << encode_bytes(fixed_header)
        buffer << encode_short(msg_id)
        buffer << encode_short(remaining_length)
        if payload.present?
            buffer << payload
        end
        {
            msg_type: msg_type,
            qos: qos,
            dup: dup,
            msg_id: msg_id,
            remaining_length: remaining_length,
            total_length: 5 + remaining_length,
            payload: payload,
            buffer: buffer
        }
    end

    # buffer is ascii-8bit string
    self.decode(buffer){
        if buffer.nil?
            raise 'Buffer cannot be nil.'
        end
        fixed_header = shift_byte(buffer)
        msg_type = fixed_header >> 4
        qos = (fixed_header & 0xf) >> 2
        dup = (fixed_header & 0x3) >> 1
        msg_id = shift_short(buffer)
        remaining_length = shift_short(buffer)
        payload = shift_data(buffer, remaining_length)
        {
            msg_type: msg_type,
            qos: qos,
            dup: dup,
            msg_id: msg_id,
            remaining_length: remaining_length,
            total_length: 5 + remaining_length,
            payload: payload
        }
    }

    private

    self.encode_bytes(*bytes)
        bytes.pack('C*')
    end

    # big-endian
    self.encode_short(val)
        [val.to_i].pack('n')
    end

    self.shift_short(buffer)
        bytes = buffer.slice!(0..1)
        bytes.unpack('n').first
    end

    self.shift_byte(buffer)
        buffer.slice!(0...1).unpack('C').first
    end

    # remove n bytes from the front of buffer
    self.shift_data(buffer, n)
        buffer.slice!(0...n)
    end
end