#! /bin/sh
rm -rf ~/.phantomjs &&
mkdir -p ~/.phantomjs/2.1.1/x86_64-linux/ &&
tar xf phantomjs.tar.bz2 &&
mv phantomjs-2.1.1-linux-x86_64/* ~/.phantomjs/2.1.1/x86_64-linux/ &&
rm -rf phantomjs-2.1.1-linux-x86_64 &&
bundle install &&
bundle exec rails db:migrate &&
bundle exec rails assets:precompile
echo done!
