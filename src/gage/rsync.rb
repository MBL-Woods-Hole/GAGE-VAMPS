

module Gage
  module Rsync 
  
    class << self
      def rsync
        raise 'ENV["GAGE_SOURCE"] rsync path is not set' if ENV['GAGE_SOURCE'].nil?
        FileUtils.mkdir('/tmp/gage')
        `rsync -zrv #{ENV['GAGE_SOURCE']} /tmp/gage`
      end
    end


  end
end

