require 'tempfile'

# Holds a set of related temporary file names. When it goes out of scope, the files are deleted.
#
#   files = Tempfiles.new('foo')
#   puts files['gif']
#   puts files['xml']
#
class Tempfiles

  def initialize(basename)
    @refs = []
    @paths = Hash.new do |h, suffix|
      tf = Tempfile.new([basename, '.' + suffix])
      tf.close
      @refs << tf  # We must keep a ref to this object or its finalizer will delete the temp file.
      h[suffix] = tf.path
    end
  end

  def [](suffix)
    @paths[suffix]
  end

  # This method shouldn't be needed, as files are supposed to
  # get deleted when Tempfile instances are GC'ed. But it seems
  # they aren't always.
  def unlink
    @refs.each { |tf| tf.unlink }
  end

end
