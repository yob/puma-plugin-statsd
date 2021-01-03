Gem::Specification.new do |spec|
  spec.name     = "puma-plugin-statsd"
  spec.version  = "1.1.0"
  spec.author   = "James Healy"
  spec.email    = "james@yob.id.au"

  spec.summary  = "Send puma metrics to statsd via a background thread"
  spec.homepage = "https://github.com/yob/puma-plugin-statsd"
  spec.license  = "MIT"

  spec.files = Dir["lib/**/*.rb", "README.md", "CHANGELOG.md", "MIT-LICENSE"]

  spec.add_runtime_dependency "puma", ">= 3.12", "< 6"
  spec.add_runtime_dependency "json"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "sinatra"
  spec.add_development_dependency "rack"
end
