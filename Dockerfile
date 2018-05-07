FROM ruby:2.3.1

ARG BUNDLE_GEMS__CONTRIBSYS__COM
ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

COPY square_primary_certificate_authority_g2.crt /usr/local/share/ca-certificates/
COPY square_service_authority_g2.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates

RUN apt-get update -qq \
    && apt-get install -y build-essential nodejs libarchive-dev libpq-dev \
       postgresql-client cmake tidy git \
    && apt-get clean

COPY Gemfile* $APP_HOME/
RUN gem update --system
RUN gem install bundler --version '>= 1.16.1' --conservative
RUN bundle install

COPY . $APP_HOME
