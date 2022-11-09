
TODO:
* Installing SS happens via local copy still! 
  * Make sure that diffs there translate into web-version

# Gage 

Gage is a configuration framework for producing *G*enomic p*AGE*s. It wraps [jBrowse 1](https://jbrowse.org/jbrowse1.html) and [SequenceServer](https://sequenceserver.com/) in website generated by a [Jekyl](https://jekyllrb.com/) wrapper. A simple metadata format allows users to index their genomes and data for the purposes of building a Gage site. A build script stages genomes and annotations then collectively links them together into a unified website.

## Quick start 

Once you complete an _Installation and setup_  using Gage a typical workflow looks like:

```
ruby src/gage.rb # Stages and builds the website
docker compose up
# Navigate to 127.0.0.1 in your browser
```

## Installation and setup (development)

Initial setup involves several stages:
1) Install dependencies
2) Clone the Gage repository to your machine
2a) Temporary.  Install sequence_server from source.
3) Prepare genomic and annotation data
4) Populate configuration files
5) Customize the main webpages
6) Test and refine templates and data

### 1) Install dependencies 

Ensure [Docker](https://www.docker.com/get-started/) and [Ruby](https://www.ruby-lang.org/en/documentation/installation/) (tested on 3.x) and [git]() are installed.

You will also need the following binaries in your PATH, the staging script will test for their presence:
* `tar` - Standard on Linux and Mac
* `bgzip` -  [https://www.htslib.org/doc/bgzip.html](https://www.htslib.org/doc/bgzip.html)
* `samtools` - [https://www.htslib.org/](https://www.htslib.org/)
* `tabix` - [https://www.htslib.org/doc/tabix.html](https://www.htslib.org/doc/tabix.html)
* `gt` - [Genome tools](http://genometools.org/pub/) 

### 2) Clone the Gage repository to your machine

`git clone https://github.com/species_file_group/gage`

### 2a) Install sequence_serer from source

_This is a temporary step at this point, ultimately this will come from the SequenceServer dockerfile directly._

### 3) Prepare genomic and annotation data 

* Create "data" directory outside the `gage` folder. You'll place everything there in preparation for building a gage site. 
* Copy the contents of `gage/_metadata_template` and place them in `data/metadata`. Be careful not to over-write existing files.

Your directory should look like this:

```
data
data/genome
data/metadata
data/metadata/_annotations/
data/metadata/_genomes/
data/metadata/_site/
data/metadata/_taxa/
```

_TODO: Add Gage::Prepare to do this work._

All newly created files stay in your `data` directory within the same place the template it was cloned from.

#### Prepare a genome

* Clone a `_genomes/_genome_template.uuid.md` template. 
* Generate a UUID (see below) for your genome.
* Rename the cloned file in the pattern `genus_species.uuid.md`, use the first 6 alphanumerics of the UUID.  E.g.: `aus_bus.AC9E27.md
* Build your BLAST database. 
  * TODO: Details

#### Prepare an annotation

* Clone and fill in an `_annotations/_annotation_template.uuid.annotation_type.md` template.
* Package your annotation
  * TODO: Details

#### Prepare a taxon
* Clone and fill in an `_annotations/_annotation_template.uuid.annotation_type.md` template.

### 4) Populate configuration files 

#### `_config.yml`

Replace the TODO lines with values or your site.

#### `classification.yml`

Using the example add a classification for your Taxa.

#### TODO: Gage paths!
* TODO: You'll need to provide the paths to your Source and Site.

### 5) Customize the main webpages

You can edit certain elements of the website by editing the `_about.md`, `_contact.md`, _footer.md` and `_index.md` files.  What these do should be self explanitory when you run the staging script and view the website.

### 6) Test and refine templates and data

* In a terminal return to the cloned `gage/` directory.  
* Navigate to inside `/gage/src`     
* !! If this is the first time running the build process, or you've updated the Gage sourec, you must install some Ruby dependencies. To do this type `bundle`.
* Run the staging script: `ruby gage.rb`.

At this point a processing log commences. If it passes without any warnings or fatal errors the website is ready for viewing. Address errors and warnings, and run the script again. Repeat.

The build script is "idempotent", it will always completely rebuild from scratch.*  This lets you keep your two worlds isolated, edit you data in `data`, and stage processed versions where they need to be for the website.

\* This could be customized with a little Ruby. 

## Running a Gage website

Ensure step 6) has passed fully. In a terminal navigate to the `gage/` directory and type `docker compose up`. If this is the first time you've run the command Docker will build the containers. On subsequent runs start will be much faster.  

To stop the docker server use `ctrl-c`.



