# = require ../files
# = require ./dragdrop
# = require ./template
# = require ./dialog

uploadcare.whenReady ->
  {
    namespace,
    initialize,
    utils,
    uploads,
    files,
    jQuery: $
  } = uploadcare

  namespace 'uploadcare.widget', (ns) ->
    class ns.Widget
      constructor: (element) ->
        @element = $(element)
        @settings = utils.buildSettings @element.data()
        @uploader = new uploads.Uploader(@settings)

        @template = new ns.Template(@element)
        $(@template).on(
          'uploadcare.widget.template.cancel uploadcare.widget.template.remove',
          @__cancel
        )

        @element.on('change', @__changed)

        @__setupWidget()
        @template.reset()
        @available = true

        if @element.val()
          @element.trigger('change') # get info

      setValue: (value, @ignoreChange = true, @ignoreSetValueFailure = false) ->
        # I really, really dislike arguments to this function

        @element.val(value).trigger('change')

      __changed: (e) =>
        if @ignoreChange
          @ignoreChange = false
          return

        id = utils.uuidRegex.exec @element.val()

        if id
          info = uploads.fileInfo(id[0], @settings)
          @__setLoaded(info)
        else
          @__reset()

      __setLoaded: (infos...) ->
        $.when(infos...)
          .fail =>
            @__fail if @ignoreSetValueFailure
            @ignoreSetValueFailure = false

          .done (infos...) =>
            if @settings.imagesOnly && !uploads.isImage(infos...)
              return @__fail('image')
            @template.setFileInfo(infos...)
            @setValue((info.fileId for info in infos).join(','))
            @template.loaded()
            @ignoreSetValueFailure = false

      __fail: (type) =>
        @__cancel()
        @template.error(type)
        @available = true

      __reset: =>
        @__resetUpload()
        @__setupFileButton()
        @available = true
        @template.reset()
        $(this).trigger('uploadcare.widget.cancel')

      __cancel: =>
        @__reset()
        @setValue('')

      __setupWidget: ->
        # Initialize the file browse button
        @fileButton = @template.addButton('file')
        @__setupFileButton()

        # Create the dialog and its button
        if @settings.tabs.length > 0
          dialogButton = @template.addButton('dialog')
          dialogButton.on 'click', => @openDialog()

        # Enable drag and drop
        ns.dragdrop.receiveDrop(@upload, @template.dropArea)
        @template.dropArea.on 'uploadcare.dragstatechange', (e, active) =>
          unless active && @dialog()?
            @template.dropArea.toggleClass('uploadcare-dragging', active)

      __setupFileButton: ->
        utils.fileInput @fileButton, @settings.multiple, (e) =>
          @upload('event', e)

      upload: (args...) =>
        # Allow two types of calls:
        #
        #     widget.upload(ns.files.foo(args...))
        #     widget.upload('foo', args...)
        @__resetUpload()

        @template.started()
        @available = false

        currentUpload = @uploader.upload(args...)
        @template.listen(currentUpload)

        currentUpload
          .fail(@__fail)
          .done (infos) => @__setLoaded(infos...)

      __resetUpload: ->
        @uploader.reset()

      currentDialog = null

      dialog: -> currentDialog

      openDialog: ->
        @closeDialog()
        currentDialog = ns.showDialog(@settings)
          .done(@upload)
          .always( -> currentDialog = null)


      closeDialog: ->
        currentDialog?.close()

    initialize
      name: 'widget'
      class: ns.Widget
      elements: '@uploadcare-uploader'
