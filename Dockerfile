# 勉強会の開発用イメージ（本番用ではありません）
FROM ruby:4.0.6-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libssl-dev libyaml-dev sqlite3 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ビルド時に bundle install まで済ませておく（当日のネットワークに依存しないため）
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000
CMD ["bash", "-c", "rm -f tmp/pids/server.pid && bin/rails db:prepare && bin/rails server -b 0.0.0.0 -p 3000"]
