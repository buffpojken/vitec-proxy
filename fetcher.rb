#coding:utf-8
require 'savon'
require 'redis'
require 'json'
require "awesome_print"
require 'rest_client'

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
		puts data["type"]
		if data["type"] == "CMNyProd"
			puts data.inspect
			begin
				info = client.call(:hamta_projekt, message:{
					'licensid' 			=> "840120", 
					'licensnyckel' 	=> "8ad810bb-205a-b123-d4df-1af899371f17", 
					"guid"					=> data["guid"]
				})
			rescue Exception => e
				puts e.inspect
			end

			puts info.inspect
			

		# Add support for other house-types here!

		elsif data["type"] == "CMBoLgh"
			info = client.call(:hamta_bostadsratt, message: {
				'licensid' 			=> "840120", 
				'licensnyckel' 	=> "8ad810bb-205a-b123-d4df-1af899371f17", 
				"kundnummer" 		=> "840120", 
				"guid"					=> data["guid"]
			})

			response 		= info.body[:hamta_bostadsratt_response]
			result 			= response[:hamta_bostadsratt_result]

		#	ap result

			email 			= result[:internetinstallningar][:intresseanmalan_epostmottagare].match(/<(.+)>/)

			status 			= parseStatus(result[:status])

			objectData 	= {
				:lgh_nr 					=> result[:lagenhetsnummer], 
				:rooms						=> result[:rum][:antal_rum_min], 
				:kvm 							=> result[:rum][:bostads_area], 
				:fee 							=> result[:manadsavgift][:manads_avgift], 
				:price 						=> result[:pris_anbud_tillval][:begart_pris], 
				:balcony					=> (result[:balkong_och_uteplats] ? result[:balkong_och_uteplats] : 'Nej' ), 
				:status						=> status[0], 
				:available 				=> status[1],
				:email_to 				=> email[1], 
				:hidden 					=> status[2],
				:name 						=> result[:lagenhetsnummer], 
				:guid 						=> result[:guid], 
				:latest_update		=> result[:senast_andrad].to_time.to_i
			}

			# Here, switch address based on which project this item belongs to!		
#			ap objectData

#			return

			url = determineEndpointOnProject(result[:projektnamn])

			# We don't do anything if this is nil - write this to a log so this can be determined!
			puts "#{objectData[:projektnamn]} does not have a proper URL-mapping"
			return unless url

			response = RestClient.post url + "/vitec/webhook/", {:data => JSON.generate(objectData), :token => "ab87d24bdc7452e55738deb5f868e1f16dea5ace"}
			if response == "ok\n"
				redis.set ("vitec-update-"+result[:guid]), objectData[:latest_update]
			else
				puts response.inspect
			end

		end
	end

	def self.parseStatus(status_key)
		# Booleans denote: 
		# 1 --> Sort as available
		# 2 --> Hide
		possible_statuses = {
			"Osåld"					=> ["Ledig", true, false],
			"Bokad"					=> ["Såld", false, false], 
			"Reserverad"		=> ["Reserverad", true, false], 
			"Såld"					=> ["Såld", false, false], 
			"Sålddold"			=> ["hidden",false, true], 
			'Till salu'			=> ['Ledig', true, false]
		}
		puts status_key.inspect
		return possible_statuses.fetch(status_key, ['hidden', false, true])
	end

	def self.determineEndpointOnProject(project_name)
		data = {
			"Tyresö trädgårdar" => "http://localhost/oscarcampaign/chokladfabriken"
		}
		return data.fetch(project_name, nil)
	end

end