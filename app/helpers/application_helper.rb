module ApplicationHelper
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
