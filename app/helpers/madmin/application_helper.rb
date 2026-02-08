module Madmin
  module ApplicationHelper
    include Pagy::Frontend if defined?(Pagy::Frontend)

    # Navigation link helper for Madmin sidebar
    def madmin_nav_link(path, icon, label, nested: false)
      is_active = current_page?(path) || (path != "/madmin" && request.path.start_with?(path.to_s.split("?").first))

      base_classes = "flex items-center gap-3 px-3 py-2 text-sm rounded-lg transition-colors"
      active_classes = "bg-dark-800 text-white"
      inactive_classes = "text-dark-400 hover:text-dark-100 hover:bg-dark-800"
      nested_classes = nested ? "pl-10" : ""

      link_to path, class: "#{base_classes} #{is_active ? active_classes : inactive_classes} #{nested_classes}" do
        inline_svg("icons/#{icon}.svg", class: "w-5 h-5 flex-shrink-0") + content_tag(:span, label)
      end
    end

    # Collapsible navigation group for Madmin sidebar
    def madmin_nav_group(id, icon, label, &block)
      content = capture(&block)

      content_tag(:div, class: "space-y-1") do
        button = content_tag(:button,
          type: "button",
          data: { action: "click->sidebar#toggleGroup", group_id: id },
          class: "w-full flex items-center justify-between gap-3 px-3 py-2 text-sm text-dark-400 hover:text-dark-100 hover:bg-dark-800 rounded-lg transition-colors") do
          icon_and_label = content_tag(:div, class: "flex items-center gap-3") do
            inline_svg("icons/#{icon}.svg", class: "w-5 h-5 flex-shrink-0") + content_tag(:span, label)
          end
          chevron = inline_svg("icons/chevron-right.svg", class: "w-4 h-4 transition-transform duration-200 rotate-90", data: { chevron: true })
          icon_and_label + chevron
        end

        group_content = content_tag(:div, content, id: "nav-group-#{id}", class: "space-y-1")
        button + group_content
      end
    end

    class MarkdownRenderer < Redcarpet::Render::HTML
      include Rouge::Plugins::Redcarpet

      def block_code(code, language)
        language ||= "text"
        formatter = Rouge::Formatters::HTMLLegacy.new(css_class: "highlight")
        lexer = Rouge::Lexer.find_fancy(language, code) || Rouge::Lexers::PlainText.new
        formatter.format(lexer.lex(code))
      end
    end

    def markdown(text)
      return "" if text.blank?

      options = {
        filter_html: true,
        hard_wrap: true,
        link_attributes: { rel: "nofollow", target: "_blank" },
        fenced_code_blocks: true,
        prettify: true,
        tables: true,
        with_toc_data: true,
        no_intra_emphasis: true
      }

      extensions = {
        autolink: true,
        superscript: true,
        disable_indented_code_blocks: true,
        fenced_code_blocks: true,
        tables: true,
        strikethrough: true,
        highlight: true
      }

      renderer = MarkdownRenderer.new(options)
      markdown_parser = Redcarpet::Markdown.new(renderer, extensions)

      markdown_parser.render(text).html_safe
    end
  end
end
