$ = jQuery

# The main REPL class. Controls the UI and acts as a parent namespace for all
# the other classes in the project.
class @JSREPL
  constructor: ->
    # The definition of the current language.
    @lang = null
    # The interpreter engine of the current language.
    @engine = null
    # The examples of the current language.
    @examples = null
    # The console instance
    @console = null
    # Set up the UI.
    @DefineTemplates()
    @SetupInputControls()
    @LoadLanguageDropdown()

  # Defines global jQuery templates used by the various functions interacting
  # with the UI.
  DefineTemplates: ->
    $.template 'optgroup', '''
                           {{each(cat, names_arr) data}}
                             <optgroup label="${cat}">
                               {{each names_arr}}
                                 <option value="${$value.value}">
                                   ${$value.display}
                                 </option>
                               {{/each}}
                             </optgroup>
                           {{/each}}
                           '''
    $.template 'option', '<option>${value}</option>'
  # Initializes the behaviour of the command prompt and the expand and eval
  # buttons.
  SetupInputControls: ->
    @console = $('#console').console
      greetings: "JSREPL 2011"
      label: ">>>"
      handler: (a...)=> @Evaluate(a...)
        
    # A custom event that sets the content of the command line.
    @console.bind 'setContent', (e, content) =>
      @console.setText(content)
      @console.click()

    # A custom event to clear the content of the command line.
    @console.bind 'clearContent', (e) =>
      @console.trigger 'setContent', ['']

  # Populates the languages dropdown from JSREPL::Languages and triggers the
  # loading of the default language.
  LoadLanguageDropdown: ->
    # Sort languages into categories.
    categories = {}
    for system_name, lang_def of JSREPL::Languages::
      if not categories[lang_def.category]?
        categories[lang_def.category] = []
      categories[lang_def.category].push
        display: lang_def.name
        value: system_name

    # Fill the dropdown.
    $languages = $('#languages')
    $languages.empty().append $.tmpl 'optgroup', data: categories

    # Link dropbox to language loading.
    $languages.change =>
      # TODO(amsad): Create a loading effect.
      $('body').toggleClass 'loading'
      @LoadLanguage $languages.val(), ->
        $('body').toggleClass 'loading'

    # Load the default language by manually triggering change.
    $languages.change()

  # Loads the specified language engine with its examples and calls the callback
  # once all loading is done.
  #   @arg lang_name: The name of the language to load, a member of
  #     JSREPL::Languages as defined in languages.js.
  #   @arg callback: The function to call after loading finishes.
  # TODO(amasad): Consider error handling when loading scripts and examples.
  LoadLanguage: (lang_name, callback) ->
    # Clean up previous engine.
    if @engine
      @engine.Destroy()
      delete @engine

    # Empty out the history, prompt and example selection.
    @console.reset()
    $('#examples').val ''

    # A counter to call the callback after the scripts and examples have
    # successfully loaded.
    signals_read = 0
    signalReady = ->
      if ++signals_read == 2 then callback()

    @lang = JSREPL::Languages::[lang_name]

    # Load scripts.
    loader = $LAB;
    for script in @lang.scripts
      loader = loader.script(script).wait()
    loader.wait =>
      # TODO(amasad): This callback doesn't run if the same language is loaded
      #               twice. See if this can be fixed. The loaded scripts
      #               themselves run fine though.
      # FOLLOWUP(max99x): It runs twice. However in IE 8 it doesn't work for lisp
      @engine = new JSREPL::Engines::[lang_name](
        ((a...) => @ReceiveInputRequest(a...)),
        ((a...) => @ReceiveOutput(a...)),
        ((a...) => @ReceiveResult(a...)),
        ((a...) => @ReceiveError(a...))
      )
      signalReady()

    # Load logo.
    $('#lang_logo').attr 'src', @lang.logo

    # Load examples.
    $.get @lang.example_file, (raw_examples) =>
      # Clear the existing examples.
      @examples = {}
      $examples = $('#examples')
      $(':not(:first)', $examples).remove()

      # Parse out the new examples.
      example_parts = raw_examples.split /\*{80}/
      title = null
      for part in example_parts
        part = part.replace /^\s+|\s*$/g, ''
        if not part then continue
        if title
          code = part
          @examples[title] = code
          title = null
        else
          title = part
          $examples.append $.tmpl 'option', value: title

      # Set up response to example selection.
      $examples.change =>
        code = @examples[$examples.val()]
        @console.trigger 'setContent', [code]

      signalReady()

  #   @arg result: The user-readable string form of the result of an evaluation.
  ReceiveResult: (result) ->
    if result
      @result(result)

  # Receives an error message resulting from a command evaluation.
  #   @arg error: A message describing the error.
  ReceiveError: (error) ->
    @result(error.message)

  # Receives any output from a language engine. Acts as a low-level output
  # stream or port.
  #   @arg output: The string to output. May contain control characters.
  ReceiveOutput: (output) ->
    @stdout(output)
    return undefined

  # Receives a request for a string input from a language engine. Passes back
  # the user's response asynchronously.
  #   @arg callback: The function called with the string containing the user's
  #     response. Currently called synchronously, but that is *NOT* guaranteed.
  ReceiveInputRequest: (callback) ->
    # TODO(max99x): Convert to something more elegant. Right now prompt() adds a
    #               new line to our command prompt for some reason, and has
    #               problems on IE.
    @console.stdin("Input: ", callback)
    return undefined

  # Evaluates a command in the current engine.
  #   @arg command: A string containing the code to execute.
  Evaluate: (command, @stdout, @result) ->
    $('#examples').val ''
    @engine.Eval command


# The languages and engines modules.
class JSREPL::Languages
class JSREPL::Engines

# Create and load the main REPL object.
$ -> new JSREPL
