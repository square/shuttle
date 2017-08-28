FROM ruby:2.3.1

RUN mkdir /app
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    gstreamer1.0-plugins-base \
    gstreamer1.0-tools \
    gstreamer1.0-x  \
    libarchive-dev \
    libqt5webkit5-dev \
    nodejs \
    postgresql-client \
    qt5-default \
    tidy \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/jwilder/dockerize/releases/download/v0.2.0/dockerize-linux-amd64-v0.2.0.tar.gz
RUN tar -C /usr/local/bin -xzvf dockerize-linux-amd64-v0.2.0.tar.gz

COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 5

COPY . ./

CMD bundle exec rails server
