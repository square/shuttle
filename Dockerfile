FROM ruby:2.4.6

ARG BUNDLE_GEMS__CONTRIBSYS__COM
ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

RUN update-ca-certificates

# RUN printf "deb http://archive.debian.org/debian/ jessie main\ndeb-src http://archive.debian.org/debian/ jessie main\ndeb http://security.debian.org jessie/updates main\ndeb-src http://security.debian.org jessie/updates main" > /etc/apt/sources.list
RUN apt-get update -qq \
    && apt-get install -y build-essential nodejs libarchive-dev libpq-dev \
       postgresql-client cmake tidy git \
    && apt-get clean

COPY Gemfile* $APP_HOME/
RUN gem update --system
RUN gem install bundler --version '>= 1.16.1' --conservative
RUN bundle install

COPY . $APP_HOME
