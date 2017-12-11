FROM ruby:2.3.1

RUN apt-get update -qq
RUN apt-get install -y build-essential nodejs libarchive-dev libpq-dev \
    postgresql-client cmake tidy git

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

COPY square_primary_certificate_authority_g2.crt /usr/local/share/ca-certificates/
COPY square_service_authority_g2.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates

ADD Gemfile* $APP_HOME/
RUN gem update --system
RUN gem update
RUN gem clean
RUN bundle install

ADD . $APP_HOME
