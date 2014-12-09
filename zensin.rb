require 'sinatra'
require 'zendesk_api'
require 'yaml'
require 'json'

class Ticket
	attr_accessor :ticket_id
	attr_accessor :satisfaction_feedback
	attr_accessor :feedback
	
	def initialize(ticket)
		yaml_in = YAML.load(ticket.description.gsub(/\r\n/,'\n').gsub(/(?<!\n)\n(?!\n)/,'!!!!!'))
		@satisfaction_feedback = yaml_in['satisfaction_feedback']
		@feedback = yaml_in['improvement_feedback']
		@ticket_id = ticket.id
	end

	def satisfaction_rating
		@output = 0
		if !@satisfaction_feedback.nil? && !@satisfaction_feedback.empty?
			case @satisfaction_feedback
			when 'very_satisfied'
				output = 5
	        when 'satisfied'
	        	output = 4
	        when 'neither_satisfied_or_dissatisfied'
	        	output = 3
	        when 'dissatisfied'
	        	output =  2
	        when 'very_dissatisfied'
	        	output = 1
	        else
	        	output = 0
	        end
    	end
    	output
    end


    def to_json
        { ticket_id: @ticket_id, satisfaction_rating: self.satisfaction_rating, feedback: @feedback.to_s}.to_json
    end
 	def to_hash
		hash = {}
		instance_variables.each {|var| hash[var.to_s.delete("@")] = instance_variable_get(var) }
		hash
	end
end

get '/' do
	'zendesk > json for geckboard'
end

get '/:view/count' do

	view = client.view.find(id: params[:view]) # '48000166')
	tickets = view.tickets
	first = tickets.first
	desc = first.description

	hash = YAML.load(desc)

	tick = Ticket.new(first)

	"count=#{tickets.count}"
end

get '/:view/first_ticket' do

	view = client.view.find(id: params[:view]) # '48000166')
	tickets = view.tickets
	first = tickets.first
	desc = first.description

	hash = YAML.load(desc)

	tick = Ticket.new(first)

	"first_ticket=#{tick.to_json}"
end

get '/ticket/:ticket' do
	ticket = Ticket.new(client.tickets.find(id: params[:ticket]))
	"#{ticket.to_json}"
end

get '/:view/scores_piechart' do
	view = client.view.find(id: params[:view]) 

	@result = []
	view.tickets.each do |t|
		begin
			ticket = Ticket.new(t)
			@result.push(JSON.parse({ value: ticket.satisfaction_rating, label: ticket.satisfaction_feedback }.to_json))
		rescue => e
			puts '-------------------'
			puts " -- Ticket #{t.id} -- "
			puts "error messaage : #{e.message}"
		end
	end


	@result.to_json

end

get '/test/:view' do

	view = client.view.find(id: params[:view]) 

	@result = []
	view.tickets.each do |t|
		begin
			@result.push(JSON.parse(Ticket.new(t).to_json))
		rescue => e
			puts '-------------------'
			puts " -- Ticket #{t.id} -- "
			puts "error messaage : #{e.message}"
		end
	end
	@result.to_json
end

private 

def client 
	client = ZendeskAPI::Client.new do |config|
	  config.url = 'https://ministryofjustice.zendesk.com/api/v2'
	  config.username = ENV['zen_key']
	  config.token = ENV['zen_token']
	  config.retry = true
	end
	client
end