FROM ruby:3.2.1

RUN mkdir -p /cuniculus/{lib/cuniculus/,bin/}
WORKDIR /cuniculus

COPY lib/cuniculus/version.rb /cuniculus/lib/cuniculus/version.rb
COPY *.gemspec Gemfile Gemfile.lock bin/ /cuniculus/
COPY bin/cuniculus /cuniculus/bin/cuniculus 
RUN bundle install

CMD bin/cuniculus

