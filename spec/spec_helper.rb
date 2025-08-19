require "rspec"
require "rack/test"
require "redis"
require_relative "../app"

RSpec.configure do |config|
  config.before(:suite) do
    # Use Redis service name when running in Docker, localhost for local development
    redis_url = ENV["REDIS_URL"] || "redis://localhost:6379/1"
    ENV["REDIS_URL"] = redis_url
  end
  
  config.before(:each) do
    # Clear test data before each test
    redis = Redis.new(url: ENV["REDIS_URL"])
    keys = redis.keys("url_mapping:*")
    redis.del(*keys) if keys.any?
  end
  
  config.after(:suite) do
    # Clean up test data
    redis = Redis.new(url: ENV["REDIS_URL"])
    keys = redis.keys("url_mapping:*")
    redis.del(*keys) if keys.any?
  end
end
