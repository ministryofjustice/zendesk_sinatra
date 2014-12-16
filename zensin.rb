require 'sinatra'
require 'zendesk_api'
require 'yaml'
require 'json'

class Ticket
	attr_accessor :ticket_id
	attr_accessor :satisfaction_feedback
	attr_accessor :improvement_feedback
	attr_accessor :difficulty_feedback
	attr_accessor :help_feedback
	attr_accessor :other

	
	def initialize(ticket)
		yaml_in = YAML.load(ticket.description.gsub(/\r\n/,'\n').gsub(/(?<!\n)\n(?!\n)/,'!!!!!'))
		@satisfaction_feedback = flatten_feedback(yaml_in['satisfaction_feedback'])
		@improvement_feedback = yaml_in['improvement_feedback']
		@difficulty_feedback = yaml_in['difficulty_feedback']
		@help_feedback = flatten_feedback(yaml_in['help_feedback'])
		@other = yaml_in['other']
		@ticket_id = ticket.id
	end

	def satisfaction_rating
		@output = 0
		if !@satisfaction_feedback.nil? && !@satisfaction_feedback.empty?
			case @satisfaction_feedback.downcase.gsub(/[_]/,' ')
			when 'very satisfied'
				output = 6
	        when 'satisfied'
	        	output = 5
	        when 'neither satisfied or dissatisfied'
	        	output = 4
	        when 'dissatisfied'
	        	output = 3
	        when 'very dissatisfied'
	        	output = 2
	        when 'not completed'
	        	output = 1
	        else
	        	puts "=====#{@satisfaction_feedback}"
	        	output = 0
	        end
    	end
    	output
    end
    def help_feedback_rating
		@output = 0
		if !@help_feedback.nil? && !@help_feedback.empty?
			case @help_feedback.downcase.gsub(/[_]/,' ')
			when 'filled in myself'
	        	output = 5
			when 'filled in for me'
	        	output = 4
			when 'used accessibility tool'
	        	output = 3
			when 'other help'
	        	output = 2
	        when 'not completed'
	        	output = 1
	        else 
	        	output = 1
	        end
    	end
    	output
    end
    def to_json
        { 
        	ticket_id: @ticket_id, 
        	satisfaction_rating: self.satisfaction_rating, 
        	improvement_feedback: @improvement_feedback.to_s, 
        	difficulty_feedback: @difficulty_feedback.to_s,
        	help_feedback_rating: self.help_feedback_rating,
        	help_feedback: @help_feedback.to_s,
        	other: self.other.to_s
    	}.to_json
    end

end

get '/:view/count' do

	view = client.view.find(id: params[:view]) # '48000166')
	tickets = view.tickets

	"count=#{tickets.count}"
end

get '/ticket/:ticket' do
	ticket = Ticket.new(client.tickets.find(id: params[:ticket])) #3506
	"#{ticket.to_json}"
end

get '/:view/piechart_data/:type' do
	view = client.view.find(id: params[:view]) 

	@result = []
	view.tickets.each do |t|
		begin
			ticket = Ticket.new(t)
			if params[:type] == 'satisfaction'
				if !ticket.satisfaction_rating.nil? && !ticket.satisfaction_feedback.nil?
					@result.push(JSON.parse({ value: ticket.satisfaction_rating, label: ticket.satisfaction_feedback }.to_json))
				end
			else
				if !ticket.help_feedback_rating.nil? && !ticket.help_feedback.nil?
					@result.push(JSON.parse({ value: ticket.help_feedback_rating, label: ticket.help_feedback }.to_json))
				end
			end
		rescue => e
			puts '-------------------'
			puts " -- Ticket #{t.id} -- "
			puts "error messaage : #{e.message}"
		end
	end
	@counted = []

	
	values = [
			{ label: 'very satisfied', colour: '339900'}, 
			{ label: 'satisfied', colour: '99cc66'}, 
			{ label: 'neither satisfied or dissatisfied', colour: '999999'}, 
			{ label: 'dissatisfied', colour: 'ff8533'}, 
			{ label: 'very dissatisfied', colour: 'd84000'},
			{ label: 'not completed', colour: 'ff3300'},
		] if params[:type] == 'satisfaction'
	
	values = [
			{ label: 'filled in myself', colour: 'd0ff00'}, 
			{ label: 'filled in for me', colour: 'ff0051'}, 
			{ label: 'used accessibility tool', colour: 'ae00ff'}, 
			{ label: 'other help', colour: '685aff'}, 
			{ label: 'not completed', colour: 'd84000'}, 
		] if params[:type] == 'help'

	values.each do |obj|
		count = @result.select{ |f| f['label'] == obj[:label] }.count
		@counted.push( JSON.parse( { value: count, label: "#{obj[:label]} (#{count})", color: obj[:colour]  }.to_json ) )
	end
	@output = { item: @counted }

	@output.to_json
end

get '/:view/feedback/:type' do
	view = client.view.find(id: params[:view]) 

	@result = []
	view.tickets.each do |t|
		begin
			ticket = Ticket.new(t)
			case params[:type]
			when 'improvement'
				if !ticket.improvement_feedback.nil? 
					@result.push(JSON.parse({ text: ticket.improvement_feedback, description: "Ticket:#{ticket.ticket_id}" }.to_json))
				end

			end
		rescue => e
			puts '-------------------'
			puts " -- Ticket #{t.id} -- "
			puts "error messaage : #{e.message}"
		end
	end
	@output = { item: @result }
	@output.to_json
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

def flatten_feedback(text_in)
	out = text_in.downcase.gsub(/[_]/,' ') if !text_in.nil?
	case out
	when 'no, i filled in this form myself'
    	out = 'filled in myself'
	when 'i had some other kind of help'
    	out = 'other help'
    when nil, ''
    	out = 'not completed'
    end
	out
end
