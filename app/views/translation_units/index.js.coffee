$(window).ready ->
  translationUnitsSearchForm = $('#translation-units-search-form')
  table = $('#translation_units')

  sr = new TranslationUnitsSearch(table, table.data('url'))

  makeURL = -> "#{table.data('url')}?#{translationUnitsSearchForm.serialize()}"
  scroll = table.infiniteScroll makeURL,
    windowScroll: true
    renderer: (translation_units) =>
      for translation_unit in translation_units
        do (translation_unit) -> sr.addTranslationUnit(translation_unit)
    dataSourceOptions: {type: 'GET'}

  translationUnitsSearchForm.submit ->
    scroll.reset()
    sr.refresh(translationUnitsSearchForm.serialize())
    return false

