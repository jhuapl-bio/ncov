FROM continuumio/miniconda3
# continuumio/miniconda3 is FROM debian:latest

# Make RUN commands use `bash --login` (always source ~/.bashrc on each RUN)
SHELL ["/bin/bash", "--login", "-c"]

# install apt dependencies and update conda
RUN apt-get update && apt-get install git -y \
    && apt-get install -y apt-transport-https ca-certificates wget unzip bzip2 libfontconfig1 \
    && update-ca-certificates \
    && apt-get -qq -y remove curl \
    && apt-get -qq -y autoremove \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /var/log/dpkg.log 

ENV PATH /opt/conda/bin:$PATH

RUN conda install -y python=3 \
    && conda update -y conda \
    && conda clean --all --yes

# install TeX libraries
RUN wget -qO- "https://yihui.name/gh/tinytex/tools/install-unx.sh" | sh \
    && export PATH=/root/.TinyTeX/bin/x86_64-linux:/opt/conda/bin:$PATH \
    && tlmgr path add \
    && tlmgr install mnsymbol \
    && tlmgr install multirow \
    && tlmgr install wrapfig \
    && tlmgr install colortbl \
    && tlmgr install pdflscape \
    && tlmgr install tabu \
    && tlmgr install threeparttable \
    && tlmgr install threeparttablex \
    && tlmgr install environ \
    && tlmgr install ulem \
    && tlmgr install makecell 

# configure directory structure exactly as it is on SciServer for ease of transition
RUN mkdir -p /root/idies/workspace/covid19/code \
    && chmod g+s /root/idies/workspace/covid19/code

# install openjdk
WORKDIR /root/idies/workspace/covid19/code
RUN wget https://download.java.net/java/GA/jdk14/076bab302c7b4508975440c56f6cc26a/36/GPL/openjdk-14_linux-x64_bin.tar.gz \
    && tar -xzf openjdk-14_linux-x64_bin.tar.gz \
    && rm openjdk-14_linux-x64_bin.tar.gz \
    && wget https://github.com/samtools/samtools/releases/download/1.10/samtools-1.10.tar.bz2 \
    && tar -xjf samtools-1.10.tar.bz2 \
    && rm samtools-1.10.tar.bz2 \
    && git clone https://github.com/mkirsche/vcfigv \
    && rm -rf vcfigv/.git \
    && wget --no-check-certificate https://americas.oxfordnanoportal.com/software/analysis/ont-guppy-cpu_3.6.1_linux64.tar.gz \
    && tar -xzf ont-guppy-cpu_3.6.1_linux64.tar.gz \
    && rm ont-guppy-cpu_3.6.1_linux64.tar.gz \
    && git clone --recurse-submodules https://github.com/artic-network/artic-ncov2019 \
    && rm -rf artic-ncov2019/.git \
    && git clone https://github.com/cov-lineages/pangolin.git \
    && rm -rf pangolin/.git

# install conda environments
RUN conda env create -f artic-ncov2019/environment.yml \
    && sed -i 's/  - python=3.6/  - python=3.7/' pangolin/environment.yml \
    && conda env create -f pangolin/environment.yml \
    && conda activate pangolin \
    && cd pangolin \
    && python setup.py install \
    && conda clean --all --yes

WORKDIR /root/idies/workspace/covid19/code/ncov/pipeline_scripts
RUN git clone https://github.com/mkirsche/CoverageNormalization.git \
    && git clone https://github.com/mkirsche/VariantValidator.git

