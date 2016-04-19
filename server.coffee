# SHARED:
#	form:
#		entries:
#			<identifier>:
#				name: <string> # Name of the entry
#				required: <boolean> # Required or not
#				type: <textline|textarea|instructions...>
#				maxLength: <number> # Maximum line length
#	results:
#		maxId: <number>
#		<id>:
#			<identifier>: <value> # Value for the entry

exports.onUpgrade = !->
	# Test data
	Db.shared.set "form",
		entries:
			header:
				type: "instruction"
				markdown: """
					# Staff application
					Make your staff application here
				"""
				order: 0
			firstname:
				type: "textline"
				order: 1
				name: "First name"
				required: true
			lastname:
				type: "textline"
				order: 2
				name: "Last name"
				required: true
			username:
				type: "textline"
				order: 3
				name: "Username"
				required: true
			country:
				type: "textline"
				order: 4
				name: "Country"
				required: true


# Remove an entry from the form
exports.client_removeEntry = (identifier) !->
	App.assertAdmin()
	log "[removeEntry] by #{member()}, identifier:", identifier

	Db.shared.remove 'form', 'entries', identifier


# Swap two entries
exports.client_swapEntries = (firstIdentifier, secondIdentifier) !->
	App.assertAdmin()
	log "[swapEntries] by #{member()}:", firstIdentifier, 'and', secondIdentifier

	return if !firstIdentifier? or !secondIdentifier?
	first = Db.shared.ref 'form', 'entries', firstIdentifier
	second = Db.shared.ref 'form', 'entries', secondIdentifier
	return if !first.peek()? or !second.peek()?

	firstOrder = first.peek 'order'
	first.set 'order', second.peek('order')
	second.set 'order', firstOrder


# Add an entry
exports.client_addEntry = (identifier, data) !->
	App.assertAdmin()
	log "[addEntry] by #{member()}, identifier:", identifier, 'data:', JSON.stringify(data)

	return if !identifier? or !data?
	entry = Db.shared.ref 'form', 'entries', identifier
	if entry.peek()?
		log '[addEntry] already exists!'
		return
	entry.set data


# Edit an entry
exports.client_editEntry = (identifier, data) !->
	App.assertAdmin()
	log "[editEntry] by #{member()}, identifier:", identifier, 'data:', JSON.stringify(data)

	return if !identifier? or !data?
	Db.shared.set 'form', 'entries', identifier, data


# Print member details
member = (memberId) ->
	memberId = App.memberId() if !memberId?
	"#{App.userName(memberId)}(#{memberId})"