=begin
- Create templates for _site

_index
_footer
_about

=end

require 'fileutils'
require 'byebug'
require 'amazing_print'

require_relative 'gage/stage'
require_relative 'gage/rsync'

# --- Debugging
# Gage::Stage.metadata('taxa')
# Gage::Stage.metadata('genomes')
# Gage::Stage.metadata('annotations')
# Gage::Stage.debug_metadata
# Gage::Stage.genome_md5s

# The build order is all in .build

=begin
Gage::Stage.check_for_binaries
Gage::Stage.stage_blast_databases # includes wipe
Gage::Stage.stage_metadata
Gage::Stage.stage_sequence_server_jbrowse_links
Gage::Stage.syncronize_data_directories
Gage::Stage.validate_genome_metadata
Gage::Stage.validate_genomes
Gage::Stage.validate_source_directory_structure
Gage::Stage.validate_species_metadata
Gage::Stage.wipe_site_metadata
Gage::Stage::build_tracks
Gage::Stage::stage_jbrowse_data
=end

Gage::Stage.build






