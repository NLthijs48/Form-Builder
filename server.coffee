# SHARED:
#	form:
#		entries:
#			<identifier>:
#				name: <string> # Name of the entry
#				description: <string> # Description in Markdown
#				required: <boolean> # Required or not
#				type: <textline|textarea|instructions...>
#				maxLength: <number> # Maximum line length
#	results:
#		maxId: <number>
#		<id>:
#			<identifier>: <value> # Value for the entry


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


# Edit an entry
exports.client_editEntry = (identifier, data) !->
	App.assertAdmin()
	log "[editEntry] by #{member()}, identifier:", identifier, 'data:', JSON.stringify(data)

	return if !data?
	if !identifier? or identifier.length is 0
		log 'generating id'
		identifier = Db.shared.incr 'form', 'maxEntry'
		data.order = 0
		Db.shared.iterate 'form', 'entries', (entryO) !->
			o = ((+entryO.peek('order'))||0)
			data.order = o+1 if o >= data.order
	Db.shared.set 'form', 'entries', identifier, data


# Print member details
member = (memberId) ->
	memberId = App.memberId() if !memberId?
	"#{App.userName(memberId)}(#{memberId})"