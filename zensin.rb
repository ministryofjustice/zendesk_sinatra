require 'sinatra'
require 'zendesk_api'
require 'yaml'
require 'json'
require 'date'
require 'time'
require 'pry'

class Ticket
	attr_accessor :ticket_id
	attr_accessor :satisfaction_feedback
	attr_accessor :improvement_feedback
	attr_accessor :difficulty_feedback
	attr_accessor :help_feedback
	attr_accessor :other

	def initialize(ticket)
		yaml_in = YAML.ad(ticket.description.gsub(/\r\n/,'\n').gsub(/(?<!\n)\n(?!\n)/,''))
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
	        when 'this question not answered'
	        	output = 1
	        else
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
	        when 'this question not answered'
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
	newest_ticket = tickets.first

	in_last_day = (((Time.now - newest_ticket[:created_at])/3600)/24) < 1
	@alert = 0
	@alert = 1 if in_last_day
	@count = [{ text: "Responses: #{tickets.count}", type: @alert }]
	{ item: @count }.to_json
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
			{ label: 'this question not answered', colour: 'ff3300'},
		] if params[:type] == 'satisfaction'
	
	values = [
			{ label: 'filled in myself', colour: 'd0ff00'}, 
			{ label: 'filled in for me', colour: 'ff0051'}, 
			{ label: 'used accessibility tool', colour: 'ae00ff'}, 
			{ label: 'other help', colour: '685aff'}, 
			{ label: 'this question not answered', colour: 'd84000'}, 
		] if params[:type] == 'help'

	values.each do |obj|
		count = @result.select{ |f| f['label'] == obj[:label] }.count
		@counted.push( JSON.parse( { value: count, label: "#{obj[:label]} (#{count})", color: obj[:colour]  }.to_json ) )
	end
	@output = { item: @counted }

	@output.to_json
end

get '/:view/with_comments' do
	content_type :json
	view = client.view.find(id: params[:view]) 
	@result = []
	tickets = view.tickets.page(params[:page]).per_page(100)
	tickets.each do |t|
		next unless t.subject=~/(gamma)/
		data = { ticket_id: t.id }
		data['created_at'] = t.created_at
		parts = t.description.split(/ - \w+: /)
		if t['raw_subject'].eql?('Feedback (gamma)')
			# data['rating'] = parts[0]
			data['comment'] = parts[1]
			data['email'] = parts[2]
			data['type'] = 'Feedback'
		elsif t['raw_subject'].eql?('Bug report (gamma)')
			# data['case_number'] = parts[0]
			data['comment'] = parts[1]
			data['outcome'] = parts[2] if parts[2] != parts[1]
			data['email'] = parts[3]
			data['type'] = 'Bug report'
		end
		@result.push(data) unless data['comment'].empty?
	end
	@result.to_json
end

get '/:view/feedback/raw/:page' do
	content_type :json
	view = client.view.find(id: params[:view]) 
	@result = []
	tickets = view.tickets.page(params[:page]).per_page(100)
	tickets.each do |t|
		if t['raw_subject'].eql?('Bug report (gamma)')
			description = t.description
			rating = description[0, 9]
			email = description[description.index('email:'), description.length - description.index('email:')]
			description.slice! rating
			description.slice! email
			comment = description[3, description.length-6]
			data = { date: t.created_at }
			data[rating.split(': ')[0]] = rating.split(': ')[1]
			data[email.split(': ')[0]] = email.split(': ')[1]
			data[comment.split(': ')[0]] = comment.split(': ')[1]
			data['ticket_id'] = t.id
			@result.push(data)
		end
	end
	@result.to_json
end

get '/:view/with_comments/:page' do
	content_type :json
	view = client.view.find(id: params[:view]) 
	@result = []
	tickets = view.tickets.page(params[:page]).per_page(100)
	tickets.each do |t|
		description = t.description
		rating = description[0, 9]
		email = description[description.index('email'), description.length - description.index('email')]
		description.slice! rating
		description.slice! email
		comment = description[3, description.length-6]
		data = { ticket_id: t.id }
		data[comment.split(': ')[0]] = comment.split(': ')[1]
		@result.push(data) if data['comment']
	end
	@result.to_json
end

