#!/usr/bin/env ruby

require 'sinatra'
require 'redis'

configure do
  REDIS = Redis.new
  REDIS.setnx "postID", "0"
  
end

before '/' do
  

end

helpers do
  def next_post
    incr = 1
    value = REDIS.incrby "postID", incr
    value.to_s
  end
end


get '/' do
	erb :home
end

get '/faq' do
  erb :faq
end

get '/about' do
  erb :about
end

get '/rules' do
  erb :rules
end

get '/:Subject/' do
  @subject = params[:Subject]
  @past_posts = REDIS.LRANGE "#{@subject}post", 0, -1
  @numPosts = REDIS.LRANGE "#{@subject}postID", 0, -1

  erb :subjects
end

get '/images/:filename' do
  filename = params[:filename]
  data = REDIS.get "image:#{filename}"
  if data.nil?
    halt 404
  end
  content_type REDIS.get "content-type:#{filename}"
  data
end

post '/:Subject/' do
  @subject = params[:Subject]

  @postID = next_post
  
  @time = Time.new

  file_info = params[:file]
  @comment = params[:comment]
  
  #START HERE FOR REPLY
  if @comment.nil?
    @replyTo = params[:replyTo].to_i
    @replyComment = params[:replycomment]
    file_info = params[:replyfile]
    @nextComment = @replyTo +1
    @prevComment = @replyTo -1
    
    REDIS.RPUSH "#{@subject}#{@replyTo}NumReplies", 1
    count = 0
    @numReplies = 0
    while count < @replyTo do
      @numReplies += REDIS.LLEN "#{@subject}#{@prevComment-count}NumReplies" 
      count +=1
    end
    
    @past_posts = REDIS.LRANGE "#{@subject}post", ((@numReplies+@replyTo)*6), -1
    REDIS.LTRIM "#{@subject}post", 0, ((@numReplies+@replyTo)*6)-1
    
    length = REDIS.LLEN "#{@subject}postID"
    REDIS.RPUSH "#{@subject}postID", length+1

    REDIS.RPUSH "#{@subject}post","<pre>    POST# #{length+1} (Response to POST# #{@replyTo})</pre>"
    REDIS.RPUSH "#{@subject}post","<pre>    Time: #{@time}</pre>"
    REDIS.RPUSH "#{@subject}post","<pre>    Comment: #{@replyComment}</pre>"
    
    if not file_info.nil?
      @filename = file_info[:filename]
      REDIS.set "imageName", "#{@filename}"
      REDIS.set "image:#{@filename}", file_info[:tempfile].read
      REDIS.set "content-type:#{@filename}", file_info[:type]

	    REDIS.RPUSH "#{@subject}post","<pre>    Image: <a href=/images/#{@filename}><IMG HEIGHT=100 WIDTH=100 SRC=\"/images/#{@filename}\"></a></pre>"
    else
      REDIS.RPUSH "#{@subject}post","<pre>    (Image: No Image Uploaded)</pre>"
    end
    REDIS.RPUSH "#{@subject}post","<br>"
    REDIS.RPUSH "#{@subject}post","<hr>"

    
    @past_posts.each do |post|
      REDIS.RPUSH "#{@subject}post", post

    end
    @past_posts = REDIS.LRANGE "#{@subject}post", 0, -1
    @numPosts = REDIS.LRANGE "#{@subject}postID", 0, -1
    
  else

    #Get Length of the subject post ID array and increment by and append to get current post ID for that subject
    length = REDIS.LLEN "#{@subject}postID"
    REDIS.RPUSH "#{@subject}postID", length+1
    REDIS.RPUSH "#{@subject}post", "POST# #{length+1}"
    REDIS.RPUSH "#{@subject}post", "Time: #{@time}"
    REDIS.RPUSH "#{@subject}post", "Comment: #{@comment}"
    if not file_info.nil?
      @filename = file_info[:filename]
      REDIS.set "imageName", "#{@filename}"
      REDIS.set "image:#{@filename}", file_info[:tempfile].read
      REDIS.set "content-type:#{@filename}", file_info[:type]
	  #forgot to add IMG tag to display the image instead of just a link
	  REDIS.RPUSH "#{@subject}post", "Image: <a href=/images/#{@filename}><IMG HEIGHT=100 WIDTH=100 SRC=\"/images/#{@filename}\"></a>"
    else
      REDIS.RPUSH "#{@subject}post", "(Image: No Image Uploaded)"
    end
    #to add a line after each post
    REDIS.RPUSH "#{@subject}post","<h4>Reply to POST# #{length+1}</h4><form method='POST' action='/#{@subject}/' enctype='multipart/form-data' /><p><dd><input type='file' size='50' name='replyfile' /></p></dd><p><dd>Enter Comment: <input type='text' size='50' name='replycomment' /></p><input type='hidden' size='50' name='replyTo' value='#{length+1}'/><input type='submit' value='Reply to POST #{length+1}'/></form></dd><p>"
    REDIS.RPUSH "#{@subject}post", "<hr>"
    @past_posts = REDIS.LRANGE "#{@subject}post", 0, -1
    @numPosts = REDIS.LRANGE "#{@subject}postID", 0, -1
  end


  erb :subjects
end
