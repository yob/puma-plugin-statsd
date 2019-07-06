require 'sinatra'

class MyApp < Sinatra::Base
  get '/' do
    sleep 0.1
		'Put this in your pipe & smoke it!'
	end
end

run MyApp	
