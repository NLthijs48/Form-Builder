tr = I18n.tr

exports.render = ->
	Comments.disable()

	Dom.style
		height: '100%'
		backgroundColor: '#EEE'

	page = Page.state.get 0
	if page? # Form id
		new FormLayout
			formId: page
	else if App.memberIsAdmin() and false # TODO remove
		renderOverview()
	else
		new FormLayout()

renderOverview = !->
	Ui.emptyText "Overview layout..."

# Form object
class FormLayout
	constructor: (opts) ->
		form = @
		opts = {} if !opts?

		@editingO = Obs.create()
		Obs.observe !->
			form.editingO.set Page.state.get('?edit')
		@entries = {}
		@formId = opts.formId

		@render()

	render: !->
		form = @

		# Add edit button
		Obs.observe !->
			return if !App.memberIsAdmin()
			if form.editingO.get()
				Page.setActions
					icon: 'good2'
					label: "Stop editing"
					action: !->
						Page.state.remove '?edit'
			else
				Page.setActions
					icon: 'edit'
					label: "Edit form"
					action: !->
						Page.state.set '?edit', true

		# Submit
		Obs.observe !->
			return if form.editingO.get()
			Form.setPageSubmit (values) !->
				log 'onSubmit'

		# Add entry button
		Obs.observe !->
			return if !form.editingO.get()
			Page.setFooter
				label: tr("Add form part")
				icon: 'add'
				action: !->
					form.addPart()

		# Render form parts
		Db.shared.iterate 'form', 'entries', (entryO) !->
			type = entryO.get('type')
			entry = makeType type, form, entryO
			if entry?
				entry.render()
			else
				log '[renderForm] Unknown form type:', type, 'entry:', entryO.key()
		, (entryO) ->
			entryO.get 'order'


	# Add a new part
	addPart: !->
		form = @

		Modal.show tr("Add a part"), !->
			renderItem = (entry) !->
				Ui.item
					content: entry.displayName
					sub: entry.description
					onTap: !->
						makeType(entry.entryType, form).edit()
						Modal.remove()
			for entry in entries
				renderItem entry
		, undefined
		, false # No buttons


makeType = (type, form, dataO) ->
	if !dataO?
		dataO = Obs.create
			type: type
	if type is 'textline'
		new TextlineEntry(form, dataO)
	else if type is 'instruction'
		new InstructionEntry(form, dataO)
	else if type is 'selection'
		new SelectionEntry(form, dataO)


# User view
renderUserView = !->
	Ui.button "New staff application", !->
		Page.nav 'form'

# Admin view
renderAdminView = !->
	Dom.text "Applications..."


