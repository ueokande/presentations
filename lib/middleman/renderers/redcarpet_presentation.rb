require 'json'
require 'middleman-core/renderers/redcarpet'
require 'active_support/core_ext/module/attribute_accessors'

module Middleman
  module Renderers
    class RedcarpetPresentationTemplate < RedcarpetTemplate
      ALIASES = {
        escape_html: :filter_html
      }.freeze

      def initialize(*args, &block)
        super

        @context = @options[:context] if @options.key?(:context)
      end

      def generate_renderer
        return options.delete(:renderer) if options.key?(:renderer)

        covert_options_to_aliases!

        # Pick a renderer
        renderer = MiddlemanRedcarpetPresentationHTML

        if options.delete(:smartypants)
          # Support SmartyPants
          renderer = Class.new(renderer) do
            include ::Redcarpet::Render::SmartyPants
          end
        end

        # Renderer Options
        possible_render_opts = [:filter_html, :no_images, :no_links, :no_styles, :safe_links_only, :with_toc_data, :hard_wrap, :xhtml, :prettify, :link_attributes]

        render_options = possible_render_opts.each_with_object({}) do |opt, sum|
          sum[opt] = options.delete(opt) if options.key?(opt)
        end

        renderer.new(render_options)
      end

      private

      def covert_options_to_aliases!
        ALIASES.each do |aka, actual|
          options[actual] = options.delete(aka) if options.key? aka
        end
      end
    end

    class MiddlemanRedcarpetPresentationHTML < MiddlemanRedcarpetHTML

      def preprocess(full_document)
        output = ""
        full_document.each_line do |line|
          output += /\A:\s*{.*}\Z/.match(line) ? page_meta(line) : line
        end
        output
      end

      def postprocess(full_document)
        doc = Nokogiri::HTML::DocumentFragment.parse(full_document)
        current_page = nil
        children = doc.children
        if children.first && children.first.name != 'hr'
          current_page = new_page_element(doc)
          doc.add_child(current_page)
        end
        children.each do |ele|
          if ele.name == 'hr'
            current_page = new_page_element(doc)
            doc.add_child(current_page)
            ele.remove
          elsif ele.name == 'p'
            if ele.children.first && ele.children.first.name  == 'x-page-meta'
              meta = ele.children.first
              meta.attributes.each{ |k,v| current_page[k] = v }
              meta.remove
              ele.remove if ele.children.length == 0
            else
              current_page.add_child(ele)
            end
          else
            current_page.add_child(ele)
          end
        end
        doc.to_html
      end

      def new_page_element(doc)
        Nokogiri::XML::Node.new("section", doc)
      end

      private

      def page_meta(line)
        attrs = JSON.parse(line.gsub(/\A:/, ''))
        doc = Nokogiri::XML("<x-page-meta></x-page-meta>")
        attrs.each{ |k,v| doc.root[k] = v }
        doc.root.to_html
      end

    end

    ::Tilt.register RedcarpetPresentationTemplate, 'markdown', 'mkd', 'md'
  end
end
