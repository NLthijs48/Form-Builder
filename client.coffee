tr = I18n.tr

exports.render = ->
	Comments.disable()

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

		Modal.show tr("What do you want to add?"), !->
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
		entry = @
		form.entries[@dataO.key()] = entry if @dataO.key()?

	render: !->
		entry = @

		Dom.div !->
			Dom.style
				background: '#fff'
				padding: '0 12px'
				margin: '12px 0'
				overflow: 'hidden'
				position: 'relative'
			entry.containerE = Dom.get()
			iconColor = '#ba1a6e'
			if entry.form.editingO.get()
				Dom.div !->
					Dom.style
						Box: 'horizontal middle'
					# Order buttons
					Dom.div !->
						# Up
						Dom.style
							Box: 'horizontal middle center'
						Dom.div !->
							Dom.style
								padding: '10px 8px'
								marginLeft: '-12px'
							Dom.div !->
								Dom.style
									borderStyle: 'solid'
									borderWidth: '0 9px 14px 9px'
									borderColor: "transparent transparent #{iconColor} transparent"
							Dom.onTap !->
								entry.move 'up'
						# Down
						Dom.div !->
							Dom.style
								padding: '10px 8px'
								marginRight: '10px'
							Dom.div !->
								Dom.style
									borderStyle: 'solid'
									borderWidth: '14px 9px 0 9px'
									borderColor: "#{iconColor} transparent transparent transparent"
							Dom.onTap !->
								entry.move 'down'
					# Content
					Dom.div !->
						Dom.style Flex: true
						entry.renderType()
					# Right side buttons
					Dom.div !->
						Dom.style Box: 'horizontal middle center'
						# Edit button
						Icon.render
							data: 'edit'
							color: iconColor
							size: 20
							style:
								padding: '10px'
								marginTop: '-10px'
								marginBottom: '-10px'
								marginLeft: '10px'
							onTap: !->
								entry.edit()
						# Remove button
						Icon.render
							data: 'trash'
							color: iconColor
							size: 20
							style:
								padding: '10px'
								marginTop: '-10px'
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
			Translate: [0,(if direction is 'up' then -1 else 1)*(otherHeight+12)]
			time: time
			onDone: !->
				Server.sync 'swapEntries', entry.dataO.key(), swapWith.dataO.key(), !->
					swapWith.dataO.set 'order', entry.dataO.peek('order')
					entry.dataO.set 'order', currentOrder
		swapWith.containerE.transition
			Translate: [0,(if direction is 'up' then 1 else -1)*(selfHeight+12)]
			time: time

	# Edit details
	edit: !->
		entry = @
		editing = entry.dataO.peek('order')?

		submit = (values = {}) !->
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

		Page.nav !->
			if entry.renderEdit() is false # Nothing to edit
				submit()
				return

			Page.setTitle if editing then tr("Editing %1", entry.constructor.displayName.toLowerCase()) else tr("Adding %1", entry.constructor.displayName.toLowerCase())

			# Give back the result
			Form.setPageSubmit submit, if editing then undefined else 2

	# Render a required checkbox
	renderRequired: !->
		Form.check
			name: 'required'
			value: @dataO.get 'required'
			text: tr('Field is required')
			sub: tr('Make it mandatory to enter this field')


# Separator line
class SeparatorEntry extends Entry
	@entryType: 'separator'
	@displayName: tr("Separator line")
	@description: tr("A line to visually separate sections of the form")

	renderType: !->
		entry = @
		Dom.style
			minHeight: if (height = entry.dataO.get('height'))? and height.length > 0 then height else '5px'
			backgroundColor: '#eee'
			padding: 0
			marginBottom: 0

	renderEdit: !->
		entry = @
		Form.label tr("Separator height")
		Form.input
			name: 'height'
			text: '5px'
			autofocus: true
			value: entry.dataO.get 'height'
			style:
				marginTop: '3px'
				marginBottom: 0


