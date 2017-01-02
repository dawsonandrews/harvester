require_relative './app'

use Rack::Auth::Basic do |username, password|
  username == 'admin' and password == ENV['ADMIN_PASSWORD']
end

run Sinatra::Application