# clone cov-lineages
WORKDIR /root/idies/workspace/covid19/ncov_reference
RUN git clone https://github.com/cov-lineages/lineages.git \
    && rm -rf lineages/.git \
    && rm lineages/lineage_summaries/*.svg

# compile java libraries
ENV PATH="/root/idies/workspace/covid19/code/ncov/pipeline_scripts:${PATH}"
ENV PATH="/root/idies/workspace/covid19/code/jdk-14/bin:${PATH}"
ENV PATH="/root/idies/workspace/covid19/code/ont-guppy-cpu/bin:${PATH}"

##################################################################
# configure IGV screenshots in report

# install dependencies for IGV build
RUN apt-get update -qq -y \
    && apt-get install -qq -y xvfb libxtst6 zip unzip curl \
    && curl -s "https://get.sdkman.io" | bash \
    && source "/root/.sdkman/bin/sdkman-init.sh" \
    && sdk install gradle 6.8 \
    && apt-get -qq -y remove curl \
    && apt-get -qq -y autoremove \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /var/log/dpkg.log

# install igv
WORKDIR /root/idies/workspace/covid19/code
RUN git clone https://github.com/igvteam/igv
RUN wget https://download.java.net/java/GA/jdk11/9/GPL/openjdk-11.0.2_linux-x64_bin.tar.gz \
    && tar -xzf openjdk-11.0.2_linux-x64_bin.tar.gz \
    && sed -i 's@SAM.COLOR_BY\tUNEXPECTED_PAIR@SAM.COLOR_BY\tREAD_STRAND@' ./igv/src/main/resources/org/broad/igv/prefs/preferences.tab \
    && sed -i 's@SAM.SORT_OPTION\tNUCLEOTIDE@SAM.SORT_OPTION\tSTRAND@' ./igv/src/main/resources/org/broad/igv/prefs/preferences.tab \
    && sed -i 's@SAM.GROUP_OPTION\tNONE@SAM.GROUP_OPTION\tSTRAND@' ./igv/src/main/resources/org/broad/igv/prefs/preferences.tab \
    && sed -i 's@SHOW_SEQUENCE_TRANSLATION\tFALSE@SHOW_SEQUENCE_TRANSLATION\tTRUE@' ./igv/src/main/resources/org/broad/igv/prefs/preferences.tab \
    && sed -i 's@SAM.SHOW_CENTER_LINE\tShow center line\tboolean\tFALSE@SAM.SHOW_CENTER_LINE\tShow center line\tboolean\tTRUE@' ./igv/src/main/resources/org/broad/igv/prefs/preferences.tab \
    && sed -i 's@IGV.genome.sequence.dir\tGenome server URL\tstring\thttps://s3.amazonaws.com/igv.org.genomes/genomes.txt@IGV.genome.sequence.dir\tGenome server URL\tstring\t/root/idies/workspace/covid19/code/ncov/igv-genomes/genomes.txt@' ./igv/src/main/resources/org/broad/igv/prefs/preferences.tab \
    && sed -i 's@DEFAULT_GENOME_KEY\thg19@DEFAULT_GENOME_KEY\tncov@' ./igv/src/main/resources/org/broad/igv/prefs/preferences.tab \
    && cd /root/idies/workspace/covid19/code/igv \
    && export JAVA_HOME="/root/idies/workspace/covid19/code/jdk-11.0.2" \
    && export PATH=/root/idies/workspace/covid19/code/jdk-11.0.2/bin:$PATH \
    && ./gradlew createDist \
    && rm ../openjdk-11.0.2_linux-x64_bin.tar.gz \
    && rm -rf ../jdk-11.0.2 \
    && find /root/idies/workspace/covid19/code/igv -mindepth 1 -maxdepth 1 -type d ! -name "build" -exec rm -r {} \;

##################################################################

#Copy just the environment.yml file for quick debugging purposes. Comment this out in production
COPY ./environment.yml /root/idies/workspace/covid19/code/ncov/

#Finally, copy over the local files into the working directory and copy rest of necessary environment over to workspace
#COPY ./ /root/idies/workspace/covid19/code/ncov/


RUN conda env create -f /root/idies/workspace/covid19/code/ncov/environment.yml \
    && conda clean --all --yes

# Re-copy yml file and the rest for quick debugging. Comment this out in production
COPY ./ /root/idies/workspace/covid19/code/ncov/
RUN cp -r /root/idies/workspace/covid19/code/ncov/covid19 /root/idies/workspace/ \
    && ln -s /root/idies/workspace/covid19/code/ncov/igv-genomes /root/idies/workspace/covid19 \
    && cp /root/idies/workspace/covid19/code/ncov/barcode_arrs_nb96.cfg /root/idies/workspace/covid19/code/ont-guppy-cpu/data/barcoding/ \
    && cp /root/idies/workspace/covid19/code/ncov/barcodes_masked.fasta /root/idies/workspace/covid19/code/ont-guppy-cpu/data/barcoding/

#################################################################
# copy 13-gene genome.json over into RAMPART directory (which has a 9-gene file by default)
RUN cp /root/idies/workspace/covid19/ncov_reference/genome.json /root/idies/workspace/covid19/code/artic-ncov2019/rampart/genome.json

# set up final environment and default working directory
RUN cat /root/idies/workspace/covid19/bashrc >> /root/.bashrc
RUN chmod -R 755 /root/idies/workspace/covid19/code/ncov/pipeline_scripts/
WORKDIR /root/idies/workspace/covid19
