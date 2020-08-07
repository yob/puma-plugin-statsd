# encoding: utf-8
require 'socket'
server = UDPSocket.new
host, port = "127.0.0.1", 8125
server.bind(host, port)

while true
  text, sender = server.recvfrom(64)
  remote_host = sender[3]
  time = Time.now.strftime('%H:%M:%S.%L')
  STDOUT.puts "#{remote_host}:#{text} - #{time}"
end
