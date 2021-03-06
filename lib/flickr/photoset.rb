class Flickr::Photosets::Photoset
  attr_accessor :id, :num_photos, :primary, :secret, :farm, :server, :title, :description, :owner

  def initialize(flickr, attributes)
    @flickr = flickr
    attributes.each do |k,v|
      send("#{k}=", v)
    end
  end

  def get_photos(options={})
    options = options.merge(:photoset_id=>id)
    rsp = @flickr.send_request('flickr.photosets.getPhotos', options)
    collect_photos(rsp)
  end

  def primary_photo_url
    "http://farm#{farm}.static.flickr.com/#{server}/#{primary}_#{secret}_s.jpg"
  end

  protected

  def collect_photos(rsp)
    photos = []
    return photos unless rsp
    if rsp.photoset.photo
      rsp.photoset.photo.each do |photo|
        attributes = create_attributes(photo)
        photos << Flickr::Photos::Photo.new(@flickr,attributes)
      end
    end
    return photos
  end

  def create_attributes(photo)
    {
      :id     => photo[:id],
      :secret => photo[:secret],
      :server => photo[:server],
      :farm   => photo[:farm],
      :title  => photo[:title],
      :url_l  => photo[:url_l],
      :owner  => self.owner
    }
  end
end
