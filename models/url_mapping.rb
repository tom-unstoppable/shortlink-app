require "redis"
require "json"

# URL Mapping model - handles the core shortening logic
# Redis is much faster anyway, so this was a good change for a quick start
class UrlMapping
  REDIS_KEY_PREFIX = "url_mapping:"  # Keep it simple for now
  TTL_ONE_YEAR = 365 * 24 * 60 * 60  # 1 year in seconds - might adjust this later
  SHORT_CODE_LENGTH = 6              # 6 chars should be enough for now, but we'll see
  
  def initialize(redis_client = nil)
    @redis = redis_client || begin
      Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379")
    rescue Redis::CannotConnectError => e
      # Log the error but don't crash the app
      puts "Warning: Redis connection failed: #{e.message}"
      puts "App will continue but URL shortening won't work until Redis is available"
      nil
    end
  end
  
  def self.encode(url, redis_client = nil)
    instance = new(redis_client)
    instance.encode(url)
  end
  
  def self.decode(short_code, redis_client = nil)
    instance = new(redis_client)
    instance.decode(short_code)
  end
  
  def encode(url)
    # Check if Redis is available
    unless @redis
      raise "Redis is not available. Please check your Redis connection."
    end
    
    # TODO: Add URL validation here later
    
    # Check if URL already exists - this prevents duplicate short codes
    existing_mapping = find_by_url(url)
    return existing_mapping if existing_mapping
    
    # Generate new short code - had some collision issues initially but this loop handles it
    short_code = generate_short_code
    
    # Store in Redis - using both URL and short code as keys for quick lookup
    # TODO: Could optimize this to use less memory later
    mapping_data = {
      "original_url" => url,
      "short_code" => short_code,
      "access_count" => 0,
      "created_at" => Time.now.to_i  # Unix timestamp for now
    }
    
    # Store with both URL and short code as keys for quick lookup
    @redis.set("#{REDIS_KEY_PREFIX}url:#{url}", mapping_data.to_json)
    @redis.set("#{REDIS_KEY_PREFIX}code:#{short_code}", mapping_data.to_json)
    
    # Set expiration - URLs expire after 1 year to prevent unlimited growth
    # TODO: Make this configurable per URL if needed
    @redis.expire("#{REDIS_KEY_PREFIX}url:#{url}", TTL_ONE_YEAR)
    @redis.expire("#{REDIS_KEY_PREFIX}code:#{short_code}", TTL_ONE_YEAR)
    
    mapping_data
  end
  
  def decode(short_code)
    # Check if Redis is available
    unless @redis
      raise "Redis is not available. Please check your Redis connection."
    end
    
    mapping_data = find_by_code(short_code)
    return nil unless mapping_data
    
    # Increment access count - useful for analytics
    mapping_data["access_count"] += 1
    @redis.set("#{REDIS_KEY_PREFIX}code:#{short_code}", mapping_data.to_json)
    
    mapping_data["original_url"]
  end
  
  def short_url(short_code)
    # For production, use BASE_URL or construct from environment
    if ENV["RACK_ENV"] == "production"
      base_url = ENV["BASE_URL"] || "https://#{ENV["HOSTNAME"] || "localhost"}"
    else
      base_url = ENV["BASE_URL"] || "http://localhost:4567"
    end
    "#{base_url}/#{short_code}"  # Simple string interpolation
  end
  
  private
    def find_by_url(url)
      data = @redis.get("#{REDIS_KEY_PREFIX}url:#{url}")
      return nil unless data
      
      JSON.parse(data)
    end
    
    def find_by_code(short_code)
      data = @redis.get("#{REDIS_KEY_PREFIX}code:#{short_code}")
      return nil unless data
      
      JSON.parse(data)
    end
    
    def generate_short_code
      # This loop handles collisions - had some issues with this initially
      # TODO: Could optimize this with a counter-based approach if we get lots of collisions
      loop do
        short_code = SecureRandom.alphanumeric(SHORT_CODE_LENGTH).upcase
        break short_code unless @redis.exists?("#{REDIS_KEY_PREFIX}code:#{short_code}")
        # If we get here, there was a collision, so try again
      end
    end
end
