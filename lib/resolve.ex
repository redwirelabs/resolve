defmodule Resolve do
  @moduledoc """
  Dependency injection and resolution at compile time or runtime
  """

  defmacro __using__(_) do
    quote do
      @doc false
      defdelegate resolve(module), to: Resolve
    end
  end

  @compile? !!Application.compile_env(:resolve, :compile, false)

  @mappings \
    Application.compile_env(:resolve, :mappings, [])
    |> Enum.into(%{})

  @doc """
  Flag a module as eligible for dependency injection / resolution.

  Defaults to `module` unless a new dependency is injected in its place.
  """
  @spec resolve(module :: module) :: module
  def resolve(module), do: resolve(module, @compile?)

  defp resolve(module, _compile? = true) do
    @mappings[module] || module
  end

  defp resolve(module, _compile? = false) do
    ensure_ets_is_running()

    case :ets.lookup(:resolve, module) do
      []                     -> @mappings[module] || module
      [{_, injected_module}] -> injected_module
    end
  end

  @doc """
  Inject a module in place of another one.
  """
  @spec inject(target_module :: module, injected_module :: module) :: any
  def inject(target_module, injected_module) when is_atom(injected_module) do
    ensure_ets_is_running()

    :ets.insert(:resolve, {target_module, injected_module})

    :ok
  end

  def inject(target_module, module_body) do
    unique_number = System.unique_integer([:positive])

    {:module, injected_module, _, _} =
      Module.create(:"Mock#{unique_number}", module_body, Macro.Env.location(__ENV__))

    inject(target_module, injected_module)
  end

  @doc """
  Revert this dependency to the original module.

  This function is idempotent and will not fail if Resolve already points to
  the original module.
  """
  @spec revert(module :: module) :: any
  def revert(module) do
    ensure_ets_is_running()

    :ets.delete(:resolve, module)

    :ok
  end

  @doc """
  Revert all dependencies to their original modules.

  This can be used when unit testing to ensure dependencies are cleared out
  between tests.
  """
  @spec revert_all() :: any
  def revert_all do
    ensure_ets_is_running()

    :ets.delete_all_objects(:resolve)

    :ok
  end

  defp ensure_ets_is_running do
    case :ets.whereis(:resolve) do
      :undefined -> :ets.new(:resolve, [:public, :named_table, read_concurrency: true])
      table_id   -> table_id
    end
  end
end
