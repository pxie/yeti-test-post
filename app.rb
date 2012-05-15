require 'sinatra'
require 'json'
require 'mongo'
require 'digest/md5'

get '/' do
  'hello from sinatra - post v0.6'
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
  coll = db['fs.files']
  grid = Mongo::Grid.new(db)
  # remove exsited file
  remove_file(coll, grid, params[:file][:filename])

  params[:file][:tempfile].rewind
  grid.put(params[:file][:tempfile], :filename => params[:file][:filename], :safe => true)

  coll.find.to_a.to_json
end

delete '/files/:key' do
  db = get_mongo_db
  coll = db['fs.files']
  grid = Mongo::Grid.new(db)
  remove_file(coll, grid, params[:key])
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

def remove_file(collection, grid, filename)
  collection.find('filename' => filename).each do |row|
    grid.delete(row['_id'])
  end
end
