## Preparing data files for GAGE
1.  download genome sequence, gff
2.  record download date and other relevant version data
3.  Examine sequence names and gff 
    - can use gffreads to extract cds or protein or other features to fasta file
    - may need to change sequence names to properly match gff
4.  Checkout uuid for genome, gff(s) from master uuid list
5.  Create md files by copying template files and editing<br>
    `cp /data_staging/metadata/_taxa/_template.md  /data_staging/metadata/_taxa/genus_species.md`<br>
    `cp /data_staging/metadata/_genomes/_template.md  /data_staging/metadata/_genomes/genus_species_strain`<br>
    `cp /data_staging/metadata/_annotations/_template.uuid.annotation_type.md /data_staging/metadata/_annotations/genus_species.uuid.gff.md`<br>
    - repeat for each gff, bigwig, bam, etc
    - currently must use “gff” in annotation_type, not “gff3” "gf3" etc
6.  Create data staging directories 

    `mkdir -p data_staging/genome/genus_species/assembly/jbrowse`
    - Copy or move original genome, gff file names to gage-convention file names
    - gzip fa and gff<br>
    `genus_species_genome.fa.gz`<br>
    `genus_species_genome.fa.fai`<br>
    `genus_species_source.gff.gz`<br>
    `tar czfv genus_species.jbrowse.tgz genus_species_*`<br>
    `rm genus_species_* tar`<br>
    `md5sum genus_species.jbrowse.tgz > genus_species.jbrowse.tgz.md`<br>
    - Final contents should be:<br>
        > genus_species.jbrowse.tgz<br>
        > genus_species.jbrowse.tgz.md<br>

    `mkdir -p data_staging/genome/genus_species/assembly/blast`<br>
    - Genome deflines should be ‘gnl|genome_uuid|genome_uuid_SeqName’
    - Feature fasta deflines should be ‘gnl|genome_uuid|gff_uuid_SeqName’
    - make the blast databases<br>
        (note: -title “this appears in SeqServer as the db name”)<br>

        `makeblastdb -blastdb_version 5 -parse_seqids -taxid [] -title "[]" -dbtype nucl  -in [] -out genus_species.genome`<br> 
        `makeblastdb -blastdb_version 5 -parse_seqids -taxid [] -title "[]" -dbtype nucl  -in [] -out genus_species.cds`<br>
        `makeblastdb -blastdb_version 5 -parse_seqids -taxid [] -title "[]" -dbtype prot  -in [] -out genus_species.pep`<br>
        `tar czfv genus_species.genome-blastdb.tgz genus_species.genome.n??`<br>
        `tar czfv genus_species.cds-blastdb.tgz genus_species.cds.n??`<br>
        `tar czfv genus_species.pep-blastdb.tgz genus_species.pep.p??`<br>
        `for i in 'ls *tgz'; do md5sum $i > $i.md5; done`<br>

7.  Final staging
    - in local seabase<br>
    `cd data`<br>
    `rsync -aP evol5.mbl.edu:/groups/markwelchlab/seabase/data_staging/* .`<br>
    `cd gage/src`<br>
    `ruby gage.rb`<br>
    `docker compose up`<br>
    - in other window:<br>
    `docker ps`<br>
    (output includes sha of docker container)<br>
    `docker exec -it [sha] bash`<br>
    `cd /conda/opt/jbrowse/data/genus_species`<br>
    `generate-names.pl --out /conda/opt/jbrowse/data/genus_species`<br>
        (this will take awhile)<br>
    `exit`<br>
    `mkdir seabase/names-holder/genus_species`<br>
    `cp -R gage/data/jbrowse/genus_species/names  names-holder/genus_species/`<br>
    `cp gage/data/jbrowse/genus_species/trackList.json names-holder/genus_species/`<br>
Note: after every execution of gage.rb, each genus_species/names directory and genus_species/trackList.json is wiped out and must be rebuilt or copied from names-holder/genus_species/ or wherever you've chosen to store a backup.  

TO DO:
1.  what to do about strains?
  a.  genus_species_strain?
  b.  genus_speciesstrain?
  c.  will effect 
    i.  _taxon
    ii. _genomes
2.  assembly version in genome?
3.  names – won’t follow symlink; trackList.json can’t even be a hard link
  a.  --completionLimit 5 (default 20) had no effect on number of files or total size.  Didn’t seem to effect autocompletion
  b.  –completionLimit 0 increased number of files to 212616 and total size to 831M.  Still didn’t seem to effect autocompletion

