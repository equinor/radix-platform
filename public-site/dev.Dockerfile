FROM ruby:2.5-alpine

RUN apk add build-base nodejs

WORKDIR /site
COPY Gemfile* ./

RUN bundle install
