# Local preview only; GitHub Pages builds the live site itself.
# The github-pages gem pins the same Jekyll and plugin versions GitHub uses.
FROM ruby:3.3
RUN gem install github-pages -v 232 --no-document
WORKDIR /site
EXPOSE 4000 35729
CMD ["jekyll", "serve", "--host", "0.0.0.0", "--livereload", "--force_polling", "--unpublished"]
