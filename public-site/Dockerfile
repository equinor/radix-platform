FROM ruby:2.6-alpine as builder
WORKDIR /site
RUN apk add build-base nodejs
COPY . .
RUN bundle install
RUN bundle exec jekyll build

FROM nginx:1.16-alpine
WORKDIR /site
COPY --from=builder /site/build /site
COPY nginx.conf /etc/nginx/conf.d/default.conf