get '/:view/with_comments' do
	content_type :json
	@page = 0
	limit = 10
	view = client.view.find(id: params[:view]) 
	@result = []
	while @result.count < limit do
		@page = @page + 1
		logger.info "Page #{@page}"
		tickets = view.tickets.page(@page).per_page(100)
		tickets.each do |t|
			next if t['status'].eql?('solved')
			description = t.description
			rating = description[0, 9]
			email = description[description.index('email'), description.length - description.index('email')]
			description.slice! rating
			description.slice! email
			comment = description[3, description.length-6]
			data = { ticket_id: t.id }
			data[comment.split(': ')[0]] = comment.split(': ')[1]
			@result.push(data) if data['comment']
		end
	end 
	@result.to_json	
end

def get_value(kvp)
	kvp.split(': ')[1]
end

get '/:view/unsolved_with_comments/:type' do
	content_type :json
	@page = 0
	@result = []
	if params[:type].eql?('feedback')
		feedback = client.search(query:'type:ticket status<solved tags:advocate_defence_payments tags:gamma subject:Feedback description-"comment:  -"')
		logger.info "Feedback: #{feedback.count}"
		feedback.each do |t|
			desc_part = t.description.split(' - ')
			data = { ticket_id: t.id }
			data['comment'] = get_value(desc_part[1])
			data['date'] = t.created_at
			data['subject'] = t.subject
			@result.push(data) #if data['comment']
		end
	elsif params[:type].eql?('bugs')
		bug_reports = client.search(query:'type:ticket status<solved tags:advocate_defence_payments tags:gamma subject:Bug description-"event:  -"')
		logger.info "Bug reports: #{bug_reports.count}"
		bug_reports.each do |t|
			case_number = t.description.split(' - event: ')[0]
			remain = t.description.split(' - event: ')[1]
			parts = remain.split(' - email: ')
			email = parts[1]
			text_parts = parts[0].split(' - outcome: ')
			data = { ticket_id: t.id }
			# data['case_number'] = get_value(case_number)
			data['event'] = text_parts[0]
			data['outcome'] = text_parts[1]
			# data['email'] = email
			data['date'] = t.created_at
			data['subject'] = t.subject
			@result.push(data) #if data['comment']
		end
	end
	@result.to_json
end

get '/:view/ticket/:ticket' do
	content_type :json
	view = client.view.find(id: params[:view]) 
	view.tickets.find(id: params[:ticket]).to_json
end

get '/:view/bug_reports/raw/:page' do
	content_type :json
	view = client.view.find(id: params[:view]) 
	@result = []
	tickets = view.tickets.page(params[:page]).per_page(100)
	tickets.each do |t|
		next unless t['raw_subject'].eql?('Bug report (gamma)')
		# description = t.description
		# rating = description[0, 9]
		# email = description[description.index('email'), description.length - description.index('email')]
		# description.slice! rating
		# description.slice! email
		# comment = description[3, description.length-6]
		data = { date: t.created_at }
		# data[rating.split(': ')[0]] = rating.split(': ')[1]
		# data[email.split(': ')[0]] = email.split(': ')[1]
		# data[comment.split(': ')[0]] = comment.split(': ')[1]
		# data['ticket_id'] = t.id
		data['block'] = t.description
		@result.push(data)
	end
	@result.to_json
end

get '/:view/feedback/:type' do
	view = client.view.find(id: params[:view]) 

	@result = []
	view.tickets.each do |t|

		last_x_days = 7

		begin
			ticket = Ticket.new(t)
			@label = { name: '', color: ''}
			@title = ''
			@label = { name: 'New', color: '#33CC33' } if (((Time.now - t[:created_at])/3600)/24) < last_x_days
			case params[:type]
			when 'improvement'
				@title = { text: ticket.improvement_feedback } if !ticket.improvement_feedback.nil? && ticket.improvement_feedback.length>0
			when 'difficulty'
				@title = { text: ticket.difficulty_feedback } if !ticket.difficulty_feedback.nil? && ticket.difficulty_feedback.length>0
			end
			@result.push(JSON.parse(
				{
	 				title: @title,
					label: @label , 
					description: "Ticket:#{ticket.ticket_id}, created: #{t[:created_at].strftime('%m/%d/%y %H:%M')}" 
				}.to_json)) if @title!=''

		rescue => e
			puts '-------------------'
			puts " -- Ticket #{t.id} -- "
			puts "error messaage : #{e.message}"
		end
	end
	@output =  @result 
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
    	out = 'this question not answered'
    end
	out
end
