Gem::Specification.new do |spec|
  spec.name     = "puma-plugin-statsd"
  spec.version  = "0.0.1"
  spec.author   = "James Healy"
  spec.email    = "james@yob.id.au"

  spec.summary  = "Send puma metrics to statsd via a background thread"
  spec.homepage = "https://github.com/yob/puma-plugin-statsd"
  spec.license  = "MIT"

  spec.files = Dir["lib/**/*.rb", "README.md", "MIT-LICENSE"]

  spec.add_runtime_dependency "puma", "~> 3.12"
  spec.add_runtime_dependency "json"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
