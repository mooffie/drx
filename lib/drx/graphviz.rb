# Adds Graphviz diagraming capability to ObjInfo

module Drx

  class ObjInfo

    # Create an ID for the DOT node representing this object.
    def dot_id
       ('o' + address.to_s).sub('-', '_')
    end

    # Creates a pseudo URL for the HTML imagemap.
    def dot_url
      "http://server/obj/#{dot_id}"
    end

    # Quotes a string to be used in DOT source.
    def dot_quote(s)
      # @todo: find the documentation for tr()?
      '"' + s.gsub('\\') { '\\\\' }.gsub('"', '\\"').gsub("\n", '\\n') + '"'
    end

    # Returns the DOT style for the node.
    def dot_style
      if singleton?
        # A singleton class
        "shape=egg,color=lightblue1,style=filled"
      elsif t_class?
        # A class
        "shape=oval,color=lightblue1,style=filled"
      elsif t_iclass? or t_module?
        # A module
        "shape=box,color=aquamarine,style=filled"
      else
        # Else: a "normal" object, or an immediate.
        "shape=house,color=wheat1,style=filled"
      end
    end

    # Returns the DOT label for the node.
    def dot_label(max = 20)
      if class_like?
        repr
      else
        # The representation may be quite big, so we trim it.
        r = repr
        if r.length > max
          r[0, max] + ' ...'
        else
          r
        end
      end
    end

    def dot_source(level = 0, &block) # :yield:
      out = ''
      # Note: since 'obj' may be a T_ICLASS, it doesn't repond to many methods,
      # including is_a?. So when we're querying things we're using Drx calls
      # instead.

      if level.zero?
        out << 'digraph {' "\n"
        out << '/*size="8,8";*/' "\n"
        out << 'node [fontsize=10];' "\n"
        @@seen = {}
      end

      seen = @@seen[address]
      @@seen[address] = true

      if not seen
        out << "#{dot_id} [#{dot_style}, label=#{dot_quote dot_label}, URL=#{dot_quote dot_url}];" "\n"
      end

      yield self if block_given?

      return '' if seen

      if class_like?
        if spr = self.super
          out << spr.dot_source(level+1, &block)
          if [Module, ObjInfo.new(Module).klass.the_object].include? the_object
            # We don't want these relatively insignificant lines to clutter the display,
            # so we paint them lightly and tell DOT they aren't to affect the layout (width=0).
            out << "#{dot_id} -> #{spr.dot_id} [color=gray85, weight=0];" "\n"
          else
            out << "#{dot_id} -> #{spr.dot_id};" "\n"
          end
        end
      end

      # Dipslaying a T_ICLASS's klass isn't very useful, because the data
      # is already mirrored in the m_tbl and iv_tvl of the T_ICLASS itself.
      if not t_iclass?
        # Displaying a singletone's class is confusing and usually unneeded.
        if not singleton?
          out << klass.dot_source(level+1, &block)
          out << "#{dot_id} -> #{klass.dot_id} [style=dotted];" "\n"
          out << "{ rank=same; #{dot_id}; #{klass.dot_id}; }" "\n"
        end
      end

      if level.zero?
        out << '}' "\n"
      end

      return out
    end

    # Generates a diagram of the inheritance hierarchy. It accepts a hash
    # pointing to pathnames to write the result to. A Tempfiles hash
    # can be used instead.
    #
    #   the_object = "some object"
    #   Tempfiles.new do |files|
    #     ObjInfo.new(the_object).generate_diagram
    #     system('xview ' + files['gif'])
    #   end
    #
    def generate_diagram(files, &block)
      source = self.dot_source(&block)
      File.open(files['dot'], 'w') { |f| f.write(source) }

      # Note: Windows's CMD.EXE too supports "2>&1" (However, this is not
      # supported on good old Windows 98).
      command = 'dot "%s" -Tgif -o "%s" -Tcmapx -o "%s" 2>&1' % [files['dot'], files['gif'], files['map']]

      message = Kernel.`(command)  # `
      if $? != 0
        error = <<-EOS % [command, message]
ERROR: Failed to run the 'dot' command. Make sure you have the GraphViz
package installed and that its bin folder appears in your PATH.

The command I tried to execute is this:

%s

And the response I got is this:

%s
        EOS
        raise error
      end
    end

  end
end
