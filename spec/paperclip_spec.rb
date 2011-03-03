require 'tempfile'
require 'active_support/dependencies'
require 'action_dispatch/http/upload'
require 'paperclip'
require 'paperclip/resource'
require 'paperclip/configuration'
require 'paperclip/stylist'
require 'dm-core/support/descendant_set'
require 'dm-core/support/deprecate'
require 'dm-core/support/assertions'
require 'dm-core/support/chainable'
require 'dm-core/resource'
require 'dm-core/model'
require 'dm-validations'
require 'dm-validations/auto_validate'
require 'dm-sqlite-adapter'
require 'dm-migrations'
require 'dm-migrations/auto_migration'
require 'dm-observer'
require 'delayed_job'
require 'delayed/backend/data_mapper'
require 'paperclip/jobs/delayed_paperclip_job'
require 'rails'

describe Paperclip do
  before :all do
    DataMapper.setup(:default, 'sqlite::memory:')
    Delayed::Worker.backend = :data_mapper
    #Paperclip.logger = Logger.new(STDOUT);

    Paperclip.configure do |config|
      config.root               = File.expand_path('.') # the application root to anchor relative urls (defaults to Dir.pwd)
      config.env                = 'test'
      config.use_dm_validations = true # validate attachment sizes and such, defaults to false
      config.stylists_path      = 'lib/paperclip_stylists' # relative path to look for stylists
    end

    class FileSystemAsset
      include DataMapper::Resource
      include Paperclip::Resource

      property :id, Serial
      property :id, Serial
      has_attached_file :image,
        :styles => {  :small => { :encoding => :png, :size => "200x200", :stylists => [:convert_image]},
          :large => { :encoding => :jpg, :size => "400x400", :stylists => [:convert_image]},
          :original => { :stylists => [:null]}},
          :storage => :filesystem,
          :default_style => :small,
          :root => "/tmp/final",
          :path => ->(asset) { "assets/:id/image_:style.:ext" },
          :processing_url => ->(asset) { "/assets/processing_image_:style.png" }
    end

    class S3Asset
      include DataMapper::Resource
      include Paperclip::Resource

      property :id, Serial
      has_attached_file :image,
        :styles => {  :small => { :encoding => :png, :size => "200x200", :stylists => [:convert_image]},
          :large => { :encoding => :jpg, :size => "400x400", :stylists => [:convert_image]},
          :original => { :stylists => [:null]}},
          :storage => :s3,
          :default_style => :small,
          :path => ->(asset) { "assets/:id/image_:style.:ext" },
          :s3_credentials => {bucket: 'bucket.host.com', access_key_id: "xxx_ACCESS_KEY_ID_xxx", secret_access_key: "xxx_SECRET_ACCESS_KEY_xxx"},
          :processing_url => ->(asset) { "/assets/processing_image_:style.png" }
    end
    DataMapper.auto_upgrade!
  end

  before :each do
    FileSystemAsset.all.destroy!
    S3Asset.all.destroy!
    Delayed::Job.delete_all
  end

  def create_and_save(storage_type, process = true)
    a = Kernel.const_get(storage_type).new
    tempfile = Tempfile.new("temp_image")
    File.open("spec/data/image_square.png", 'r') {|file| tempfile.write file.read} 
    upfile = ActionDispatch::Http::UploadedFile.new({ :filename => "image_square.png", :content_type => "image/png", :tempfile => tempfile })
    a.image = upfile
    a.save

    if process
      worker = Delayed::Worker.new
      worker.work_off 1
      a.reload
    end

    a
  end

  STORAGE_TYPES = ['FileSystemAsset', 'S3Asset']
  STORAGE_TYPES.each do |storage_type|
    context storage_type do
      before :all do
        puts "\nContext: #{storage_type}\n"
      end

      it "should exist" do
      end

      it "should default to processing url" do
        a = Kernel.const_get(storage_type).new
        a.image.url.should == "/assets/processing_image_small.png"
      end

      it "should start in invalid status" do
        a = Kernel.const_get(storage_type).new
        a.image.status = Paperclip::Attachment::INVALID
      end

      it "should be assignable" do
        a = Kernel.const_get(storage_type).new
        tempfile = Tempfile.new("temp_image")
        File.open("spec/data/image_square.png", 'r') {|file| tempfile.write file.read} 
        upfile = ActionDispatch::Http::UploadedFile.new({ :filename => "image_square.png", :content_type => "image/png", :tempfile => tempfile })
        a.image = upfile
        a.save.should == true
      end

      it "should change status to uploaded after assigned" do
        a = create_and_save(storage_type, false)
        a.image.status.should == Paperclip::Attachment::UPLOADED
      end

      it "should place file in the proper location" do
        a = create_and_save(storage_type, false)
        File.exist?("/tmp/assets/#{a.id.to_s}/image_upload.upload").should == true
      end

      it "should process the job properly" do
        a = create_and_save(storage_type, true)
        a.image.status.should == Paperclip::Attachment::STORED
      end

      it "should remove processing files" do
        a = create_and_save(storage_type, true)
        File.directory?("/tmp/assets/#{a.id.to_s}").should == false
      end
    end
  end
end
