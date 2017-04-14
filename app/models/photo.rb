class Photo
  # include Mongoid::Document

  attr_writer :contents
  attr_accessor :id, :location, :place

  def initialize photo_hash={}
  	unless photo_hash.empty?
	  	@id = photo_hash[:_id].to_s unless photo_hash[:_id].nil?
	  	@location = Point.new(photo_hash[:metadata][:location]) unless photo_hash[:metadata][:location].nil?
	  	@place = photo_hash[:metadata][:place]
  	end
  end

  def persisted?
  	!@id.nil?
  end

  def save
  	if persisted?
  		self.class.mongo_client.database.fs.files_collection.find(:_id=>BSON::ObjectId.from_string(@id)).update_one({:metadata => {:location => @location.to_hash, :place => @place}})
  	else
  		gps_obj = EXIFR::JPEG.new(@contents).gps
  		@contents.rewind
  		point = Point.new({lat: gps_obj.latitude, lng: gps_obj.longitude})
  		photo_desc = {}
  		photo_desc[:content_type] = 'image/jpeg'
		photo_desc[:metadata] = {:location => point.to_hash, :place => @place}
  		@location = point
  		image = Mongo::Grid::File.new(@contents.read, photo_desc)
  		@id = self.class.mongo_client.database.fs.insert_one(image)
  	end
  end

  def contents
  	self.class.mongo_client.database.fs.find_one(:_id => BSON::ObjectId.from_string(id)).data
  end

  def destroy
  	self.class.mongo_client.database.fs.find(:_id => BSON::ObjectId.from_string(@id)).delete_one
  end

  def find_nearest_place_id max_distance
  	place = Place.near(self.location, max_distance).limit(1).projection({:_id=>1}).to_a
  	return place.size == 1 ? place[0][:_id] : nil
  end

  def place=(place)
  	case 
  	when place.is_a?(Place)
  		@place = BSON::ObjectId.from_string(place.id)
  	when place.class == String
  		@place = BSON::ObjectId.from_string(place)
  	else 
  		@place = place
  	end
  end

  def place
  	Place.find @place
  end

  class << self

  	def mongo_client
  		Mongoid::Clients.default
  	end

  	def all offset=0, limit=0
  		result = mongo_client.database.fs.find
  		result = result.skip(offset) if offset > 0
  		result = result.limit(limit) if limit > 0
  		result.to_a.map {|photo| self.new(photo)}
  	end

  	def find id
  		self.new(mongo_client.database.fs.find(:_id => BSON::ObjectId.from_string(id)).first) rescue nil
  	end

  	def find_photos_for_place place_id
  		place_id = BSON::ObjectId.from_string(place_id)
  		mongo_client.database.fs.files_collection.find({"metadata.place" => place_id})
  	end

  end

end
