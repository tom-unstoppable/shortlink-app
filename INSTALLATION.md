# Installation & Setup

## Prerequisites
- Ruby 3.1+
- Redis 6.0+
- Bundler

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd shortlink-app
   ```

2. **Install dependencies:**
   ```bash
   bundle install
   ```

3. **Copy environment file:**
   ```bash
   cp env.example .env
   ```

4. **Start Redis:**
   ```bash
   # On Windows (using Docker)
   docker run -d -p 6379:6379 redis:6-alpine
   
   # On macOS with Homebrew
   brew install redis && brew services start redis
   
   # On Linux
   sudo apt-get install redis-server && sudo systemctl start redis
   ```

5. **Test Redis connection:**
   ```bash
   bundle exec rake redis_check
   ```

6. **Run the application:**
   ```bash
   bundle exec ruby app.rb
   ```

7. **Access the service:**
   - API: http://localhost:4567
   - Health check: http://localhost:4567/

## Docker Setup (Alternative)

1. **Build and run with Docker Compose:**
   ```bash
   docker-compose up --build
   ```

2. **Access the service:**
   - API: http://localhost:4567
   - Redis: localhost:6379

## Testing

Run the comprehensive test suite:

```bash
# Local testing
bundle exec rspec

# With Docker
docker-compose exec app bundle exec rspec
```

## Quick Commands

Here are the essential commands to get started:

```bash
# Install dependencies
bundle install

# Copy environment file
cp env.example .env

# Run tests
bundle exec rspec

# Start app
bundle exec ruby app.rb

# Test Redis
bundle exec rake redis_check

# Run demo
ruby demo.rb
```

**Test Coverage:**
- ✅ URL encoding endpoint
- ✅ URL decoding endpoint  
- ✅ Error handling (invalid URLs, missing parameters)
- ✅ JSON response validation
- ✅ Redis data persistence
- ✅ Access count tracking
- ✅ Duplicate URL handling
