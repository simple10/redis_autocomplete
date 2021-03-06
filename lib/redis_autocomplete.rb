require 'redis'

class RedisAutocomplete
  attr_reader :redis, :terminal

  def initialize(set, disallowed_chars = /[^a-zA-Z0-9_-]/, terminal = '+')
    @set = set
    @redis = Redis.new
    @disallowed_chars = disallowed_chars
    @terminal = terminal
  end

  def add_word(word)
    w = word.gsub(@disallowed_chars, '')
    (1..(w.length)).each { |i| @redis.zadd(@set, 0, w.slice(0, i)) }
    @redis.zadd(@set, 0, "#{w}#{@terminal}")
  end

  def add_words(*words)
    words.flatten.compact.uniq.each { |word| add_word word }
  end

  def suggest(prefix, count = 10)
    results = []
    rangelen = 50 # This is not random, try to get replies < MTU size
    start = @redis.zrank(@set, prefix)
    return [] if !start
    while results.length != count
      range = @redis.zrange(@set, start, start+rangelen-1)
      start += rangelen
      break if !range || range.length == 0
      range.each do |entry|
        minlen = [entry.length, prefix.length].min
        if entry.slice(0, minlen) != prefix.slice(0, minlen)
          count = results.count
          break
        end
        if entry[-1] == @terminal and results.length != count
          results << entry.chomp(@terminal)
        end
      end
    end
    return results
  end
end