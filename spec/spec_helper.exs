ESpec.configure fn(config) ->
  config.before fn(tags) ->
    {:shared, tags: tags}
  end

  config.finally fn(_shared) ->
    :ok
  end
end
