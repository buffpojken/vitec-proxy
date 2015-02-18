#coding:utf-8
require 'rest_client'
require 'json'
require 'socksify'

TCPSocket::socks_server = "127.0.0.1"
TCPSocket::socks_port = 2001


data = {
           :lgh_nr => "C1602",
            :rooms => "3",
              :kvm => "91",
              :fee => "6314",
            :price => "6400000",
          :balcony => "Nej",
           :status => "Såld",
        :available => false,
         :email_to => "christian@oscarproperties.se",
           :hidden => false,
             :name => "C1602",
             :guid => "4A53B0UI8GQ1F9S2",
    :latest_update => 1422005681, 
    :plan 		=> "http://static.comicvine.com/uploads/original/11116/111169062/3910634-cthulhu.jpg"
}

url = "http://www.op.whisprgroup.com/packhuset"

response = RestClient.post (url + "/vitec/webhook/"), {:data => JSON.generate(data), :token => "ab87d24bdc7452e55738deb5f868e1f16dea5ace"}

puts response