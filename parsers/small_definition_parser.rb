class SmallDefinitionParser

	def self.parse(result, status)
		if result[:filer] && result[:filer][:fil]
			fil 				= result[:filer][:fil]
		end

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
	end

	def endpoint_url
		raise NotImplementedError.new("SmallDefinitionParser doesn't provide this method, a subclass should implement it!")
	end

end