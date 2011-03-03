Lazy Paperclip -> Paperclip + DelayedJob + Datamapper
=====================================================

Rationale
---------

This is an initial attempt at writing a plugin (I may gemify it later) to solve a problem I have with processing uploaded files.  
If any significant processing needs to be done, I don't want my web server to be tied up running image and audio conversions (especially audio conversions as they are quite time-consuming - video would be worse) in the middle of a request.
I want to be able to hand this off to delayed job and have the processing done offline, and the resource updated when it has been processed.  I initially started working with delayed_paperclip, but the datamapper support wasn't there.  So I've basically taken delayed_paperclip and updated it to use datamapper, and cleaned up and refactored/renamed where I thought that the ActiveRecord idioms were getting in the way or causing kludginess.

Credit
------

Thanks to anybody who has contributed to either paperclip, or dm-paperclip, and delayed job, especially the originators and maintainers (thoughtbot/krobertson/snusnu/dkubb/tobi/collectiveidea)

Status
------

This is reasonably functional right now, but only works with Datamapper.  Ultimately I'd like to set it up for ActiveRecord as well, but I'll wait until I have a bit more time to work on it.

Usage
-----

You'll want to include the aws-s3 gem if you want to use s3 for storage, and the appropriate Datamapper/DelayedJob gems. 

		gem 'sauberia-aws-s3',          :git => "git://github.com/pschuegr/aws-s3.git", :require => "aws/s3"
		gem 'delayed_job',              '2.1.0.pre2'
		gem 'delayed_job_data_mapper',  '1.0.0.rc'
		gem 'dm-core',              		'~> 1.0.2'

Then you need to set up your resources.

		class Track

			include DataMapper::Resource
			include Paperclip::Resource

			property :id, Serial
			property :name, String

			belongs_to :album

			has_attached_file :audio,
								:styles => { :mp3 => { :encoding => :mp3, :stylists => [:convert_audio]},
														 :ogg => { :encoding => :vorbis, :stylists => [:convert_audio]},
														 :flac => { :encoding => :flac, :stylists => [:convert_audio]}},
								:path => ->(track) { "albums/#{Album.get(track.album_id).artist_id}/tracks/:id/:style.:ext" },
								:processing_url => ->(track) { "/images/processing_track_:style.:ext}" },
								:default_style => :mp3,
								:storage => :s3,
								:s3_credentials => File.join(Rails.root.to_s, "config", "s3.yml"),
								:s3_content_disposition => ->(track) { "#{track.album.artist.name} - #{track.name}" },
		end

Notes
------

* I still have to rename the whole thing to LazyPaperclip instead of Paperclip.  
* What paperclip called processors I refer to as stylists, because I mentally separate the styling (performing actions on the resource which modify the look/sound/feel) from processing (everything that happens to the upload to produce the finished product) - processing can include many different stylists.  I hope that isn't too confusing for anybody.
* Once the upload has been completed but the resource hasn't been processed yet, the resource can be represented by a placeholder => the "processing url".
* the actual storage name/path which were interpolated by paperclip can now be lambdas.
* Aaaand naturally I need to update the comments...
