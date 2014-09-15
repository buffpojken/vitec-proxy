require 'sinatra'
require 'sinatra/redis'
require 'resque'
require 'resque-retry'
require 'json'
require './updater'

set :port, 6677

configure do
	Resque.redis = Redis.new	
end

get '/vitec/webhook' do 
	Resque.enqueue(Updater, {:user_id => params["UserID"], :data_source => params["DataSource"]}.to_json)
end