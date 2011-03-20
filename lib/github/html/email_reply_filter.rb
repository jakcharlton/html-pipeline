module GitHub::HTML
  # HTML Filter that converts email reply text into an HTML DocumentFragment.
  # It must be used as the first filter in a pipeline.
  #
  # Context options:
  #   None
  #
  # This filter does not write any additional information to the context hash.
  class EmailReplyFilter < Filter
    include EscapeUtils

    def initialize(text, context={})
      raise TypeError, "text cannot be HTML" if text.is_a?(DocumentFragment)
      @text = text.to_s
      @context = context
      @doc = nil
    end

    # Convert Markdown to HTML using the best available implementation
    # and convert into a DocumentFragment.
    def call
      html = format_email_reply(@text)
      @doc = parse_html(html)
    end

    EMAIL_HIDDEN_HEADER    = %(<span class="email-hidden-toggle"><a href="#">Show quoted text</a></span><div class="email-hidden-reply">).freeze
    EMAIL_QUOTED_HEADER    = %(<div class="email-quoted-reply">).freeze
    EMAIL_SIGNATURE_HEADER = %(<div class="email-signature-reply">).freeze
    EMAIL_FRAGMENT_HEADER  = %(<div class="email-fragment">).freeze
    EMAIL_HEADER_END       = "</div>".freeze

    # Scans an email body to determine which bits are quoted and which should
    # be hidden. EmailReplyParser is used to split the comment into an Array
    # of quoted or unquoted Blocks. Now, we loop through them and attempt to
    # add <div> tags around them so we can hide the hidden blocks, and style
    # the quoted blocks differently. Since multiple blocks may be hidden, be
    # sure to keep the "email-hidden-reply" <div>s around "email-quoted-reply"
    # <div> tags. Call this on each comment of a visible thread in the order
    # that they are displayed. Note: all comments are processed so we can
    # maintain a Set of SHAs of paragraphs. Only plaintext comments skip the
    # markdown step.
    #
    # Returns the email comment HTML as a String
    def format_email_reply(text)
      found_hidden = nil
      paragraphs = EmailReplyParser.read(text.dup).fragments.map do |fragment|
        pieces = [escape_html(fragment.to_s.strip)]
        if fragment.quoted?
          if !fragment.hidden? && pieces[0] !~ /^\s*(>|&gt;)/
            header, quoted = pieces[0].split("\n", 2)
            pieces = ["<!-- #{header} -->\n#{quoted}"]
          end
          pieces.unshift EMAIL_QUOTED_HEADER
          pieces << EMAIL_HEADER_END
        elsif fragment.signature?
          pieces.unshift EMAIL_SIGNATURE_HEADER
          pieces << EMAIL_HEADER_END
        else
          pieces.unshift EMAIL_FRAGMENT_HEADER
          pieces << EMAIL_HEADER_END
        end
        if fragment.hidden? && !found_hidden
          found_hidden = true
          pieces.unshift EMAIL_HIDDEN_HEADER
        end
        pieces.join
      end
      paragraphs << EMAIL_HEADER_END if found_hidden
      paragraphs.join("\n")
    end
  end
end
