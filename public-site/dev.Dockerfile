FROM ruby:2.7-buster

RUN apt-get update
RUN apt-get install build-essential nodejs -y
RUN wget https://www.npmjs.com/install.sh && sh ./install.sh && rm install.sh
RUN gem install bundler:1.17.2
RUN npm install -g bower

WORKDIR /site
COPY Gemfile* ./

RUN bundle install
