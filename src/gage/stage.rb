
# TODO:
# * use `refseqs` in links.rb file
# * check result of indexing - does increasing memory help (256MB -> ?)
# *
#
#
# Validations
# - gage_file ends in .gz (not .tgz)
# - gage track name is unique among same types

# Code
# - CLI debug flag to toggle 2> dev/nul
# sequence_server_prefix is not required

# 0 See rsync.rb

require 'front_matter_parser'
require 'digest'
require 'amazing_print'
require 'rainbow'
require 'jekyll'

require_relative 'annotations'
require_relative 'genomes'
require_relative 'tracks'


COLOR = {
  info: :gold,
  fatal: :red,
  warning: :orange,
  passed: :darkgreen,
  file: :lightgray
}.freeze

module Gage
  module Stage

    SITE_MANIFEST = {
      '/_includes' => %w{ _about.html _contact.html _footer.html _index.html },
      '/' => %w{_config.yml},
      '/data' => %w{classification.yml}
    }

    # The location of the build, prior to moving
    BUILD_DIR = '/usr/local/tmp/gage/'

    # This is the expected layout of the raw (incoming) data
    METADATA_LAYOUT = %w{
      genome
      metadata
      metadata/_annotations
      metadata/_taxa
      metadata/_genomes
    }

    # Repository clone location
    GAGE_DIR = '/usr/local/www/vamps/projects/seabase/gage/'
    #GAGE_DIR = '/users/avoorhis/programming/seabase/gage/' #'/Users/matt/src/github/species_file_group/gage/'

    # Data originate here
    SOURCE_DATA_DIR = '/usr/local/www/vamps/projects/seabase/data/'
    #SOURCE_DATA_DIR = '/users/avoorhis/programming/seabase/data/' #'/Users/matt/src/github/species_file_group/gage/raw_data'

    # Raw Blast databases are here
    SOURCE_GENOME_DATA = File.expand_path('genome', SOURCE_DATA_DIR)

    # Source metadata (Jekyl files) originate here
    SOURCE_METADATA = File.expand_path('metadata', SOURCE_DATA_DIR)

    # Website is staged here. We don't check to see that these directories are in place.
    SITE_DIR = File.expand_path('site', GAGE_DIR) # '/Users/matt/src/github/species_file_group/gage/site'

    # Metadata demplates are placed here.
    SITE_METADATA = File.expand_path('data', SITE_DIR)

    # Genome data are staged here
    DATA_DIR = File.expand_path('data', GAGE_DIR) # '/Users/matt/src/github/species_file_group/gage/data'

    # Blast databases for sequence server go here
    SEQUENCE_SERVER_DATA = File.expand_path('sequenceserver', DATA_DIR)

    # jBrowse tracks go here
    JBROWSE_DATA = File.expand_path('jbrowse', DATA_DIR)

    class << self

      # Order dependent at this point
      def build
        # debug_metadata
        # check_for_binaries

        validate_source_directory_structure
        validate_species_metadata
        validate_genome_metadata
        validate_genomes

        prepare_build_dirs

        syncronize_data_directories
        wipe_site_metadata

        stage_blast_databases
        stage_metadata
        stage_site

        write_gage_metadata_ruby
        build_tracks
        stage_jbrowse_data

        jekyll_build
      end

      def jekyll_build
        msg('Building site', :info)
        config = Jekyll.configuration({
          'source' => SITE_DIR,
          'destination' => File.expand_path('_site', SITE_DIR)
        })
        site = Jekyll::Site.new(config)
        Jekyll::Commands::Build.build site, config
      end

      def metadata(metadata_type = 'taxa', target = :source)
        case target
        when :source
          base = File.expand_path('_' + metadata_type, SOURCE_METADATA)
        when :site
          base = File.expand_path('_' + metadata_type, SITE_DIR + '/data/')
        end

        # TODO: ignore not just _template but all _ files
        Dir.glob('**/*.md', base: base).collect{|a| File.basename(a, File.extname(a))} - ['_template']
      end

      def genome_species
        Dir.glob('**', base: SOURCE_GENOME_DATA)
      end

      # @return [Array]
      #   Full path to SOURCE md metadata files
      def metadata_files_for(target = :genomes)
        Dir.glob( '**/*.md', base: File.expand_path("_#{target}", SOURCE_METADATA))
          .collect{|f|
            File.expand_path("_#{target}", SOURCE_METADATA ) + '/' + f
          }.delete_if{ |g| File.basename(g)[0] == '_'} # leading _, e.g. _template_md or temporary files
      end

      # @return [Array] of zipped data files
      # DEPRECATED: we calculate this from the metadata now.
      def blast_databases
        Dir.glob( '**/blast/**/*.tgz', base: SOURCE_GENOME_DATA)
      end

      def genome_md5s
        Dir.glob( '**/blast/**/*.md5', base: SOURCE_GENOME_DATA)
      end

      def annotations
        Dir.glob( '**/jbrowse/**/*.tgz', base: SOURCE_GENOME_DATA)
      end

      def annotation_md5s
        Dir.glob( '**/jbrowse/**/*.md5', base: SOURCE_GENOME_DATA)
      end

      # @return [hash]
      #  { uuid[0..5]: {
      #    values
      #  }
      #  }
      def metadata_for(target = :genomes)
        h = {}
        metadata_files_for(target).each do |f|
          begin
            d = FrontMatterParser::Parser.parse_file(f)

            case target
            when :genomes
              h[d['gage_genome_id']] = d.front_matter
            when :annotations
              h[d['gage_annotation_id']] = d.front_matter
            end

          rescue Psych::DisallowedClass
          end
        end
        h
      end

      def validate_species_metadata
        errors = 0
        (genome_species - metadata('taxa')).each do |m|
          msg("Missing metadata for #{m}.", :warning)
          errors += 1
        end

        (metadata('taxa') - genome_species).each do |m|
          msg("Missing genome for #{m}.", :warning)
          errors += 1
        end

        msg("Species metadata OK", :passed) if errors == 0
      end

      # @return [boolean]
      #   TODO: log silently or on request
      def validate_genome_metadata
        msg("Validating genome metadata.", :info)
        errors = 0
        metadata_files_for(:genomes).each do |f|
          begin
            d = FrontMatterParser::Parser.parse_file(f)
          rescue Psych::DisallowedClass
            errors +=1
            msg("#{f} is invalid. It likely has _date that is not quoted.", :warning)
          end
          msg("Processed #{f}", :passed)
        end

        msg("Genome metadata OK", :passed) if errors == 0
        errors == 0 ? true : false
      end

      def required_data_directories
        a = [ DATA_DIR, SEQUENCE_SERVER_DATA, JBROWSE_DATA ]
        metadata('taxa').each do |s|
          [SEQUENCE_SERVER_DATA, JBROWSE_DATA].each do |t|
            a.push File.expand_path(s, t)
          end
        end
        a
      end

      def validate_source_directory_structure
        msg("Validating source directory structure.", :info)
        errors = 0
        [
          SOURCE_DATA_DIR,
        ].each do |d|
          METADATA_LAYOUT.each do |l|
            p = File.expand_path(l, d)
            if Dir.exists?( p )
              msg("Found #{p}", :passed)
            else
              msg("Can not find #{p}", :warning)
              errors += 1
            end
          end
        end

        if errors > 1
          msg("Errors in directory structure", :fatal)
        end
      end

      # TODO: presently unused
      # @return Hash
      #   uuid => unzipped source file
      def debug_metadata
        msg('Blast database', :info)
        puts blast_databases
        msg('Genome metadata files', :info)
        puts metadata_files_for(:genomes)

        metadata_for(:genomes).each do |k,v|
          puts genome_path(k)
        end
        # puts genomes
      end

      # @return [String]
      #   the relative path to the un/zipped
      #   genome file data its staged position
      def genome_path(uuid, zipped = false)
        d = metadata_for(:genomes)[uuid]
        [ staging_subpath(uuid),
          File.basename( d['gage_file'], '.gz' ),
          (zipped ? File.extname( d['gage_file'] ) : nil)
        ].compact.join('/')
      end

      def staging_subpath(uuid)
        d = metadata_for(:genomes)[uuid]
        [ filenameify(d['organism']),
          d['gage_path_prefix']
        ].compact.join('/')
      end

      def filenameify(species)
        species.gsub(/ /, '_').downcase
      end

      # Root structure
      # Species structure - jbrowse
      # Species structure - sequence server
      def syncronize_data_directories
        msg("Creating required directories", :info)

        created = 0
        required_data_directories.each do |d|
          if Dir.exists?( d )
            msg("Found #{d}, skipping", :passed)
          else
            created +=1
            Dir.mkdir(d)
            msg("Created #{d}, skipping", :file)
          end
        end

        msg("Syncronized required data directories", :passed) if created > 1
      end

      def stage_metadata
        msg("Moving metadata to _site", :info)
        ['_taxa', '_genomes', '_annotations'].each do |t|
          a = SOURCE_METADATA + '/' + t
          if Dir.exists?(a).to_s
            msg(a + ' found', :passed)
          else
            msg(a + ' not found', :fatal)
          end

          b = SITE_DIR + '/data/'
          if Dir.exists?(b).to_s
            msg(b + ' found', :passed)
            FileUtils.cp_r(a, b, remove_destination: true)
          else
            msg(b + ' not found', :fatal)
          end
        end
      end

      def stage_site
        msg("Staging _site", :info)
        SITE_MANIFEST.values.flatten.each do |f|
          a = File.expand_path(f, SOURCE_METADATA + '/_site')
          if File.exists?(a)
            msg(a + ' found', :passed)
          else
            msg(a + ' not found', :warning)
          end
        end

        SITE_MANIFEST.each do |path, files|
          files.each do |f|
            src = File.expand_path(f, SOURCE_METADATA + '/_site/')
            dest = File.expand_path(f, SITE_DIR + path)

            if File.exists?(src)
              msg("From: #{src}, to: #{dest}", :file)
              FileUtils.cp(src,dest)
            else
              msg(f + ' skipped!', :warning)
            end
          end
        end
      end

      def validate_genomes
        errors = 0
        genome_md5s.each do |path|
          base = File.expand_path( File.dirname(path), SOURCE_GENOME_DATA)
          sum, name = File.read(File.expand_path(path, SOURCE_GENOME_DATA)).split.map(&:chomp)
          md5 = Digest::MD5.new
          md5 << File.read(File.expand_path(name, base))
          h = md5.hexdigest
          if h == sum
            msg("#{name} checksum matched", :passed)
          else
            msg("#{name} checksum NOT MATCHED", :warning)
            errors += 1
          end
        end
        msg("Detected #{errors} errors.", (errors > 0 ? :warning : :info))
        true
      end

      def wipe_site_metadata
        msg("Wiping site metadata", :info)
        FileUtils.rm_rf(SITE_METADATA)
        FileUtils.mkdir(SITE_METADATA)
      end

      # Remove the jBrowse and Sequence Server
      # directories from production
      def wipe_genome_data
        msg("Wiping genome metadata", :info)
        FileUtils.rm_rf(DATA_DIR)
        FileUtils.mkdir(DATA_DIR)

        FileUtils.mkdir(SEQUENCE_SERVER_DATA)
        FileUtils.mkdir(JBROWSE_DATA)
      end

      def stage_blast_databases(wipe = true, unzip = true)
        wipe_genome_data if wipe

        msg('Moving genomes to /data/sequenceserver', :info)

        # Only stage those we have metadata for
        metadata_for(:genomes).each do |uuid, d|
          subpath = staging_subpath(uuid)

          dest_species_dir = File.expand_path(
            filenameify(d['organism']),
            SEQUENCE_SERVER_DATA)

          src_dir = File.expand_path(subpath + '/blast', SOURCE_GENOME_DATA)
          dest_dir = File.expand_path(subpath, SEQUENCE_SERVER_DATA)

          if !Dir.exists?( dest_species_dir )
            FileUtils.mkdir( dest_species_dir )
          end

          if !Dir.exists?( dest_dir)
            FileUtils.mkdir(dest_dir)
          end

          # Loop the zipped files, these are each a blast database
          Dir.glob( '*.tgz', base: src_dir).each do |blastdb|

            # TODO: validate MD5s perhaps at this point
            src = File.expand_path(blastdb, src_dir)
            dest = File.expand_path(blastdb, dest_dir)

            msg("From: #{src}, to: #{dest}", :file)
            FileUtils.cp(src, dest)

            if unzip
              msg("unpacking #{dest}", :file)
              `tar -xzf #{dest} -C #{dest_dir}`
            end
          end
        end
      end

      # Print the metadata to screen
      def debug_metadata(type = :genomes)
        g = metadata_for(type)
        ap g
      end

      def prepare_build_dirs
        FileUtils.rm_rf(BUILD_DIR)
        FileUtils.mkdir(BUILD_DIR)
        FileUtils.chmod_R(0755, BUILD_DIR)
      end

      # TODO:
      # * DRY naming with genome above
      # * Split into 2 methods? build stage, track stage
      # Requires `prepare_build_dirs -> Rake!!
      def build_tracks
        msg("Building jBrowse tracks", :info)

        g = metadata_for(:genomes)

        # Array of UUIDs. A genome file with this UUID is missing.
        invalid_metadata = []

        build_data_dirs = {}

        tracks = Gage::Tracks.new

        # Expand the genome and
        # annotation data into the build dir
        g.each do |genome_uuid, d|
          subpath = staging_subpath(genome_uuid)
          species = filenameify(d['organism'])

          src_dir = File.expand_path(subpath + '/jbrowse/', SOURCE_GENOME_DATA)
          build_species_dir = File.expand_path(species, BUILD_DIR)
          build_dir =  File.expand_path(subpath, BUILD_DIR)

          # Only generate the build dirs here, we're not positive there are annotation
          # tracks to move
          [build_species_dir, build_dir].each do |dir|
            if !Dir.exists?( dir )
              FileUtils.mkdir( dir )
              # FileUtils.chmod_R(0755, dir)
            end
          end

          if Dir.exists?(src_dir)
            msg('Staging jBrowse data', :info)           # Copy the jbrowse data files over to tmp
            FileUtils.cp_r("#{src_dir}/.", build_dir)
          else
            msg("Can not find #{src_dir}", :fatal)
            next
          end

          # TODO: This is a little crude, we might want to reference the source in
          # the _annotation.md
          Dir.glob( '*.tgz', base: build_dir).each do |tf|
            tf = File.expand_path(tf, build_dir)
            msg("unpacking #{tf}", :file)
            `tar -xzf #{tf} -C #{build_dir}`
          end

          # Check for the genome file, and unzip it if present

          genome_file = File.expand_path(d['gage_file'], build_dir)
          if File.exists?( genome_file )
            msg(genome_file + ' found, unzipping', :file)
            `gunzip #{genome_file}`
          else
            msg(genome_file + ' not found!', :file)
            next
          end

          unzipped_genome_file =
            File.expand_path(
              File.basename(genome_file, '.gz'),
              build_dir)

          jbrowse_data_dir = File.expand_path('data/', build_dir)
          FileUtils.mkdir(jbrowse_data_dir)
          FileUtils.chmod_R(0755, jbrowse_data_dir)

          msg("Writing to #{jbrowse_data_dir}", :info)

          build_data_dirs[genome_uuid] = jbrowse_data_dir

          # fai is file.fa.fai format.
          fai = d['gage_file'].split('.')
          fai.pop
          fai = fai.join('.') + '.fai'
          fai = jbrowse_data_dir + '/' + fai

          a = "samtools faidx #{unzipped_genome_file} -o #{fai} 2> /dev/null" # TODO: suppress stderr optional
          msg(a, :file)

          `#{a}` # Shell out and run

          # copy the fa file to /data
          FileUtils.cp(unzipped_genome_file, jbrowse_data_dir )

          tracks_conf = File.expand_path('tracks.conf', jbrowse_data_dir)

          f = File.new(tracks_conf , "w")
          f.puts '[GENERAL]'
          f.puts 'refSeqs=' + fai.split('/').last
          f.puts '[tracks.refseqs]' # TODO: maybe change this
          f.puts 'urlTemplate=' + unzipped_genome_file.split('/').last
          f.puts 'storeClass=JBrowse/Store/SeqFeature/IndexedFasta'
          f.puts 'type=Sequence'
          f.puts

          f.close
        end

        metadata_for(:annotations).each do |uuid, d|
          gage_track_label = d['gage_trackname']

          msg("Building track #{gage_track_label}", :info)

          genome_uuid = d['gage_genome_id']
          subpath = staging_subpath(genome_uuid)
          species = filenameify(g[genome_uuid]['organism'])

          build_dir =  File.expand_path(subpath, BUILD_DIR)

          track = {
            urlTemplate: nil,
            storeClass: nil,
            type: nil,
            # TODO: we might be able to add more track metadata to display in interface here.
          }

          # Move the necessary build file from site
          # and unzip it if necessary

          # Recheck for the target genome, we might
          # not have found it
          target_genome = File.expand_path(
            File.basename(g[genome_uuid]['gage_file'], '.gz'),
            build_dir)

          if !File.exists?(target_genome)
            msg(target_genome + ' not found!', :warning)
            next
          end

          target_annotation = File.expand_path(
            d['gage_file'],
            build_dir
          )

          if File.exists?(target_annotation)
            # unzip the annotation file
            msg(target_annotation + ' found, unzipping', :file)
            `gunzip #{target_annotation}`
          else
            msg(target_annotation + ' not found!', :warning)
            next
          end

          unzipped_target_annotation =
            File.expand_path(
              File.basename(target_annotation, '.gz'),
              build_dir)

          if File.exists?(unzipped_target_annotation)
            jbrowse_data_dir = build_data_dirs[d['gage_genome_id']]

            case d['annotation_type'].downcase

            when 'gff' # change when gff3
              sorted =  File.basename(unzipped_target_annotation, '').split('.')
              sorted = sorted.insert((sorted.count - 1),'sorted').join('.')

              # suppress warnings
              a = "gt gff3 -sortlines -tidy -o #{jbrowse_data_dir}/#{sorted} #{unzipped_target_annotation} 2> /dev/null" # 2> /dev/null
              msg(a, :file)
              `#{a}`

              b = "bgzip #{jbrowse_data_dir}/#{sorted}"
              msg(b, :file)
              `#{b}`

              c = "tabix -p gff #{jbrowse_data_dir}/#{sorted}.gz"
              msg(c, :file)
              `#{c}`

              track[:urlTemplate] = sorted + '.gz'
              track[:storeClass] = 'JBrowse/Store/SeqFeature/GFF3Tabix'
              track[:type] = 'CanvasFeatures'
              track[:genome_uuid] = d['gage_genome_id']
              track[:track_name] = d['gage_trackname']
            when 'bigwig'
              FileUtils.cp_r(unzipped_target_annotation, jbrowse_data_dir)

              track[:urlTemplate] =  unzipped_target_annotation.split('/').last
              track[:storeClass] = 'JBrowse/Store/SeqFeature/BigWig'
              track[:type] = 'JBrowse/View/Track/Wiggle/XYPlot'
              track[:genome_uuid] = d['gage_genome_id']
              track[:track_name] = d['gage_trackname']

              # track[:variance_band] = 'true'
              track[:max_score] = '100000000' # Going to have to check this
              track[:min_score] = '-1000'
            else
              msg('Skipping track build.', :warning)
            end
          else
            msg(unzipped_target_annotation + ' not found', :warning)
          end

          tracks.tracks.push track
        end

        # Write the tracks.conf files
        build_data_dirs.keys.each do |uuid|
          f = File.open( File.expand_path('tracks.conf', build_data_dirs[uuid]), "a")
          f.puts tracks.to_file(uuid)
          f.close
        end

        write_jbrowse_conf(BUILD_DIR, g)

        true
      end

      def write_jbrowse_conf(build_dir, metadata_for_genomes)
        msg('Writing jbrowse.conf', :info)
        g = metadata_for_genomes
        f = File.open( File.expand_path('jbrowse.conf', BUILD_DIR), "w")

        f.puts '[GENERAL]'
        f.puts "# !! This file is auto-generated, it will be over-written. !!\n"

        # Note, this file is currently *not* generated by gage. See README.md for notes.
        f.puts 'include = {dataRoot}/trackList.json'

        f.puts 'include += {dataRoot}/tracks.conf'
        f.puts "\n"

        g.keys.each do |uuid|
          s = g[uuid]['organism'].downcase.gsub(' ', '_')
          f.puts '[datasets.' + [ s, g[uuid]['gage_path_prefix']].compact.join('_') + ']'
          f.puts "url  = ?data=data/" + [s, g[uuid]['gage_path_prefix']].compact.join('/') + '/'
          f.puts 'name = ' + [ g[uuid]['organism'], g[uuid]['gage_path_prefix'] ].compact.join(' ')
          f.puts "\n"
        end

        f.close
      end

      def msg(text, type = :info)
        return if text.nil? || text.length == 0
        # lead
        case type
        when :info
          print Rainbow('▩ ').send(COLOR[type])
        when :fatal
          print Rainbow(' 𐄂 !!').send(COLOR[type])
        when :warning
          print Rainbow(' ⚠ ').send(COLOR[type])
        when :file
          print Rainbow(" □ ").send(COLOR[type])
        when :passed # indent 4
          print ' ✓ '
        end

        # text
        puts Rainbow(text).send(COLOR[type])
      end

      # TODO: check permissions on each as well?
      def check_for_binaries
        msg('Checking for necessary* binaries', :info)
        ['tar', 'samtools', 'bgzip', 'tabix', 'gt'].each do |t|
          if which(t)
            msg('Found ' + t, :passed)
          else
            msg('Not found ' + t, :fatal)
          end
        end
      end

      def stage_jbrowse_data
        msg('Moving tracks and config to /data/jbrowse', :info)

        metadata_for(:genomes).each do |genome_uuid, d|
          subpath = staging_subpath(genome_uuid)
          species = filenameify(d['organism'])

          build_dir =  File.expand_path(subpath, BUILD_DIR)
          jbrowse_data_dir = File.expand_path('data/', build_dir)

          dest_species_dir = File.expand_path(species, JBROWSE_DATA)
          dest_dir = File.expand_path(subpath, JBROWSE_DATA)

          src_dir = jbrowse_data_dir # File.expand_path(subpath + '/blast', SOURCE_GENOME_DATA)

          msg("From: #{src_dir}, to: #{dest_dir}", :file)

          if !Dir.exists?( dest_species_dir )
            FileUtils.mkdir( dest_species_dir )
          end

          if !Dir.exists?( dest_dir)
            FileUtils.mkdir(dest_dir)
          end

          FileUtils.cp_r("#{src_dir}/.", dest_dir)
        end

        a = File.expand_path('jbrowse.conf', BUILD_DIR )
        b = File.expand_path('config/jbrowse/jbrowse.conf', GAGE_DIR)

        msg("From: #{a}, to: #{b}", :file)

        FileUtils.cp( a,b )

        # The Sequence server link bridge constant
        a = File.expand_path('gage_metadata.rb', BUILD_DIR )
        b = File.expand_path('config/sequenceserver/gage_metadata.rb', GAGE_DIR)
        msg("From: #{a}, to: #{b}", :file)
        FileUtils.cp( a,b )
      end

      # We use the UUID as a signature
      # so that we can build links from SS to jBrowse.
      def write_gage_metadata_ruby
        msg('Writing gage_metadata.rb', :info)

        x = metadata_for(:genomes)
        d = {}
        x.each do |k, v|
          s = k[0..7]
          d[s] = { genome_id: s, data: v['organism'].downcase.gsub(' ', '_') }
        end

        y = metadata_for(:annotations)
        d.merge! y.keys.inject({}){|hsh,k| hsh[k[0..7]] = { genome_id:  y[k]['gage_genome_id'][0..7], name: y[k]['source_name'], data: d[ y[k]['gage_genome_id'][0..7] ][:data] } ; hsh  }

        f = File.open( File.expand_path('gage_metadata.rb', BUILD_DIR), "w")

        f.puts "# !! This file is auto-generated, it will be over-written. !!\n"
        f.puts "\n"

        f.puts "module GageMetadata"
        f.puts "GAGE_METADATA = {"

        i = []
        d.each do |k,v|
          i.push "  '#{k}' => { genome_id: #{ v[:genome_id] ?  "'" + v[:genome_id] + "'" : 'nil' }, name: #{  v[:name] ? '"' + v[:name] + '"'  : 'nil' },  data: '#{v[:data]}'  }"
        end

        f.puts i.join(",\n")
        f.puts "}"

        f.puts "end"

        f.close
      end

      # Yoinked directly from https://stackoverflow.com/questions/2108727/which-in-ruby-checking-if-program-exists-in-path-from-ruby
      # Cross-platform way of finding an executable in the $PATH.
      #
      #   which('ruby') #=> /usr/bin/ruby
      def which(cmd)
        exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
        ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
          exts.each do |ext|
            exe = File.join(path, "#{cmd}#{ext}")
            return exe if File.executable?(exe) && !File.directory?(exe)
          end
        end
        nil
      end
    end # end class methods
  end
end
