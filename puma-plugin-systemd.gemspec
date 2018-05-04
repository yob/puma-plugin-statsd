# coding: utf-8, frozen_string_literal: true
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "puma/plugin/systemd/version"

Gem::Specification.new do |spec|
  spec.name     = "puma-plugin-systemd"
  spec.version  = Puma::Plugin::Systemd::VERSION
  spec.author   = "Samuel Cochran"
  spec.email    = "sj26@sj26.com"

  spec.summary  = "Puma integration with systemd: notify, status, watchdog"
  spec.homepage = "https://github.com/sj26/puma-plugin-systemd"
  spec.license  = "MIT"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]

  spec.add_runtime_dependency "puma", "~> 3.6.0"
  spec.add_runtime_dependency "json"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
