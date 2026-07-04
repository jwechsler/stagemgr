class ActiveSupport::HashWithIndifferentAccess < Hash
  def to_yaml(opts = {})
    to_hash.to_yaml(opts)
  end
end
