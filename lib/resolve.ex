defmodule Resolve do
  @moduledoc """
  Dependency injection and resolution at compile time or runtime

  ## Usage

  Include resolve in the module that requires dependency injection with
  `use Resolve`. Any place in that module that might need a dependency injected
  can then use `resolve(<module>)` to allow another module to be injected. The
  module passed to `resolve/1` will be used if another module isn't injected.

  ```elixir
  defmodule MyInterface do
    use Resolve

    def some_command, do: resolve(__MODULE__).some_command
  end 
  ```

  ### Configuration

  Resolve can be configured in the project's `config.exs`.

  **Opts**
  - `compile` - (false) - Sets the mappings at compile time and doesn't start \
                          the process that allows them to be modified at runtime. \
                          This method is more secure and more performant. \
                          Compiling is intended for production and runtime is \
                          intended for unit tests.
  - `mappings` - `[]`   - A two element tuple of the modules to map from and to: \
                          `{from, to}`

  **Example**


  ```elixir
  config :resolve,
    compile: true,
    mappings: [
      {OriginalModule, InjectedModule},
    ]
  ```

  ### Runtime

  Dependencies can be injected at runtime with `inject/2`. This is intended for
  unit testing, but not necessarily limited to it. Runtime mappings will be
  less performant compared to compiled mappings, as each lookup goes through
  a read-optimized ETS table.

  ```elixir
  Resolve.inject(OriginalModule, InjectedModule)
  ```

  Modules can also be defined directly in a block, which can be helpful if they
  are only needed for certain tests.

  ```elixir
  Resolve.inject(Port, quote do
    def open(_name, _opts), do: self()

    def close(_port), do: :ok

    def command(_port, _data), do: :ok
  end)
  ```
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

  defp ensure_ets_is_running do
    case :ets.whereis(:resolve) do
      :undefined -> :ets.new(:resolve, [:public, :named_table, read_concurrency: true])
      table_id   -> table_id
    end
  end
end
