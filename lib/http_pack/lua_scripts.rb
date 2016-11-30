module HttpPack::LuaScripts

    # Add to Indexable Priority Queue
    # 
    # EVAL PQADD 1 ns 999 msgid bufferstring
    #
    # Keys 1. Namespace
    # Args 1. Sorted Set Score
    # Args 2. Identifer
    # Args 3. Value
    PQADD = "redis.call('ZADD', KEYS[1]..':pq', ARGV[1], ARGV[2])\n" + \
        "redis.call('HSET', KEYS[1]..':index', ARGV[2], ARGV[3])"

    # Popup N item from Indexable Priority Queue
    #
    # EVAL PQPOP 1 ns 10
    #
    # Keys 1. Namespace
    # Args 1. Limit
    PQPOP = "local t = {}\n" + \
        "for i, k in pairs(redis.call('ZRANGE', KEYS[1]..':pq', 0, ARGV[1])) do\n" + \
            "local v = redis.call('HGET', KEYS[1]..':index', k)\n" + \
            "table.insert(t, #t + 1, v)\n" + \
        "end" + \
        "redis.call('ZREMRANGEBYRANK', KEYS[1]..':pq', 0, ARGV[1]))" + \
        "return t"

    # Remove from Indexable Priority Queue
    #
    # EVAL PQPOP 1 ns msgid
    #
    # Keys 1. Namespace
    # Args 1. Identifer
    PQREM = "redis.call('ZREM', KEYS[1]..':pq', ARGV[1])\n" + \
        "redis.call('HDEL', KEYS[1]..':index', ARGV[1])"
end