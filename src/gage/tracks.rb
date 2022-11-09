module Gage
  # Store metadata about tracks, and serialize 
  # them to 
  class Tracks

    TRACK_ATTRIBUTES = [
      :urlTemplate, 
      :storeClass,
      :type
    ]

    attr_accessor :refseqs
    attr_accessor :tracks

    def initialize
      @tracks = []
    end

    # @return String 
    def to_file(uuid)
      str = ''

      tracks.select{|a, b| a[:genome_uuid] == uuid}.each do |t|
        str << "[tracks.#{t[:track_name]}]\n"
        [:urlTemplate, :storeClass, :type,
         :max_score, :min_score, :variance_band].each do |v|
           next if t[v].nil?
           str <<  v.to_s + '=' + t[v] + "\n"
         end
        str << "\n"
      end

      str
    end
  end
end
