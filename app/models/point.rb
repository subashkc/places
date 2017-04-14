class Point
  # include Mongoid::Document
  attr_accessor :latitude, :longitude
  
  def initialize pt_hash
  	pt_hash.symbolize_keys!
  	@latitude, @longitude = pt_hash[:lat], pt_hash[:lng] if pt_hash[:coordinates].nil?
  	@latitude, @longitude = pt_hash[:coordinates][1], pt_hash[:coordinates][0] unless pt_hash[:coordinates].nil?
  end

  def to_hash
  	{:type => 'Point', :coordinates => [@longitude, @latitude]}
  end

end
