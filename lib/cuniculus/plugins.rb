# frozen_string_literal: true

module Cuniculus
  # Base plugin load and registration module.
  module Plugins

    # Store for registered plugins
    @plugins = {}

    # Method that loads a plugin file. It should not be called directly; instead
    # use {Cuniculus.plugin} method to add and configure a plugin.
    #
    # @param name [Symbol] name of plugin, also matching its file name.
    #
    # @return [Module]
    def self.load_plugin(name)
      h = @plugins
      unless plugin = h[name]
        require "cuniculus/plugins/#{name}"
        raise Cuniculus::Error, "Plugin was not registered with 'register_plugin'" unless plugin = h[name]
      end
      plugin
    end

    # Include plugin module into a Hash so it can be referenced by its name.
    # This method should be called by the plugin itself, so that when it is required
    # (by {Cuniculus::Plugins.load_plugin}), it can be found.
    #
    # @param name [Symbol] Name of the plugin, matching its file name.
    # @param mod [Module] The plugin module.
    #
    # @example Register a plugin named `my_plugin`
    #   # file: my_plugin.rb
    #   module Cuniculus
    #     module Plugins
    #       module MyPlugin
    #       end
    #       register_plugin(:my_plugin, MyPlugin)
    #     end
    #   end
    def self.register_plugin(name, mod)
      @plugins[name] = mod
    end
  end
end

