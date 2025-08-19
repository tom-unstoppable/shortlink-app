require "redis"
require "json"

# Rake tasks for ShortLink - mostly for development and testing
# TODO: Add more admin tasks if needed

namespace :db do
  desc "Test Redis connection"
  task :test_connection do
    begin
      redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379")
      redis.ping
      puts "✅ Redis connection successful!"
    rescue => e
      puts "❌ Redis connection failed: #{e.message}"
      puts "💡 Make sure Redis is running and accessible"
    end
  end

  desc "Clear all URL mappings from Redis"
  task :clear do
    begin
      redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379")
      keys = redis.keys("url_mapping:*")
      if keys.any?
        redis.del(*keys)
        puts "✅ Cleared #{keys.length} URL mappings from Redis"
      else
        puts "ℹ️  No URL mappings found in Redis"
      end
    rescue => e
      puts "❌ Failed to clear Redis: #{e.message}"
    end
  end

  desc "Seed the database with sample data"
  task :seed do
    begin
      redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379")
      
      # Load the model
      require_relative "models/url_mapping"
      
      # Create some sample URLs
      sample_urls = [
        "https://www.google.com",
        "https://github.com",
        "https://stackoverflow.com",
        "https://ruby-lang.org",
        "https://sinatrarb.com"
      ]
      
      sample_urls.each do |url|
        UrlMapping.encode(url, redis)
      end
      
      puts "✅ Database seeded with #{sample_urls.length} sample URLs!"
    rescue => e
      puts "❌ Error seeding database: #{e.message}"
    end
  end

  desc "Show Redis statistics"
  task :stats do
    begin
      redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379")
      keys = redis.keys("url_mapping:*")
      url_keys = keys.select { |k| k.include?("url:") }
      code_keys = keys.select { |k| k.include?("code:") }
      
      puts "📊 Redis Statistics:"
      puts "   Total keys: #{keys.length}"
      puts "   URL mappings: #{url_keys.length}"
      puts "   Short codes: #{code_keys.length}"
      puts "   Memory usage: #{redis.info["used_memory_human"]}"
    rescue => e
      puts "❌ Failed to get Redis stats: #{e.message}"
    end
  end
end

desc "Start the application"
task :start do
  puts "Starting ShortLink application..."
  exec "ruby app.rb"
end

desc "Test Redis connection and show stats"
task :redis_check => ["db:test_connection", "db:stats"]
