require File.expand_path("lib/cuniculus/version", __dir__)
CUNICULUS_GEMSPEC = Gem::Specification.new do |gem|
  gem.name = "cuniculus"
  gem.version = Cuniculus.version
  gem.platform = Gem::Platform::RUBY
  gem.extra_rdoc_files = ["README.md", "CHANGELOG.md"]
  gem.rdoc_options += ["--quiet", "--line-numbers", "--inline-source", "--title",
                       "Cuniculus: Background job processing with RabbitMQ", "--main", "README.md"]
  gem.summary = "Job queue processing backed by RabbitMQ"
  gem.description = gem.summary
  gem.author = "Marcelo Pereira"
  gem.homepage = "https://github.com/MarcPer/cuniculus"
  gem.license = "BSD-2-Clause"
  gem.metadata = {
    "source_code_uri" => "https://github.com/MarcPer/cuniculus",
    "bug_tracker_uri" => "https://github.com/MarcPer/cuniculus/issues",
    "changelog_uri" => "https://github.com/MarcPer/cuniculus/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }
  gem.required_ruby_version = ">= 3.0"
  gem.files = %w[LICENSE CHANGELOG.md README.md bin/cuniculus] + Dir["lib/**/*.rb"]
  gem.bindir = "bin"
  gem.executables << "cuniculus"

  gem.add_dependency "bunny", ">= 2.19.0"

  gem.add_development_dependency "pry"
  gem.add_development_dependency "rackup"
  gem.add_development_dependency "redcarpet"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rubocop"
  gem.add_development_dependency "rubocop-rspec"
  gem.add_development_dependency "toxiproxy"
  gem.add_development_dependency "warning"
  gem.add_development_dependency "webrick"
  gem.add_development_dependency "yard"
end
