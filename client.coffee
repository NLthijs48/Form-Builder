tr = I18n.tr

exports.render = ->
	Comments.disable()

	if (formId = Page.state.get(0))?
		renderForm formId
	else if App.memberIsAdmin() and false # TODO remove
		renderAdminView()
	else
		renderForm()

# Render form
renderForm = (formId) !->
	Dom.style
		height: '100%'
		backgroundColor: '#EEE'

	# TODO: Use formId
	new FormBuild().render()

# Form object
class FormBuild
	constructor: (formO) ->
		@formO = formO
		@editingO = Obs.create false
		@entries = {}

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
						form.editingO.set false
			else
				Page.setActions
					icon: 'edit'
					label: "Edit form"
					action: !->
						form.editingO.set true

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
			type = entryO.get 'type'
			if type is 'textline'
				new TextlineEntry(form, entryO).render()
			else if type is 'instruction'
				new InstructionEntry(form, entryO).render()
			else
				log '[renderForm] Unknown form type:', type, 'entry:', entryO.key()
		, (entryO) ->
			entryO.get 'order'


	# Add a new part
	addPart: !->
		Modal.show tr("Add a part"), !->
			for entry in entries
				Ui.item
					content: entry.displayName
					sub: entry.description
					onTap: !->
						log 'tapped:', entry
						# TODO add part

						Modal.remove()
		, (result) !->
			log 'result:', result
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
		@dataO = dataO
		@containerE = undefined # Container dom element
		@margin = 4
		entry = @
		form.entries[dataO.key()] = entry

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
					# Remove button
					Icon.render
						data: 'trash'
						color: '#BA1A6E'
						size: 20
						style:
							padding: '10px'
							marginRight: '-10px'
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
		entry.containerE.transition (element) ->
			initial:
				zIndex: 1
			Translate: [0,(if direction is 'up' then -1 else 1)*(element.height()+entry.margin)]
			time: time
			onDone: !->
				Server.sync 'swapEntries', entry.dataO.key(), swapWith.dataO.key(), !->
					swapWith.dataO.set 'order', entry.dataO.peek('order')
					entry.dataO.set 'order', currentOrder
		swapWith.containerE.transition (element) ->
			Translate: [0,(if direction is 'up' then 1 else -1)*(element.height()+swapWith.margin)]
			time: time

	# Render a label
	renderLabel: (text) !->
		return if !text
		Form.label !->
			Dom.text text
			Dom.style marginBottom: '-12px'


# Text line entry
class TextlineEntry extends Entry
	@entryType: 'textline'
	@displayName: tr("Text line")
	@description: tr("A single line of text")

	renderType: !->
		entry = @

		identifier = entry.dataO.key()
		entry.renderLabel entry.dataO.get('name')
		Form.input
			name: identifier
		if entry.dataO.get 'required'
			Form.condition (value) ->
				return tr("This field is required") if !value[identifier]
		Dom.style marginBottom: '-15px'


# Markdown entry
class InstructionEntry extends Entry
	@entryType: 'instruction'
	@displayName: tr("Instruction block")
	@description: tr("A markdown block with instructions or an explanation")

	renderType: !->
		entry = @

		Dom.markdown entry.dataO.get 'markdown'


# List of all entries
entries = [TextlineEntry, InstructionEntry]