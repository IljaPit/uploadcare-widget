{
  namespace,
  utils,
  ui: {progress},
  templates: {tpl},
  jQuery: $,
  crop: {CropWidget},
  locale: {t}
} = uploadcare

namespace 'uploadcare.widget.tabs', (ns) ->
  class ns.PreviewTab extends ns.BasePreviewTab

    PREFIX = '@uploadcare-dialog-preview-'

    constructor: ->
      super

      @__doCrop = @settings.__cropParsed.enabled

      @dialogApi.fileColl.onAdd.add @__setFile

    __setFile: (@file) =>
      @__setState 'unknown'

      stateKnown = utils.once (info) =>
        if info.isImage
          @__setState 'image'
        else
          @__setState 'regular'

      file = @file
      ifCur = (fn) =>
        => fn.apply(null, arguments) if file == @file

      @file.done ifCur (info) =>
        stateKnown info

      @file.fail ifCur (error) =>
        @__setState 'error', {error}

    # error
    # unknown
    # image
    # regular
    __setState: (state, data) ->
      render = utils.once (fileInfo) =>
        data = $.extend {file: fileInfo}, data
        @container.empty().append tpl("tab-preview-#{state}", data)
        @__afterRender state

      @file.progress (progressInfo) -> render progressInfo.incompleteFileInfo
      @file.done render
      @file.fail (error, fileIfo) -> render fileIfo

    __afterRender: (state) ->
      if state is 'unknown'
        if @__doCrop
          @__hideDoneButton()
      if state is 'image' and @__doCrop
        @__initCrop()

    __hideDoneButton: ->
      @container.find(PREFIX + 'done').hide()

    __initCrop: ->
      # crop widget can't get container size when container hidden
      # (dialog hidden) so we need timer here
      utils.defer =>
        img = @container.find(PREFIX + 'image')
        container = img.parent()
        doneButton = @container.find(PREFIX + 'done')
        widget = new CropWidget $.extend({}, @settings.__cropParsed, {
          container
          controls: false
        })
        doneButton.addClass('uploadcare-disabled-el')
        widget.onStateChange.add (state) =>
          if state == 'loaded'
            doneButton
              .removeClass('uploadcare-disabled-el')
              .click -> widget.forceDone()
        @file.done (info) =>
          widget.croppedImageModifiers(img.attr('src'), info.originalImageInfo,
                                       info.cdnUrlModifiers)
            .done (opts) =>
              @dialogApi.replaceFile @file, @file.then (info) =>
                info.cdnUrlModifiers = opts.modifiers
                info.cdnUrl = "#{@settings.cdnBase}/#{info.uuid}/#{opts.modifiers or ''}"
                info.crop = opts.crop
                info

        # REFACTOR: separate templates?
        img.remove()
        @container.find('.uploadcare-dialog-title').text t('dialog.tabs.preview.crop.title')
        @container.find('@uploadcare-dialog-preview-done').text t('dialog.tabs.preview.crop.done')
