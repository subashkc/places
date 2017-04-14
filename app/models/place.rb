class Place
  include ActiveModel::Model

  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize place_hash
  	place_hash.deep_symbolize_keys!
  	@id = place_hash[:_id].to_s
  	@location = Point.new(place_hash[:geometry][:geolocation])
  	@formatted_address = place_hash[:formatted_address]
  	@address_components = place_hash[:address_components].map{ |address_component| AddressComponent.new(address_component) } unless place_hash[:address_components].nil?
  end

  def destroy
  	self.class.collection.find(:_id => BSON::ObjectId.from_string(@id)).delete_one
  end

  def near max_meters=0
  	return self.class.to_places(self.class.near(self.location, max_meters)) if max_meters > 0
  	self.class.to_places(self.class.near(self.location))
  end

  def photos offset=0, limit=0
  	photos = Photo.find_photos_for_place @id
  	photos = photos.skip(offset) if offset > 0
  	photos = photos.limit(limit) if limit > 0
  	photos.to_a.map {|photo| Photo.find photo[:_id]}
  end

  def persisted?
	!@id.nil?
  end

  class << self

  	def mongo_client
  		Mongoid::Clients.default
  	end

  	def collection
  		mongo_client[:places]
  	end

  	def load_all places_file
  		places_data = File.read(places_file)
  		places_json = JSON.parse(places_data)
  		collection.insert_many(places_json)
  	end

  	def find_by_short_name short_name
  		collection.find({ "address_components.short_name" => short_name})
  	end

  	def to_places places_hash
  		places_hash.map{ |place_hash| self.new(place_hash) }
  	end

  	def find place_id
  		place = collection.find(:_id => BSON::ObjectId.from_string(place_id)) rescue nil
  		self.new(place.to_a[0]) if place && place.count > 0
  	end

  	def all offset=0,limit=0
  		places = collection.find.skip(offset)
  		places = places.limit(limit) if limit>0
  		places.map{ |place| self.new(place) }
  	end

  	def get_address_components sort={}, offset=0, limit=0 # would like to write this function in a less messy way
  		return collection.find.aggregate([{:$unwind => "$address_components"}, {:$sort => sort}, {:$skip => offset}, {:$limit => limit}, {:$project => {:address_components=>1, :formatted_address=>1, "geometry.geolocation" => 1}}]) unless sort.empty?
  		collection.find.aggregate([{:$unwind => "$address_components"}, {:$project => {:address_components=>1, :formatted_address=>1, "geometry.geolocation" => 1}}])

  	end

  	def get_country_names
  		collection.find.aggregate([{:$project=>{:_id=>0,"address_components.long_name"=>1,"address_components.types"=>1}}, {:$unwind=>"$address_components"}, {:$match=>{"address_components.types"=>'country'}}, {:$group=>{:_id=>"$address_components.long_name"}}]).to_a.map{|place| place[:_id]}
  	end

  	def find_ids_by_country_code country_code
  		collection.find.aggregate([{:$unwind=>"$address_components"}, {:$match=>{"address_components.types"=>"country","address_components.short_name"=>country_code}}, {:$project=>{:_id=>1}}]).to_a.map{|place_id| place_id[:_id].to_s}  		
  	end

  	def create_indexes
  		collection.indexes.create_one({"geometry.geolocation" => "2dsphere"})
  	end

  	def remove_indexes
  		collection.indexes.drop_one("geometry.geolocation_2dsphere")
  	end

  	def near point, max_meters=-1
  		return collection.find({"geometry.geolocation" => {:$near => {:$geometry => point.to_hash, :$maxDistance => max_meters}}}) if max_meters > 0
  		collection.find({"geometry.geolocation" => {:$near => {:$geometry => point.to_hash}}}) 
  	end

  end

end
