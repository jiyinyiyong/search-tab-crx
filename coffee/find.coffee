
define (require, exports) ->
  Ractive = require "Ractive"
  cirru = require "cirru"
  c2m = require "c2m"

  listTmplText = require "text!cirru_list"
  cirru.parse.compact = yes
  listTmpl = c2m.render cirru.parse listTmplText
  # helpers

  isKeyword = (char) -> char.match(/[\w\d\s\u4E00-\u9FA5]/)?

  fuzzy = (text) ->
    query = text.split('').filter(isKeyword).join('.*')
    new RegExp query, 'i'

  q = (query) -> document.querySelector query

  # ractive part

  page_list = new Ractive
    el: q('#menu')
    template: listTmpl
    data:
      currentAt: 0
      list: []
      highlightSelected: (selected) ->
        if selected
          "selected"
        else
          ""
      highlightCurrentAt: (currentAt, num) ->
        if currentAt is num
          "currentAt"
        else
          ""

  # cache

  initialTab = undefined

  # setup close event

  window.onbeforeunload = ->
    chrome.extension.sendMessage word: 'close', (res) ->
      console.log 'after close', res

  # main function

  input = q('#key')
  menu = q('#menu')

  suggest = (text) ->
    page_list.data.currentAt = 0
    list = page_list.data.list = []

    show_list = ->
      choice = []
      list.map (tab) ->
        if tab.title is 'Search Tabs' then console.log 'hide', tab
        else if tab.active
          initialTab = tab unless initialTab?
          choice.unshift tab
          chrome.extension.sendMessage word: 'log', data: tab
        else choice.push tab
      page_list.update "list"

    addOne = (tab) ->
      if tab.url.match(/^http/)?
        urlList = list.map (tab) -> tab.url
        list.push tab unless tab.url in urlList

    chrome.tabs.query {}, (tabs) ->
      tabs.filter((tab) -> tab.title.indexOf(text) >= 0).map(addOne)
      tabs.filter((tab) -> tab.url.indexOf(text) >= 0).map(addOne)
      tabs.filter((tab) -> tab.title.match(fuzzy text)?).map(addOne)
      show_list()

  input.addEventListener 'input', -> 
    suggest input.value

  document.body.onkeydown = (event) ->
    if event.keyCode is 13
      window.close()

    else if event.keyCode is 40 # down arrow
      currentAt = page_list.data.currentAt
      length = page_list.data.list.length
      if (currentAt + 1) < length
        page_list.set "currentAt", (currentAt + 1)
      context = page_list.data.list[page_list.data.currentAt]
      gotoTab context.id

    else if event.keyCode is 38 # up arrow
      currentAt = page_list.data.currentAt
      if currentAt > 0
        page_list.set "currentAt", (currentAt - 1)
      context = page_list.data.list[page_list.data.currentAt]
      gotoTab context.id

    else if event.keyCode is 27 # esc key
      chrome.extension.sendMessage word: 'log', data: initialTab
      if initialTab?
        gotoTab initialTab.id
        window.close()

  gotoTab = (tabid) ->
    console.log "going to", tabid
    chrome.tabs.update tabid, selected: yes

  # handle events

  page_list.on "select", (event) ->
    gotoTab event.context.id
    window.close()

  # init main function

  input.focus()
  suggest ''