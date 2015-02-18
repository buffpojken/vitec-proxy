require 'savon'
require 'redis'
require 'date'
require 'json'
require './fetcher'

class Updater
	extend Resque::Plugins::Retry

	@retry_limit = 3
	@retry_delay = 180

	@queue = :vitec_update_queue

	def self.perform(payload)

		redis = Redis.new

		data 		= JSON.parse(payload)

		client = Savon.client(wsdl: "http://export.capitex.se/Gemensam/Export.svc?singleWsdl")

		updatedItems = client.call(:hamta_lista, message: {'licensId' => "840120", 'licensNyckel' => "8ad810bb-205a-b123-d4df-1af899371f17", "kundnummer" => "840120"})
		puts client.inspect

		result = updatedItems.body[:hamta_lista_response][:hamta_lista_result]

		listOfItems = result[:objekt_uppdateringsinfo]

		puts listOfItems.inspect
		listOfItems.each_with_index do |updated_item, idx|
			puts updated_item.inspect
			timestamp = redis.get('vitec-update-'+updated_item[:guid])
			if timestamp
				last_update = DateTime.strptime(timestamp,'%s')
			else
				last_update = DateTime.parse("1970-01-01")
			end
			if last_update < updated_item[:senast_andrad]
				Resque.enqueue(Fetcher, {:guid => updated_item[:guid], :type => updated_item[:typ], :index => idx}.to_json)
			else
				puts "Do not update!"
			end			
		end

	end

end