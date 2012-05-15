require 'sinatra'
require 'json'
require 'mongo'
require 'uri'
require 'base64'
require 'digest/md5'
require 'stringio'

get '/' do
  'hello from sinatra'
end

get '/crash' do
  Process.kill("KILL", Process.pid)
end

post '/service/mongo/:key' do
  # get data
  data = Base64.decode64(request.env["rack.input"].read)
  input_md5 = Digest::MD5.hexdigest(data)
  puts input_md5
  if params[:md5] != input_md5
    raise RuntimeError, "MD5 hash is different"
  end

  # put data to mongo gridfs
  db = get_mongo_db
  grid = Mongo::Grid.new(db)
  io = StringIO.new
  io.write(data)
  io.rewind
  id = grid.put(io, :filename => params[:key], :safe => true)

  coll = db['fs.files']
  coll.find.to_a.to_json
end

get '/list' do
  coll = get_mongo_db['fs.files']
  coll.find.to_a.to_json
end

not_found do
  'This is nowhere to be found.'
end

def get_mongo_db
  conn = Mongo::Connection.new('127.0.0.1', 4567)
  db = conn['testdb']
end
