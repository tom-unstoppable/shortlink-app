#!/usr/bin/env ruby

require "net/http"
require "json"
require "uri"
require "redis"

# Demo script for ShortLink - built this to test the API manually
# Useful for development and showing off the features

# Demo script for ShortLink URL Shortening Service
class ShortLinkDemo
  BASE_URL = "http://localhost:4567"
  
  def initialize
    @http = Net::HTTP.new("localhost", 4567)
    @redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379")
  end
  
  def run_demo
    puts "ShortLink URL Shortening Service Demo (Redis Edition)"
    puts "=" * 60
    puts
    
    # Test Redis connection
    test_redis_connection
    
    # Test health check
    test_health_check
    
    # Test URL encoding
    test_url_encoding
    
    # Test URL decoding
    test_url_decoding
    
    # Test redirect functionality
    test_redirect_functionality
    
    # Test error handling
    test_error_handling
    
    # Show Redis stats
    show_redis_stats
    
    puts "\n✅ Demo completed successfully!"
  end
  
  private
    def test_redis_connection
      puts "0. Testing Redis Connection..."
      begin
        @redis.ping
        puts "✅ Redis connection successful!"
      rescue => e
        puts "❌ Redis connection failed: #{e.message}"
        puts "--- Make sure Redis is running: docker-compose up redis"
        return false
      end
      puts
    end
    
    def test_health_check
      puts "1. Testing Health Check..."
      response = make_request("GET", "/")
      if response.code == "200"
        data = JSON.parse(response.body)
        puts "✅ Health check passed: #{data["message"]}"
      else
        puts "❌ Health check failed: #{response.code}"
      end
      puts
    end
    
    def test_url_encoding
      puts "2. Testing URL Encoding..."
      
      test_urls = [
        "https://www.google.com",
        "https://github.com/ruby/ruby",
        "https://stackoverflow.com/questions/tagged/ruby"
      ]
      
      @encoded_urls = []
      
      test_urls.each_with_index do |url, index|
        puts "Encoding URL #{index + 1}: #{url}"
        
        response = make_request("POST", "/encode", { url: url })
        
        if response.code == "200"
          data = JSON.parse(response.body)
          @encoded_urls << data
          puts "✅ Encoded to: #{data["short_url"]} (code: #{data["short_code"]})"
        else
          puts "❌ Failed to encode: #{response.code} - #{response.body}"
        end
      end
      puts
    end
    
    def test_url_decoding
      puts "3. Testing URL Decoding..."
      
      @encoded_urls.each_with_index do |encoded, index|
        short_code = encoded["short_code"]
        puts "Decoding short code: #{short_code}"
        
        response = make_request("GET", "/decode/#{short_code}")
        
        if response.code == "200"
          data = JSON.parse(response.body)
          puts "✅ Decoded to: #{data["original_url"]}"
        else
          puts "❌ Failed to decode: #{response.code} - #{response.body}"
        end
      end
      puts
    end
    
    def test_redirect_functionality
      puts "4. Testing Redirect Functionality..."
      
      @encoded_urls.each_with_index do |encoded, index|
        short_code = encoded["short_code"]
        puts "Testing redirect for: #{short_code}"
        
        response = make_request("GET", "/#{short_code}")
        
        if response.code == "301" || response.code == "302"
          puts "✅ Redirect successful: #{response["location"]}"
        else
          puts "❌ Redirect failed: #{response.code} - #{response.body}"
        end
      end
      puts
    end
    
    def test_error_handling
      puts "5. Testing Error Handling..."
      
      # Test invalid URL
      puts "Testing invalid URL..."
      response = make_request("POST", "/encode", { url: "not-a-valid-url" })
      if response.code == "400"
        puts "✅ Correctly rejected invalid URL"
      else
        puts "❌ Should have rejected invalid URL: #{response.code} - #{response.body}"
      end
      
      # Test non-existent short code
      puts "Testing non-existent short code..."
      response = make_request("GET", "/decode/NONEXISTENT")
      if response.code == "404"
        puts "✅ Correctly handled non-existent code"
      else
        puts "❌ Should have returned 404: #{response.code} - #{response.body}"
      end
      
      puts
    end
    
    def show_redis_stats
      puts "6. Redis Statistics..."
      begin
        keys = @redis.keys("url_mapping:*")
        url_keys = keys.select { |k| k.include?("url:") }
        code_keys = keys.select { |k| k.include?("code:") }
        
        puts "+ Total keys: #{keys.length}"
        puts "+ URL mappings: #{url_keys.length}"
        puts "+ Short codes: #{code_keys.length}"
        puts "+ Memory usage: #{@redis.info["used_memory_human"]}"
      rescue => e
        puts "❌ Failed to get Redis stats: #{e.message}"
      end
      puts
    end
    
    def make_request(method, path, data = nil)
      case method.upcase
      when "GET"
        request = Net::HTTP::Get.new(path)
      when "POST"
        request = Net::HTTP::Post.new(path)
        request["Content-Type"] = "application/json"
        request.body = data.to_json if data
      end
      
      @http.request(request)
    rescue => e
      puts "❌ Request failed: #{e.message}"
      OpenStruct.new(code: "500", body: "{}")
    end
end

# Run the demo if this script is executed directly
if __FILE__ == $0
  puts "Starting ShortLink Demo (Redis Edition)..."
  puts "Make sure the application is running on http://localhost:4567"
  puts "Make sure Redis is running: docker-compose up redis"
  puts "Press Enter to continue..."
  gets
  
  demo = ShortLinkDemo.new
  demo.run_demo
end
