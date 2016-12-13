{CompositeDisposable} = require 'atom'

path = require 'path'
helpers = require 'atom-linter'

module.exports = LinterBeancount =
  config:
    a:
      title: 'linter-beancount'
      type: 'object'
      description: 'Settings for linter-beancount.'
      properties:
        enable:
          title: 'Enable linter.'
          type: 'boolean'
          default: true
          description: 'Restart required for changes to take effect.'
        executable:
          title: 'Path'
          type: 'string'
          default: 'bean-check'
          description: 'Path to the `bean-check` executable.'

  subscriptions: null

  activate: (state) ->
    require('atom-package-deps').install('linter-beancount')
      .then ->
          console.log("Installed linter-beancount dependencies.")
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor', 'linter-beancount:run': => @run()

  deactivate: ->
    @subscriptions.dispose()

  serialize: ->

  isBeancountScope: (editor) ->
    if editor?
      return editor.getGrammar().scopeName is 'source.beancount'
    return false

  run: ->
    editor = atom.workspace.getActiveTextEditor()

    if editor.isModified()
      atom.notifications.addInfo('There are unsaved changes.')
      return

    if not @isBeancountScope editor
      atom.notifications.addInfo('Not a beancount file.')
      return

    if not atom.config.get 'linter-beancount.a.enable'
      atom.notifications.addInfo('Linter is disabled.')
      return

    atom.notifications.addInfo('Checking ...')
    path = editor.getPath()
    return @checkFile path
      .then (output) =>
        results = @parseOutput(output)
        if results.length == 0
            atom.notifications.addInfo('No errors.')
        else
          message = 'There are some errors!'
          for result in results
            message += '\n\nLine '
            message += result.range[0][0] + 1
            message += ': '
            message += result.text
          atom.notifications.addWarning(message)

  provideLinter: ->
    provider =
      scope: 'file'
      lintOnFly: false
      grammarScopes: ['source.beancount']
      lint: (textEditor) =>
        path = textEditor.getPath()
        return @checkFile path
          .then @parseOutput

  checkFile: (file) ->
    command = atom.config.get 'linter-beancount.a.executable'
    options = {
      stream: 'stderr',
      throwOnStderr: false,
      allowEmptyStderr: true,
      ignoreExitCode: true
    }
    return helpers.exec(command, [file], options)

  parseOutput: (output) ->
    result = []
    regex = /^(.+?):(\d+):\s+(.+)$/
    for l in output.split(/\r?\n/)
      l = l.replace(/^\s+|\s+$/g, '')
      match = regex.exec(l)
      if match
        path = match[1]
        line = parseInt(match[2], 10) - 1
        message = match[3]
        result.push(
          type: 'Warning',
          text: message,
          filePath: path,
          range: [[line, 0], [line, l.length]]
        )
    return result
