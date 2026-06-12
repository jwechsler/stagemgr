class Object
  def nil_or
    self
  end
end

class NilClass
  def nil_or
    NilHolder.new
  end
end

class NilHolder
  def method_missing(*args)
    nil
  end
end
