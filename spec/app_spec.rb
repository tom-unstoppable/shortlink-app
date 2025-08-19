require "spec_helper"
require "rack/test"
require_relative "../app"

describe "ShortLink URL Shortening Service" do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  let(:redis) { Redis.new(url: ENV["REDIS_URL"]) }

  describe "GET /" do
    it "returns health check information" do
      get "/"
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to include("status" => "ok")
    end
  end

  describe "POST /encode" do
    it "encodes a valid URL successfully" do
      post "/encode", { url: "https://example.com" }.to_json, "CONTENT_TYPE" => "application/json"
      
      expect(last_response.status).to eq(200)
      response = JSON.parse(last_response.body)
      
      expect(response).to include("original_url")
      expect(response).to include("short_url")
      expect(response).to include("short_code")
      expect(response["original_url"]).to eq("https://example.com")
      expect(response["short_code"]).to match(/^[A-Z0-9]{6}$/)
    end

    it "returns the same short URL for duplicate URLs" do
      post "/encode", { url: "https://example.com" }.to_json, "CONTENT_TYPE" => "application/json"
      first_response = JSON.parse(last_response.body)

      post "/encode", { url: "https://example.com" }.to_json, "CONTENT_TYPE" => "application/json"
      second_response = JSON.parse(last_response.body)
      
      expect(first_response["short_code"]).to eq(second_response["short_code"])
    end

    it "rejects invalid URLs" do
      post "/encode", { url: "not-a-url" }.to_json, "CONTENT_TYPE" => "application/json"
      
      expect(last_response.status).to eq(400)
      response = JSON.parse(last_response.body)
      expect(response).to include("error")
    end

    it "rejects empty URL" do
      post "/encode", { url: "" }.to_json, "CONTENT_TYPE" => "application/json"
      
      expect(last_response.status).to eq(400)
      response = JSON.parse(last_response.body)
      expect(response).to include("error")
    end

    it "rejects missing URL parameter" do
      post "/encode", {}.to_json, "CONTENT_TYPE" => "application/json"
      
      expect(last_response.status).to eq(400)
      response = JSON.parse(last_response.body)
      expect(response).to include("error")
    end

    it "rejects invalid JSON" do
      post "/encode", "invalid json", "CONTENT_TYPE" => "application/json"
      
      expect(last_response.status).to eq(400)
      response = JSON.parse(last_response.body)
      expect(response).to include("error")
    end
  end

  describe "GET /decode/:short_code" do
    it "decodes a valid short code successfully" do
      # First encode a URL to get a short code
      post "/encode", { url: "https://example.com" }.to_json, "CONTENT_TYPE" => "application/json"
      short_code = JSON.parse(last_response.body)["short_code"]
      
      get "/decode/#{short_code}"
      
      expect(last_response.status).to eq(200)
      response = JSON.parse(last_response.body)
      
      expect(response["short_code"]).to eq(short_code)
      expect(response["original_url"]).to eq("https://example.com")
      expect(response).to include("short_url")
    end

    it "increments access count on decode" do
      # First encode a URL
      post "/encode", { url: "https://example.com" }.to_json, "CONTENT_TYPE" => "application/json"
      short_code = JSON.parse(last_response.body)["short_code"]
      
      # Get initial access count
      initial_data = redis.get("url_mapping:code:#{short_code}")
      initial_count = JSON.parse(initial_data)["access_count"]
      
      # Decode the URL
      get "/decode/#{short_code}"
      
      # Check if access count increased
      updated_data = redis.get("url_mapping:code:#{short_code}")
      updated_count = JSON.parse(updated_data)["access_count"]
      expect(updated_count).to eq(initial_count + 1)
    end

    it "returns 404 for non-existent short code" do
      get "/decode/NONEXISTENT"
      
      expect(last_response.status).to eq(404)
      response = JSON.parse(last_response.body)
      expect(response).to include("error")
    end

    it "rejects empty short code" do
      get "/decode/"
      
      expect(last_response.status).to eq(404)
    end
  end

  describe "GET /:short_code (redirect)" do
    it "redirects to original URL for valid short code" do
      # First encode a URL
      post "/encode", { url: "https://example.com" }.to_json, "CONTENT_TYPE" => "application/json"
      short_code = JSON.parse(last_response.body)["short_code"]
      
      get "/#{short_code}"
      
      expect(last_response.status).to eq(301)
      expect(last_response.location).to eq("https://example.com")
    end

    it "increments access count on redirect" do
      # First encode a URL
      post "/encode", { url: "https://example.com" }.to_json, "CONTENT_TYPE" => "application/json"
      short_code = JSON.parse(last_response.body)["short_code"]
      
      # Get initial access count
      initial_data = redis.get("url_mapping:code:#{short_code}")
      initial_count = JSON.parse(initial_data)["access_count"]
      
      # Access the short URL
      get "/#{short_code}"
      
      # Check if access count increased
      updated_data = redis.get("url_mapping:code:#{short_code}")
      updated_count = JSON.parse(updated_data)["access_count"]
      expect(updated_count).to eq(initial_count + 1)
    end

    it "returns 404 for non-existent short code" do
      get "/NONEXISTENT"
      
      expect(last_response.status).to eq(404)
      response = JSON.parse(last_response.body)
      expect(response).to include("error")
    end
  end

  describe "URL Mapping Model" do
    it "generates unique short codes" do
      mapping1 = UrlMapping.encode("https://example1.com")
      mapping2 = UrlMapping.encode("https://example2.com")
      
      expect(mapping1["short_code"]).not_to eq(mapping2["short_code"])
    end

    it "stores data in Redis" do
      mapping = UrlMapping.encode("https://example.com")
      
      # Check if data is stored in Redis
      stored_data = redis.get("url_mapping:code:#{mapping["short_code"]}")
      expect(stored_data).not_to be_nil
      
      parsed_data = JSON.parse(stored_data)
      expect(parsed_data["original_url"]).to eq("https://example.com")
      expect(parsed_data["short_code"]).to eq(mapping["short_code"])
    end

    it "handles duplicate URLs correctly" do
      # Encode the same URL twice
      mapping1 = UrlMapping.encode("https://example.com")
      mapping2 = UrlMapping.encode("https://example.com")
      
      # Should return the same mapping data
      expect(mapping1["short_code"]).to eq(mapping2["short_code"])
      expect(mapping1["original_url"]).to eq(mapping2["original_url"])
    end
  end
end
