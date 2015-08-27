#coding:utf-8
require 'rest_client'
require 'savon'
require 'redis'
require 'json'
require "awesome_print"
require 'set'
require './parsers/small_definition_parser'

Dir.glob('./parsers/**').each do |path|
	require path
end


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

		@projects = File.open('projects', 'a')

		client = Savon.client(wsdl: "http://export.capitex.se/Nyprod/Standard/Export.svc?singleWsdl")
		fileclient = Savon.client(wsdl: "http://export.capitex.se/fastighetsmaklare/Standardobjektmall/ExportV2.svc?wsdl")
		puts data["type"]

		if data["type"] == "CMNyProd"

		elsif data["type"] == "CMBoLgh"
			info = client.call(:hamta_bostadsratt, message: {
				'licensid' 			=> "840120", 
				'licensnyckel' 	=> "8ad810bb-205a-b123-d4df-1af899371f17", 
				"kundnummer" 		=> "840120", 
				"guid"					=> data["guid"]
			})

			response 		= info.body[:hamta_bostadsratt_response]
			result 			= response[:hamta_bostadsratt_result]

			ap "Managing #{result[:projektnamn]}"
			status 			= parseStatus(result[:status])

			parser 			= parse_by_project(result[:projektnamn])

			unless parser
				ap "#{result[:projektnamn]} is not configured with a parser."
				return
			end

			begin
				objectData = parser.parse(result, status, data['index'])
			rescue Exception => e
				puts e
			end
			wrapped_url = parser.endpoint_url
			puts wrapped_url
			begin
				response = RestClient.post wrapped_url, {:data => JSON.generate(objectData), :token => "ab87d24bdc7452e55738deb5f868e1f16dea5ace"}
			rescue Exception => e
				puts e
			end
			puts response.inspect
			if response == "ok\n"
				redis.set ("vitec-update-"+result[:guid]), objectData[:latest_update]
			else
				puts response.inspect
			end
@projects.close
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
			'Till salu'			=> ['Ledig', true, false], 
			'Dold'					=> ['Dold', false, true], 
			'Bokaddold' 		=> ['-', false, true]
		}
		return possible_statuses.fetch(status_key, ['hidden', false, true])
	end

	def self.parse_by_project(project_name)
		data = {
			'HG7 Packhuset' 		=> PackhusetParser, 
			'Chokladfabriken'		=> ChokladfabrikenParser,
			'Lyceum'						=> LyceumParser, 
			'Norra tornen'			=> NorraTornenParser, 
			'Industriverket'		=> IndustriverketParser, 
			'79 & Park' 				=> Park79Parser, 
			'Zootomiska' 				=> ZootomiskaParser		
		}
		if data[project_name]
			return data[project_name]
		end
	end

end