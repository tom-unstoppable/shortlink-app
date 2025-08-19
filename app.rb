require "sinatra"
require "json"
require "securerandom"
require_relative "models/url_mapping"

# ShortLink URL Shortening Service
# Started this as a weekend project to learn Sinatra, ended up being pretty useful!

# Configure Sinatra for different environments
if ENV["RACK_ENV"] == "production"
  # For production (Render/Heroku) - use PORT environment variable
  port = ENV["PORT"] || 8080
  set :port, port
  set :bind, "0.0.0.0"
  set :server, :puma
  set :environment, :production
  puts "Starting in PRODUCTION mode on port #{port}"
else
  # For local development
  set :port, 4567
  set :bind, "0.0.0.0"
  set :server, :puma
  set :environment, :development
  puts "Starting in DEVELOPMENT mode on port 4567"
end

# Enable JSON parsing
before do
  content_type "application/json"
end

# Helper method to get the current base URL
def current_base_url
  if ENV["RACK_ENV"] == "production"
    # For production, use the provided BASE_URL or construct from request
    ENV["BASE_URL"] || "https://#{request.env["HTTP_HOST"]}"
  else
    # For local development
    ENV["BASE_URL"] || "http://localhost:4567"
  end
end

# Helper method to handle Redis errors consistently
# Got tired of writing the same error handling code everywhere
def handle_redis_error(error)
  if error.message.include?("Redis is not available")
    status 500
    { error: "Service temporarily unavailable. Please try again later." }.to_json
  else
    status 500
    { error: "Internal server error", message: error.message }.to_json
  end
end

# Helper method for common error responses
# These helpers make the code much cleaner
def error_response(status_code, message)
  status status_code
  { error: message }.to_json
end

# Helper method for successful responses
def success_response(data)
  data.to_json
end

# Health check endpoint
get "/" do
  begin
    # Test Redis connection
    redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379")
    redis.ping
    
    success_response({
      status: "ok", 
      message: "ShortLink URL Shortening Service",
      redis: "connected",
      environment: ENV["RACK_ENV"] || "development",
      port: ENV["PORT"] || "unknown",
      timestamp: Time.now.iso8601
    })
  rescue => e
    # If Redis is down, still return a response but with warning
    success_response({
      status: "warning", 
      message: "ShortLink URL Shortening Service",
      redis: "disconnected",
      error: e.message,
      environment: ENV["RACK_ENV"] || "development",
      port: ENV["PORT"] || "unknown",
      timestamp: Time.now.iso8601
    })
  end
end

# Encode endpoint - converts long URL to short URL
post "/encode" do
  begin
    request_payload = JSON.parse(request.body.read)
    original_url = request_payload["url"]
    
    if original_url.nil? || original_url.empty?
      return error_response(400, "URL parameter is required")
    end
    
    # Validate URL format - had some issues with edge cases initially
    # Using proper URL validation that actually checks if the URL is valid
    begin
      uri = URI.parse(original_url)
      unless uri.scheme && uri.host && (uri.scheme == "http" || uri.scheme == "https")
        return error_response(400, "Invalid URL format - must be a valid HTTP or HTTPS URL")
      end
    rescue URI::InvalidURIError => e
      return error_response(400, "Invalid URL format")
    end
    
    # Encode the URL
    mapping = UrlMapping.encode(original_url)
    
    if mapping
      success_response({
        original_url: mapping["original_url"],
        short_url: "#{current_base_url}/#{mapping["short_code"]}",
        short_code: mapping["short_code"]
      })
    else
      # This shouldn't happen normally, but just in case
      error_response(500, "Failed to encode URL")
    end
    
  rescue JSON::ParserError
    error_response(400, "Invalid JSON payload")
  rescue => e
    # Catch any other errors and handle them
    handle_redis_error(e)
  end
end

# Decode endpoint - converts short URL back to original URL
get "/decode/:short_code" do
  short_code = params[:short_code]
  
  if short_code.nil? || short_code.empty?
    return error_response(400, "Short code parameter is required")
  end
  
  # Decode the short code
  begin
    original_url = UrlMapping.decode(short_code)
    
    if original_url
      success_response({
        short_code: short_code,
        original_url: original_url,
        short_url: "#{current_base_url}/#{short_code}"
      })
    else
      error_response(404, "Short code not found")
    end
  rescue => e
    handle_redis_error(e)
  end
end

# Redirect endpoint for actual URL redirection
get "/:short_code" do
  short_code = params[:short_code]
  
  if short_code.nil? || short_code.empty?
    return error_response(400, "Short code parameter is required")
  end
  
  # Decode the short code
  begin
    original_url = UrlMapping.decode(short_code)
    
    if original_url
      redirect original_url, 301
    else
      error_response(404, "Short code not found")
    end
  rescue => e
    handle_redis_error(e)
  end
end

# Error handlers
error 404 do
  error_response(404, "Not found")
end

error 500 do
  error_response(500, "Internal server error")
end

# Only start the server if this file is run directly
# When using rackup, this won't execute
if __FILE__ == $0
  Sinatra::Application.run!
end
