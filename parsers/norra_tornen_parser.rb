class NorraTornenParser < SmallDefinitionParser

	def self.endpoint_url
		"http://nt.spektradesign.se/wp-content/themes/Norra-Tornen/vitecSync.php"
#		"http://requestb.in/1fecj8t1"
	end

	def self.parse(result, status, index)		
		objectData = super
		image_list = result[:bilder][:bild]
		if image_list && image_list.is_a?(Array)
			image_list.each do |image_package|
				if ["view", "preview"].include?(image_package[:kategori])
					url = "http://fastighet.capitex.se/CapitexResources/Capitex.Datalager.DBFile/Capitex.Datalager.DBFile.dbfile.aspx?g=#{image_package[:guid]}&t=CBild"
					objectData[image_package[:kategori]] = url
				else
					next
				end
			end
			ap objectData
		end
		objectData
	end

end