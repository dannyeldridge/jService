


 # Arguments are seasons to grab. [1,30] grabs seasons 1 through 30
task :get_clues, [:arg1, :arg2] => :environment do |t, args|
	require 'nokogiri'
	require 'open-uri'
	require 'chronic'
	require 'byebug'
  
	arg1int = args.arg1.to_s.match?(/\A[+-]?\d+?(\.\d+)?\Z/)
	arg2int = args.arg2.to_s.match?(/\A[+-]?\d+?(\.\d+)?\Z/)
	if arg1int && arg2int
	  # Get game list
	  gameIds = []
	  (args.arg1.to_i..args.arg2.to_i).each do |i|
		seasonsUrl = "http://j-archive.com/showseason.php?season=#{i}"
		seasonList = Nokogiri::HTML(URI.open(seasonsUrl))
		linkList = seasonList.css('table td a')
		linkList.each do |ll|
		  href = ll.attr('href').split('id=')[1]
		  gameIds.push(href)
		end
	  end
  
	  gameIds.each do |gid|
		gameurl = "http://www.j-archive.com/showgame.php?game_id=#{gid}"
		game = Nokogiri::HTML(URI.open(gameurl))
  
		# Define vars
		var_question = ''
		var_answer = ''
		var_value = ''
		var_category = ''
		var_airdate = nil
  
		# Get an array of the category names, we'll need these later
		categoryArr = game.css('#jeopardy_round .category_name').map do |c|
		  categoryName = c.text().downcase
		  Category.find_or_create_by(title: categoryName)
		end
  
		# Get the airdate
		ad = game.css('#game_title h1').text.split(" - ")
		if ad[1]
		  var_airdate = Chronic.parse(ad[1])
		  puts "Working on: #{ad[1]}"
		end
  
		# Process each question
		game.css('tr').each do |tr_node|
		  clue_text_node = tr_node.at_css('.clue_text')
		  correct_response_node = tr_node.at_css('em.correct_response')
  
		  if clue_text_node && correct_response_node
			var_question = clue_text_node.text.strip
			var_answer = correct_response_node.text.strip
			if tr_node.previous_element
				var_value = tr_node.previous_element.css('.clue_value').text[/[0-9,]+/]
	
				# Assuming category index needs to be determined from the position of the clue.
				# This might need adjustment based on actual requirement and structure.
				index = clue_text_node.parent.parent.parent.css('.clue_text').index(clue_text_node)
				var_category = categoryArr[index]
	
				unless var_value.nil?
					newClue = Clue.where(
					question: var_question,
					answer: var_answer,
					category: var_category,
					value: var_value.gsub(',', ''), # Remove commas for thousands
					airdate: var_airdate,
					game_id: gid
					).first_or_create
		
					puts "Added clue: #{var_question}"
				end
			end
		  end
		end
	  end
	else
	  puts "Invalid arguments. Please provide valid season numbers."
	end
  end
  