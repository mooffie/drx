# Adds Graphviz diagraming capability to ObjInfo

module Drx

  class ObjInfo

    # Notes:
    # - Windows' CMD.EXE too supports "2>&1"
    # - We're generating GIF, not PNG, because that's a format Tk
    #   supports out of the box.
    GRAPHVIZ_COMMAND = 'dot "%s" -Tgif -o "%s" -Tcmapx -o "%s" 2>&1'

    @@sizes = {
      '100%' => "
        node[fontsize=10]
      ",
      '90%' => "
        node[fontsize=10]
        ranksep=0.4
        edge[arrowsize=0.8]
      ",
      '80%' => "
        node[fontsize=10]
        ranksep=0.3
        nodesep=0.2
        node[height=0.4]
        edge[arrowsize=0.6]
      ",
      '60%' => "
        node[fontsize=8]
        ranksep=0.18
        nodesep=0.2
        node[height=0]
        edge[arrowsize=0.5]
      "
    }

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
    def dot_style__default
      if singleton?
        # A singleton class
        "shape=oval,color=skyblue1,style=filled"
      elsif t_class?
        # A class
        "shape=oval,color=lightblue1,style=filled"
      elsif t_iclass? or t_module?
        # A module
        if repr['#']
          # Paint anonymous modules only lightly.
          "shape=box,style=filled,color=\"#D9FFF2\",fontcolor=gray60"
        else
          "shape=box,style=filled,color=aquamarine"
        end
      else
        # Else: a "normal" object, or an immediate.
        "shape=house,color=wheat1,style=filled"
      end
    end

    # Returns the DOT style for the node.
    def dot_style__crazy
      craze = "distortion=#{2*rand-1},skew=#{2*rand-1},orientation=#{360*rand}"
      crazy_oval = "shape=polygon,sides=25," + craze
      crazy_rect = "shape=polygon,sides=#{4+rand(3)}," + craze
      if singleton?
        # A singleton class
        "#{crazy_oval},color=palevioletred3,style=filled,fontcolor=white,peripheries=3"
      elsif t_class?
        # A class
        "#{crazy_oval},color=palevioletred1,style=filled"
      elsif t_iclass? or t_module?
        # A module
        "#{crazy_rect},color=peachpuff1,style=filled"
      else
        # Else: a "normal" object, or an immediate.
        "shape=house,color=pink,style=filled"
      end
    end

    # Returns the DOT label for the node.
    #
    # The representation may be quite big, so we trim it.
    def dot_label(max = 20)
      if class_like?
        # Let's be more lenient when trimming a class/module name.
        # We want to show The::Last::Component and possibly a singleton's
        # trailing 'S.
        max = 60 if max < 60
      end
      r = repr
      if r.length > max
        r[0, max] + ' ...'
      else
        r
      end
    end

    def dot_source(level = 0, opts = {}, &block) # :yield:
      out = ''
      # Note: since 'obj' may be a T_ICLASS, it doesn't repond to many methods,
      # including is_a?. So when we're querying things we're using Drx calls
      # instead.

      if level.zero?
        out << 'digraph {' "\n"
        out << @@sizes[opts[:size] || '100%']
        @@seen = {}
      end

      seen = @@seen[address]
      @@seen[address] = true

      if not seen
        dot_style = method('dot_style__' + (opts[:style] || 'default')).call
        out << "#{dot_id} [#{dot_style}, label=#{dot_quote dot_label}, URL=#{dot_quote dot_url}];" "\n"
      end

      yield self if block_given?

      return '' if seen

      if class_like?
        if spr = self.super and display_super?(spr)
          out << spr.dot_source(level+1, opts, &block)
          if [Module, ObjInfo.new(Module).klass.the_object].include? the_object
            # We don't want these relatively insignificant lines to clutter the display,
            # so we paint them lightly and tell DOT they aren't to affect the layout (width=0).
            out << "#{dot_id} -> #{spr.dot_id} [color=gray85, weight=0];" "\n"
          else
            out << "#{dot_id} -> #{spr.dot_id};" "\n"
          end
        end
      end

      kls = effective_klass
      if display_klass?(kls)
        out << kls.dot_source(level+1, opts, &block)
        out << "#{dot_id} -> #{kls.dot_id} [style=dotted];" "\n"
        out << "{ rank=same; #{dot_id}; #{kls.dot_id}; }" "\n"
      end

      if level.zero?
        out << '}' "\n"
      end

      return out
    end

    # Whether to display the klass.
    def display_klass?(kls)
      if t_iclass?
        # We're interested in an ICLASS's klass only if it isn't Module.
        #
        # Usualy this means that the ICLASS has a singleton (see "Singletons
        # of included modules" in display_super?()). We want to see this
        # singleton.
        return Module != kls.the_object
      else
        # Displaying a singletone's klass is confusing and usually unneeded.
        return !singleton?
      end
    end

    # Whether to display the super.
    def display_super?(spr)
      if (singleton? or t_iclass?) and Module == spr.the_object
         # Singletons of included modules, and modules included in them,
         # have their chain eventually reach Module. To prevent clutter,
         # we don't show this final link.
         #
         # "Singletons of included modules" often exist only for their
         # #included method. For example, DataMapper#Resource have
         # such a singleton.
        return false
      end
      return true
    end

    # Like klass(), but without surprises.
    #
    # Since the klass of an ICLASS is the module itself, we need to
    # invoke klass() twice.
    def effective_klass
      if t_iclass?
        klass.klass
      else
        klass
      end
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
    def generate_diagram(files, opts = {}, &block)
      source = self.dot_source(0, opts, &block)
      File.open(files['dot'], 'w') { |f| f.write(source) }
      command = GRAPHVIZ_COMMAND % [files['dot'], files['gif'], files['map']]
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
