# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
use Rack::Deflater
use Solitr::Rack::Headers
use Solitr::Rack::TrailingSlash
run Solitr::Application
