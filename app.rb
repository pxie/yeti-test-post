require 'sinatra'
require 'json'
require 'mongo'
require 'digest/md5'
require 'aws/s3'

get '/' do
  "hello from sinatra - post v0.8<br>vblob"
end

get '/env' do
  ENV['VMC_SERVICES']
end

get '/upload' do
  '<html><form method="post" enctype="multipart/form-data"><input type="file" ' +
      'name="file"/><input type="submit"/></form></html>'
end

not_found do
  'This is nowhere to be found.'
end

def list_objs
  bucket = get_bucket

  data = []
  bucket.objects.each do |obj|
    item = {}
    item['filename'] = obj.key
    about            = obj.about
    item['md5']      = about['etag']
    item['length']   = about['content-length']
    data << item
  end
  data.to_json
end

get '/list' do
  load_vblob
  list_objs
end

post '/upload' do
  data = params[:file][:tempfile].read
  md5 = Digest::MD5.hexdigest(data)
  if params[:md5] != md5
    raise RuntimeError, "MD5 hash is different"
  end

  # put data to buckets
  load_vblob
  params[:file][:tempfile].rewind
  AWS::S3::S3Object.store(params[:file][:filename],
                          params[:file][:tempfile],
                          VBLOB_BUCKET_NAME)
  list_objs
end

delete '/files/:key' do
  load_vblob
  bucket = get_bucket
  begin
    bucket.delete(params[:key])
  rescue
    puts "fail to delete #{params[:key]}"
  end
  list_objs
end

VBLOB_BUCKET_NAME = 'assets-storage'

def get_bucket
  begin
    bucket = AWS::S3::Bucket.find(VBLOB_BUCKET_NAME)
  rescue AWS::S3::NoSuchBucket
    AWS::S3::Bucket.create(VBLOB_BUCKET_NAME)
    bucket = AWS::S3::Bucket.find(VBLOB_BUCKET_NAME)
  end
  bucket
end

def load_vblob
  vblob_service = load_service('vblob')
  AWS::S3::Base.establish_connection!(
      :access_key_id      => vblob_service['username'],
      :secret_access_key  => vblob_service['password'],
      :port               => vblob_service['port'],
      :server             => vblob_service['host']
  ) unless vblob_service == nil
end

def load_service(service_name)
  services = JSON.parse(ENV['VMC_SERVICES'])
  service = services.find {|service| service["vendor"].downcase == service_name}
  service = service["options"] if service
end