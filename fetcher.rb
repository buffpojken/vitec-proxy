#coding:utf-8
require 'savon'
require 'redis'
require 'json'
require "awesome_print"
require 'restclient'

class Fetcher
	extend Resque::Plugins::Retry

	@retry_limit = 3
	@retry_delay = 180
	
	@queue = :info_fetch_queue

	def self.sandbox
		perform({:guid => "49J34TIN6QHBV6VS", :type => "CMBoLgh"}.to_json)
	end

	def self.perform(payload)
		data = JSON.parse(payload)
		redis = Redis.new

		client = Savon.client(wsdl: "http://export.capitex.se/Nyprod/Standard/Export.svc?singleWsdl")

		# Add support for other house-types here!
		if data["type"] == "CMBoLgh"
			info = client.call(:hamta_bostadsratt, message: {
				'licensid' 			=> "840120", 
				'licensnyckel' 	=> "8ad810bb-205a-b123-d4df-1af899371f17", 
				"kundnummer" 		=> "840120", 
				"guid"					=> data["guid"]
			})

			response = info.body[:hamta_bostadsratt_response]
			result 		= response[:hamta_bostadsratt_result]

			ap result

			email = result[:internetinstallningar][:intresseanmalan_epostmottagare].match(/<(.+)>/)

			objectData = {
				:lgh_nr 					=> result[:lagenhetsnummer], 
				:rooms						=> result[:rum][:antal_rum_min], 
				:kvm 							=> result[:rum][:bostads_area], 
				:fee 							=> result[:manadsavgift], 
				:price 						=> result[:pris_anbud_tillval][:utgangspris], 
				:balcony					=> result[:balkong_och_uteplats], 
				:status						=> result[:status].eql?("Till salu") ? 'Ledig' : 'Såld', 
				:email_to 				=> email[1], 
				:name 						=> result[:lagenhetsnummer], 
				:guid 						=> result[:guid], 
				:latest_update		=> result[:senast_andrad].to_time.to_i
			}

			# Here, switch address based on which project this item belongs to!		
			response = RestClient.post "http://localhost/oscarcampaign/chokladfabriken/vitec/webhook/", {:data => JSON.generate(objectData), :token => "ab87d24bdc7452e55738deb5f868e1f16dea5ace"}
			if response == "ok\n"
				redis.set ("vitec-update-"+result[:guid]), objectData[:latest_update]
			end

		end

	end

end