require "bundler/setup"
require "rack-rewrite"

use Rack::Rewrite do
  rewrite '/', '/index.html'
end

root=Dir.pwd
puts ">>> Serving: #{root}"
run Rack::Directory.new(root.to_s)
