class ActiveResource::Base
  def self.remote_new options={}
    new(get("new").merge(options))
  end
end