class AddressComponent
  # include Mongoid::Document

  attr_reader :long_name, :short_name, :types

  def initialize address_hash
  	address_hash.symbolize_keys!
  	@types = address_hash[:types]
  	@long_name = address_hash[:long_name]
  	@short_name = address_hash[:short_name]
  end

end