# Markdown instruction block
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
		Form.smallLabel !->
			Dom.style marginTop: 0
			Dom.text 'Markdown can be used' # TODO link to markdown explanation?
		field = Form.text
			name: 'description'
			value: @dataO.get 'description'
			style:
				marginTop: '8px'
				marginBottom: '5px'
		field.focus()


# Text line entry
class TextlineEntry extends Entry
	@entryType: 'textline'
	@displayName: tr("Text line")
	@description: tr("A single line of text")

	renderType: !->
		entry = @
		Form.input
			name: entry.identifier
			style:
				marginTop: '2px'
				marginBottom: '4px'
		if entry.dataO.get 'required'
			Dom.div !->
				Dom.style
					marginTop: '12px'
					marginBottom: '-12px'
				Form.condition (value) ->
					return tr("You need to fill in this field") if !value[entry.identifier]


	renderEdit: !->
		entry = @

		entry.renderRequired()


# Text area entry
class TextareaEntry extends Entry
	@entryType: 'textarea'
	@displayName: tr("Text area")
	@description: tr("A text area for writing more than one line of text")

	renderType: !->
		entry = @
		Form.text
			name: entry.identifier
			style:
				marginTop: '8px'
				marginBottom: '5px'
		if entry.dataO.get 'required'
			Dom.div !->
				Dom.style
					marginTop: '12px'
					marginBottom: '-12px'
				Form.condition (value) ->
					return tr("You need to fill in this textarea") if !value[entry.identifier]


	renderEdit: !->
		entry = @

		entry.renderRequired()


# Checkbox
class CheckboxEntry extends Entry
	@entryType: 'checkbox'
	@displayName: tr("Checkbox")
	@description: tr("A checkbox that can be ticked")

	renderType: !->
		entry = @
		Form.check
			name: !->
				Dom.style padding: '0 12px'
				Dom.text entry.identifier
			text: entry.dataO.get 'title'
			sub: entry.dataO.get 'description'
		if entry.dataO.get 'required' # TODO render star somewhere?
			Form.condition (value) ->
				return tr("This checkbox is required") if !value[entry.identifier]

	renderEdit: !->
		entry = @

		Form.label tr("Checkbox title")
		Form.input
			name: 'title'
			autofocus: true
			value: entry.dataO.get 'title'
			style:
				marginTop: '3px'
				marginBottom: 0

		Form.label tr("Checkbox description")
		Form.input
			name: 'description'
			value: entry.dataO.get 'description'
			style:
				marginTop: '3px'
				marginBottom: '16px'

		entry.renderRequired()


# Selector
class SelectorEntry extends Entry
	@entryType: 'selector'
	@displayName: tr("Selector")
	@description: tr("Select an option from a list")

	renderType: !->
		entry = @
		Form.selectInput
			name: entry.identifier
			title: "Things"
			options:
				0: ["text", "Text field"]
				1: ["date", "Date picker"]
				2: ["number", "Numeric value"]
				3: ["url", "Web URL"]
			default: 0

		# TODO

		if entry.dataO.get 'required' # require not selecting default?
			Form.condition (value) ->
				return tr("This checkbox is required") if !value[entry.identifier]

	renderEdit: !->
		entry = @

		# TODO

		entry.renderRequired()


# List of all entries
entries = [TextlineEntry, TextareaEntry, CheckboxEntry, SelectorEntry, InstructionEntry, SeparatorEntry]

makeType = (type, form, dataO) ->
	if !dataO?
		dataO = Obs.create
			type: type
	if type is 'textline'
		new TextlineEntry form, dataO
	else if type is 'instruction'
		new InstructionEntry form, dataO
	else if type is 'checkbox'
		new CheckboxEntry form, dataO
	else if type is 'separator'
		new SeparatorEntry form, dataO
	else if type is 'textarea'
		new TextareaEntry form, dataO
	else if type is 'selector'
		new SelectorEntry form, dataO