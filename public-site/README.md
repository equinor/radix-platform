# Radix Public Site

This is the public site for promoting, documenting & showcasing the Radix
platform. It is a static site built with [Jekyll](https://jekyllrb.com).

## Running, building

### The easy way

    docker-compose up

This builds a Docker image `radix-public-site`, runs it in the container
`radix-public-site_container`, mounts the local directory into `/site` in the
container, and runs the `bundle exec jekyll serve` script, which builds and
serves the site. It also watches for file changes and auto-rebuilds.

You can see the site on http://localhost:4000

Stop the server with Ctrl+C, but also run `docker-compose down` to clean up the
Docker state.

If you need a shell in the container:

    docker exec -ti radix-public-site_container sh

If you change the `Gemfile` (e.g. add a dependency), or want to force a clean
dev environment, you will need to rebuild the dev image:

    docker-compose up --build

**Windows**: There is currently [a
problem](https://github.com/docker/for-win/issues/56) with Docker that prevents
auto-reload of the development server from working when source files change. A
simple workaround is to use [a little watcher
process](https://github.com/FrodeHus/docker-windows-volume-watcher/releases).

### The other way

You can just run Jekyll locally. You need Ruby and `bundle`. In the root folder
of the project run `bundle install` to set up dependencies, and then 
`bundle exec jekyll serve` to start the server. Instructions on how to set up the
environment are on the [Jekyll
website](https://jekyllrb.com/docs/installation/).

### Update gem version

Run re-built site

    docker-compose up --build

Connect to a shell in the container:

    docker exec -ti radix-public-site_container sh

Change the version of a gem in `Gemfile` (files in the container `site` folder are mapped to current folder `.` in the project)
Update `Gemfile.lock`

    bundle lock --update

Verify if `Gemfile.lock` has gem version updated
Verify that site is operating - open/refresh in the browser a link [http//:localhost:4000](http//:localhost:4000)     

## Folder structure

The site content is organised within `/site/`. In here you find:

- `/_data/`: Various bits of data for using throughout the site
- `/_includes/`: Blocks of HTML, to be included in layouts or in content
- `/_layouts/`: HTML layouts for different types of page
- `/_style/`: CSS files. See the [CSS Section](#CSS) below
- `/_vendor/`: Third party libraries. Currently maintained manually

But the interesting bits are the actual content:

- `/docs/`: General concepts (topics) and reference documentation for end-users
- `/guides/`: User-friendly, conversational guides on how to achieve specific objectives

## CSS

We are using a variation of
[ITCSS](https://www.creativebloq.com/web-design/manage-large-css-projects-itcss-101517528).

All files have the `.scss` extension, but we are not using SASS features — this
is simply to make use of Jekyll's minifier and bundler, provided by SASS.

The `/index.scss` file includes all stylesheet files (organised under
`/_style/`).

Under `/_style/`, files are categorised in the following order:

- **settings.\*** global settings; variables only
- **generic.\*** resets; applies to most of the DOM
- **elements.\*** bare HTML elements
- **objects.\*** OOCSS-style reusable concepts: layouts, mini-layouts,
  animations
- **components.\*** specific components; the bulk of the styling
- **overrides.\*** utility-based styles and browser overrides

## Production build

The production build is containerised in the project's `Dockerfile`. To run the
build image locally:

    docker build -t radix-public-site-prod .
    docker run --name radix-public-site-prod_container --rm -p 8080:8080 radix-public-site-prod

The web server will be available on http://localhost:8080

# Credits

trees by Made x Made from the Noun Project: https://thenounproject.com/term/trees/1723897/
pot plant by Made x Made from the Noun Project: https://thenounproject.com/term/pot-plant/1724797/
Tumbleweed by Megan Sorenson from the Noun Project: https://thenounproject.com/term/tumbleweed/1390797/
