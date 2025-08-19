FROM ruby:3.4.4-alpine

RUN apk add --no-cache \
    build-base \
    tzdata

WORKDIR /app

RUN gem install bundler

COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

COPY . .

EXPOSE ${PORT:-8080}

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT:-8080}/ || exit 1

CMD bundle exec rackup --host 0.0.0.0 --port ${PORT:-8080}