# General form entry
class Entry
	constructor: (form, dataO) ->
		@form = form
		@dataO = if dataO? then dataO else Obs.create()
		@identifier = @dataO.key()
		@containerE = undefined # Container dom element
		@margin = 4
		entry = @
		form.entries[@dataO.key()] = entry if @dataO.key()?

	render: !->
		entry = @

		Dom.div !->
			Dom.style
				background: '#fff'
				MarginPolicy: 'pad'
				paddingTop: '8px'
				paddingBottom: '8px'
				marginTop: "#{entry.margin}px"
				marginBottom: "#{entry.margin}px"
				overflow: 'hidden'
				position: 'relative'
			entry.containerE = Dom.get()
			if entry.form.editingO.get()
				Dom.div !->
					Dom.style
						Box: 'horizontal middle'
					# Order buttons
					Dom.div !->
						Dom.style
							Box: 'vertical middle center'
						Dom.div !->
							Dom.style
								padding: '10px'
								marginLeft: '-10px'
							Dom.div !->
								Dom.style
									borderStyle: 'solid'
									borderWidth: '0 7px 10px 7px'
									borderColor: 'transparent transparent #BA1A6E transparent'
							Dom.onTap !->
								entry.move 'up'


						Dom.div !->
							Dom.style
								padding: '10px'
								marginLeft: '-10px'
							Dom.div !->
								Dom.style
									borderStyle: 'solid'
									borderWidth: '10px 7px 0 7px'
									borderColor: '#BA1A6E transparent transparent transparent'
							Dom.onTap !->
								entry.move 'down'
					# Content
					Dom.div !->
						Dom.style Flex: true
						entry.renderType()
					# Right side buttons
					Dom.div !->
						Dom.style Box: 'vertical middle center'
						# Edit button
						Icon.render
							data: 'edit'
							color: '#BA1A6E'
							size: 20
							style:
								padding: '10px'
								marginRight: '-10px'
								marginTop: '-10px'
							onTap: !->
								entry.edit()
						# Remove button
						Icon.render
							data: 'trash'
							color: '#BA1A6E'
							size: 20
							style:
								padding: '10px'
								marginRight: '-10px'
								marginBottom: '-10px'
							onTap: !->
								Modal.confirm tr("Remove?"), tr("Are you sure you want to remove this component?"), (value) !->
									entry.containerE.transition (element) ->
										initial:
											height: element.height()+'px'
										time: 200
										opacity: 0
										height: 0
										paddingTop: 0
										paddingBottom: 0
										onDone: !->
											Server.sync 'removeEntry', entry.dataO.key(), !->
												Db.shared.remove 'form', 'entries', entry.dataO.key()
			else
				Dom.div !->
					entry.renderType()


	# Move the entry up or down
	move: (direction) !->
		entry = @

		order = entry.dataO.peek 'order'
		swapWith = undefined
		currentOrder = undefined
		for identifier,check of entry.form.entries
			entryOrder = check.dataO.peek 'order'
			if direction is 'up' and entryOrder < order
				if !currentOrder? or entryOrder > currentOrder
					swapWith = check
					currentOrder = entryOrder
			else if entryOrder > order
				if !currentOrder? or entryOrder < currentOrder
					swapWith = check
					currentOrder = entryOrder
		if !swapWith
			log '[Entry.move] nothing to move to, direction:', direction
			return

		# Visually swap, then confirm
		time = 200
		selfHeight = entry.containerE.height()
		otherHeight = swapWith.containerE.height()
		entry.containerE.transition
			initial:
				zIndex: 1
			Translate: [0,(if direction is 'up' then -1 else 1)*(otherHeight+entry.margin)]
			time: time
			onDone: !->
				Server.sync 'swapEntries', entry.dataO.key(), swapWith.dataO.key(), !->
					swapWith.dataO.set 'order', entry.dataO.peek('order')
					entry.dataO.set 'order', currentOrder
		swapWith.containerE.transition
			Translate: [0,(if direction is 'up' then 1 else -1)*(selfHeight+swapWith.margin)]
			time: time

	# Edit details
	# opts.cb: callback that is called with the result
	edit: (opts) !->
		entry = @

		Page.nav !->
			entry.renderEdit()

			# Give back the result
			Form.setPageSubmit (values) !->
				values.type = entry.dataO.peek 'type'
				if (order = entry.dataO.peek 'order')?
					values.order = order

				Server.sync 'editEntry', entry.identifier, values, !->
					if !entry.identifier?
						# Copy to prevent changing the actual values instance for the server call
						data = {}
						for k,v of values
							data[k] = v
						data.order = 0
						Db.shared.iterate 'form', 'entries', (entryO) !->
							o = ((+entryO.peek('order'))||0)
							data.order = o+1 if o >= data.order
					Db.shared.set 'form', 'entries', entry.identifier, data ? values
				Page.back()

	# Render a required checkbox
	renderRequired: !->
		Form.check
			name: 'required'
			value: @dataO.get 'required'
			text: tr('Field is required')
			sub: tr('Make it mandatory to enter this field')

	# Markdown description field
	renderDescription: ->
		Form.smallLabel !->
			Dom.style marginTop: 0
			Dom.text 'Markdown can be used' # TODO link to markdown explanation?
		Form.text
			name: 'description'
			value: @dataO.get 'description'
			style:
				marginTop: '8px'
				marginBottom: '5px'

# Text line entry
class TextlineEntry extends Entry
	@entryType: 'textline'
	@displayName: tr("Text line")
	@description: tr("A single line of text")

	renderType: !->
		entry = @

		# Description
		if (description = entry.dataO.get('description'))?
			Dom.markdown description
		# Input
		Form.input
			name: entry.identifier
			style:
				marginTop: '3px'
				marginBottom: 0
		# Required or not
		if entry.dataO.get 'required' # TODO render star somewhere?
			Form.condition (value) ->
				return tr("This field is required") if !value[entry.identifier]


	renderEdit: !->
		entry = @

		Form.label tr('Description')
		entry.renderDescription().focus()
		entry.renderRequired()


# Markdown entry
class InstructionEntry extends Entry
	@entryType: 'instruction'
	@displayName: tr("Instruction block")
	@description: tr("A markdown block with instructions or an explanation")

	renderType: !->
		entry = @

		if (description = entry.dataO.get('description'))?
			Dom.markdown description

	renderEdit: !->
		entry = @

		Form.label tr('Instructions')
		entry.renderDescription().focus()


# Selector
class SelectionEntry extends Entry
	@entryType: 'selection'
	@displayName: tr("Selection list")
	@description: tr("A list in which items can be ticked")

	renderType: !->
		entry = @

		# Description
		if (description = entry.dataO.get 'description')?
			Dom.markdown description

		###
		Form.segmented
			name: 'mode'
			value: 'single'
			segments: ['one', tr("Thing one"), 'two', tr("Thing two")]
			description: !->
				Dom.text tr("Select a thing")
			onChange: (v) !->
				log 'new:', v


		Dom.css
			'.form-check:checked':
				border: '2px solid green !important'
				backgroundColor: 'green !important'

		Form.check
			name: 'check'
			text: "Instruction"
			sub: "More detail in here somewhere"
			style:
				borderRadius: '50%'
				border: '2px solid #777'
				background: 'none'
			onChange: (v) !->
				log 'checked:', v
		###


	renderEdit: !->
		entry = @

		# Description
		Form.label tr('Description')
		entry.renderDescription().focus()

		# Options
		options = Obs.create entry.dataO.get('options')
		Form.label tr("")


# List of all entries
entries = [TextlineEntry, InstructionEntry, SelectionEntry]