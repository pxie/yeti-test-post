require 'sinatra'
require 'json'
require 'mongo'
require 'digest/md5'

get '/' do
  'hello from sinatra'
end

get '/crash' do
  Process.kill("KILL", Process.pid)
end

get '/upload' do
  '<html><form method="post" enctype="multipart/form-data"><input type="file" ' +
      'name="file"/><input type="submit"/></form></html>'
end

post '/upload' do
  data = params[:file][:tempfile].read
  md5 = Digest::MD5.hexdigest(data)
  if params[:md5] != md5
    raise RuntimeError, "MD5 hash is different"
  end

  # put data to mongo gridfs
  db = get_mongo_db
  grid = Mongo::Grid.new(db)
  params[:file][:tempfile].rewind
  id = grid.put(params[:file][:tempfile], :filename => params[:file][:filename], :safe => true)

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
