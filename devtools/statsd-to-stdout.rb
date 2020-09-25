# encoding: utf-8

RECV_BUFFER = 64*1024

require 'socket'
server = UDPSocket.new
host, port = "127.0.0.1", 8125
server.bind(host, port)

while true
  text, sender = server.recvfrom(RECV_BUFFER)
  remote_host = sender[3]
  STDOUT.puts "#{remote_host}:" + text
end
