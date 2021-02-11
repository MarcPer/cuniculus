# frozen_string_literal: true

module Cuniculus
  module Plugins

    # Store for registered plugins
    @plugins = {}

    def self.load_plugin(name)
      h = @plugins
      unless plugin = h[name]
        require "cuniculus/plugins/#{name}"
        raise Cuniculus::Error, "Plugin was not registered with 'register_plugin'" unless plugin = h[name]
      end
      plugin
    end

    def self.register_plugin(name, mod)
      @plugins[name] = mod
    end
  end
end

