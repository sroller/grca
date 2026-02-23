# frozen_string_literal: true

require "json"
require "fileutils"
require "digest"

module Grca
  # Cache module supporting Redis (production) and file-based (development) caching
  class Cache
    CACHE_TTL = 45 * 60 # 45 minutes in seconds
    CACHE_DIR = File.join(Dir.tmpdir, "grca_cache")

    class << self
      def enabled?
        ENV.fetch("GRCA_CACHE_ENABLED", "true") == "true"
      end

      def redis?
        ENV.key?("REDIS_URL")
      end

      # Fetch data from cache or execute block and cache result
      def fetch(key, ttl: CACHE_TTL, &block)
        return yield unless enabled?

        if redis?
          fetch_redis(key, ttl, &block)
        else
          fetch_file(key, ttl, &block)
        end
      end

      # Clear all cached data
      def clear
        if redis?
          clear_redis
        else
          clear_file
        end
      end

      private

      # Generate a short, filesystem-safe filename from cache key
      def hash_key(key)
        Digest::SHA256.hexdigest(key)[0, 32]
      end

      def redis_client
        require "redis"
        @redis_client ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379"))
      end

      def fetch_redis(key, ttl)
        cache_key = "grca:#{key}"
        cached = redis_client.get(cache_key)

        return JSON.parse(cached) if cached

        data = yield
        redis_client.setex(cache_key, ttl, data.to_json)
        data
      rescue Redis::BaseError => e
        warn "Redis error: #{e.message}, falling back to direct fetch"
        yield
      end

      def fetch_file(key, ttl)
        FileUtils.mkdir_p(CACHE_DIR)
        hashed = hash_key(key)
        cache_file = File.join(CACHE_DIR, "#{hashed}.json")
        lock_file = File.join(CACHE_DIR, "#{hashed}.lock")

        # Use file locking to prevent thundering herd
        File.open(lock_file, "w") do |lock|
          lock.flock(File::LOCK_EX)

          # Check if cache exists and is still valid
          if File.exist?(cache_file)
            mtime = File.mtime(cache_file)
            if (Time.now - mtime) < ttl
              lock.flock(File::LOCK_UN)
              return JSON.parse(File.read(cache_file))
            end
          end

          # Fetch fresh data
          data = yield
          File.write(cache_file, data.to_json)
          lock.flock(File::LOCK_UN)
          data
        end
      rescue StandardError => e
        warn "File cache error: #{e.message}, falling back to direct fetch"
        yield
      end

      def clear_redis
        keys = redis_client.keys("grca:*")
        redis_client.del(*keys) if keys.any?
      end

      def clear_file
        FileUtils.rm_rf(CACHE_DIR)
        FileUtils.mkdir_p(CACHE_DIR)
      end
    end
  end
end
