require 'drx_ext' # Load the C extension

# Contains a simple utility function, Drx::examine.

module Drx

  def self.obj_repr(obj)
    is_singleton = Drx.is_class_like(obj) && (Drx.get_flags(obj) & Drx::FL_SINGLETON).nonzero?
    is_iclass    = Drx.get_type(obj) == Drx::T_ICLASS
    if is_iclass
      return "'ICLS { include " + obj_repr(Drx.get_klass(obj)) + " }"
    else
      return obj.inspect + (is_singleton ? " 'S" : "")
    end
  end

  def self.examine(obj, level = 0, title = '', &block) # :yield:
    # Note: since 'obj' may be a T_ICLASS, it doesn't repond to may methods,
    # including is_a?. So when we're querying things we're using Drx calls
    # instead.

    $seen = {} if level.zero?
    line = ('  ' * level) + title + ' ' + obj_repr(obj)

    address = Drx.get_address(obj)
    seen = $seen[address]
    $seen[address] = true
    
    if seen
      line += " [seen]" #  #{address.to_s}"
    end

    if block_given?
      yield line, obj
    else
      puts line
    end
    
    return if seen

    if Drx.is_class_like(obj)
      # Kernel has a NULL super.
      # Modules too have NULL super, unless when 'include'ing.
      if Drx.get_super(obj) # Warning: we can't do 'if !Drx.get_super(obj).#nil?' because
                            # T_ICLASS doesn't "have" #nil.
        Drx.examine(Drx.get_super(obj), level+1, '[super]', &block)
      end
    end

    # Dipslaying a T_ICLASS's klass isn't very useful, because the data
    # is already mirrored in the m_tbl and iv_tvl of the T_ICLASS itself.
    if Drx.get_type(obj) != Drx::T_ICLASS
      Drx.examine(Drx.get_klass(obj), level+1, '[klass]', &block)
    end
  end

  def self.has_iv_tbl(obj)
    Drx.get_type(obj) == T_OBJECT or Drx.is_class_like(obj)
  end

  # Returns true if this object is either a class or a module.
  # When true, you know it has 'm_tbl' and 'super'.
  def self.is_class_like(obj)
    [Drx::T_CLASS, Drx::T_ICLASS, Drx::T_MODULE].include? Drx.get_type(obj)
  end

end
