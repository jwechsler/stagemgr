class HashWithIndifferentAccess < Hash
  def to_yaml(opts = {})
    self.to_hash.to_yaml(opts)
  end
end
