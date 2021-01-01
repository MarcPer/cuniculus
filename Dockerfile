FROM ruby:2.7.2

RUN mkdir -p /cuniculus/{lib/cuniculus/,bin/}
WORKDIR /cuniculus

COPY lib/cuniculus/version.rb /cuniculus/lib/cuniculus/version.rb
COPY *.gemspec gems.rb gems.locked bin/ /cuniculus/
COPY bin/cuniculus /cuniculus/bin/cuniculus 
RUN bundle install

CMD bin/cuniculus

