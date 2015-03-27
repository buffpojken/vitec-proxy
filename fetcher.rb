#coding:utf-8
require 'rest_client'
require 'savon'
require 'redis'
require 'json'
require "awesome_print"
#require 'socksify'
require 'set'

# TCPSocket::socks_server = "127.0.0.1"
# TCPSocket::socks_port = 2001

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

			# begin
			# 	info = client.call(:hamta_projekt, message:{
			# 		'licensid' 			=> "840120", 
			# 		'licensnyckel' 	=> "8ad810bb-205a-b123-d4df-1af899371f17", 
			# 		"guid"					=> data["guid"]
			# 	})
			# rescue Exception => e
			# 	puts e.inspect
			# end

			# response = info.body[:hamta_projekt_response]
			# result = response[:hamta_projekt_result]

			# ap result[:namn] + " " + data['guid']
			

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

			if result[:filer] && result[:fil]
				fil 				= result[:filer][:fil]
			end

			email 			= result[:internetinstallningar][:intresseanmalan_epostmottagare].match(/<(.+)>/)

			status 			= parseStatus(result[:status])

			begin
			objectData 	= {
				:lgh_nr 					=> result[:lagenhetsnummer], 
				:rooms						=> result[:rum][:antal_rum_min], 
				:kvm 							=> result[:rum][:bostads_area], 
				:fee 							=> result[:manadsavgift][:manads_avgift], 
				:price 						=> result[:pris_anbud_tillval][:begart_pris], 
				:balcony					=> (result[:balkong_och_uteplats] ? result[:balkong_och_uteplats][:sammanstallning] : 'Nej' ), 
				:status						=> status[0], 
				:available 				=> status[1],
				:email_to 				=> email[1], 
				:hidden 					=> status[2],
				:name 						=> result[:lagenhetsnummer], 
				:sortering 				=> data['index'],
				:guid 						=> result[:guid], 
				:latest_update		=> result[:senast_andrad].to_time.to_i, 
			}
			if fil
				objectData[:plan] = "http://fastighet.capitex.se/CapitexResources/Capitex.Datalager.DBFile/Capitex.Datalager.DBFile.dbfile.aspx?g=#{fil[:guid]}&t=CFil"
			end
		rescue Exception => e
			puts e
		end

			# Here, switch address based on which project this item belongs to!		
			ap objectData

# #			return

			url = determineEndpointOnProject(result[:projektnamn])
			ap url
			return unless url
			wrapped_url = (url + "/vitec/webhook/")
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

	def self.determineEndpointOnProject(project_name)
		# data = {
		# 	"Tyresö trädgårdar" => "http://www.op.whisprgroup.com/tyreso/"
		# }
		data = {
			'HG7 Packhuset' => 'http://www.op.whisprgroup.com/packhuset', 
			'Chokladfabriken' => 'http://www.op.whisprgroup.com/chokladfabriken'
		}
		if data[project_name]
			return data[project_name]
		else
			@projects.puts project_name
		end
	end

end