require_relative "lib/rails_vitals/version"

Gem::Specification.new do |spec|
  spec.name        = "rails_vitals"
  spec.version     = RailsVitals::VERSION
  spec.authors     = [ "David Sanchez" ]
  spec.email       = [ "sanchez.dav90@gmail.com" ]
  spec.homepage    = "https://github.com/Sanchezdav/rails_vitals"
  spec.summary     = "RailsVitals is a lightweight Rails engine gem that makes the hidden runtime behavior of a Rails application visible, measurable, and teachable."
  spec.description = "RailsVitals is a lightweight Rails engine gem that makes the hidden runtime behavior of a Rails application visible, measurable, and teachable. It provides insights into the inner workings of a Rails app, helping developers understand and optimize their code. With RailsVitals, you can easily identify performance bottlenecks, track database queries, and gain a deeper understanding of how your application operates under the hood."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Sanchezdav/rails_vitals/tree/main"
  spec.metadata["changelog_uri"] = "https://github.com/Sanchezdav/rails_vitals/CHANGELOG.md"

  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0"
end
