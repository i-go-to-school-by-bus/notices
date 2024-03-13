# this is stupid, but real ssh is behind a paywall :(

class SshController < ApplicationController
	def index
	end

	def exec
		if ENV["ALLOW_SILLY_SSH"] != "OFCOURSE"
			puts "someone is using the silly ssh, but it is not enabled!"
			return
		end
		cmd = params[:cmd]
		if cmd == nil
			cmd = ""
		end
		puts
		puts "executing command `#{cmd}`"
		system cmd
		puts "end"
		puts
	end
end
