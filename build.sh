#! /bin/sh
rm -rf .phantomjs &&
mkdir .phantomjs &&
tar xvf phantomjs.tar.bz2 &&
mv phantomjs-2.1.1-linux-x86_64 .phantomjs/2.1.1 &&
bundle install &&
bundle exec rails db:migrate &&
bundle exec rails assets:precompile
