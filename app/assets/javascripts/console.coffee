$(document).on "ready", ->

  buffer = $("#buffer")
  command = $("#command")
  form = $("form")
  prompt = $("#prompt").html()
  history = []
  historyPosition = -1
  savedCommand = ""

  fn = {}

  fn.createCardToken = (key, name, number, expMonth, expYear, sc) ->
    Omise.setPublicKey(key)

    card =
      name: name,
      number: number,
      expiration_month: expMonth,
      expiration_year: expYear,
      security_code: sc

    node = $("<pre>requesting: ...</pre>")
    appendToBuffer(node)

    Omise.createToken "card", card, (statusCode, response) ->
      if response["object"] is "token"
        node.html("requesting: " + response["id"])
      else
        node.html("requesting: [#{response.code}] #{response.message}")

  appendToBuffer = (content) ->
    buffer.append(content)

  appendCommandToBuffer = ->
    history_position = -1
    history.unshift(command.val())
    appendToBuffer("<pre><span class='prompt'>#{prompt}</span> #{command.val()}</pre>")
    command.val("")

  placeCaretAtEnd = ->
    position = command.val().length
    element = command.get(0)
    if element.setSelectionRange is undefined
      command.val(element.value)
    else
      element.setSelectionRange(position, position)

  loadCommand = ->
    if historyPosition is -1
      loadSavedCommand()
    else
      loadCommandFromHistory()

    placeCaretAtEnd()

  loadCommandFromHistory = ->
    command.val(history[historyPosition])

  loadSavedCommand = ->
    command.val(savedCommand)

  saveCommand = ->
    if historyPosition is -1
      savedCommand = command.val()

  disableCommand = ->
    command.blur()
    command.prop("disabled", true)
    form.hide()

  enableCommand = ->
    form.show()
    command.prop("disabled", false)
    command.focus()

  setPromptStatus = (status) ->
    buffer.children().last().find(".prompt").addClass(status)

  command.focus()

  command.bind "keydown", "meta+k", ->
    buffer.html("")

  command.bind "keydown", "ctrl+c", ->
    appendCommandToBuffer()

  command.bind "keydown", "up", ->
    saveCommand()

    if historyPosition is (history.length - 1)
      historyPosition = -1
    else
      historyPosition = historyPosition + 1

    loadCommand()

    false

  command.bind "keydown", "down", ->
    saveCommand()

    if historyPosition is -1
      historyPosition = history.length - 1
    else
      historyPosition = historyPosition - 1

    loadCommand()

    false

  $(document).on "ajax:send", (xhr) ->
    appendCommandToBuffer()
    disableCommand()

  $(document).on "ajax:success", (event, data, status, xhr) ->
    setPromptStatus("success")
    if data.slice(0,3) is "#!/"
      argv = data.slice(3,-1).split("|")
      name = argv.shift()
      fn[name].apply(undefined, argv)
    else
      appendToBuffer("<pre>#{data}</pre>")
    enableCommand()

  $(document).on "ajax:error", (event, xhr, status, error) ->
    setPromptStatus("error")
    if xhr.responseText
      message = xhr.responseText
    else
      message = "fatal error"
    appendToBuffer("<pre>#{message}</pre>")
    enableCommand()
