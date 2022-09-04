FROM ubuntu
RUN apt update && apt install -y git python3-pip gridsite-clients jq curl python-is-python3
RUN useradd -m -u 1000 pls
WORKDIR /home/pls
RUN git clone https://github.com/daxiongmao87/plexmedia-downloader.git
WORKDIR /home/pls/plexmedia-downloader
RUN pip install -r requirements.txt && pip install yq
COPY get_media_from_library.sh .
RUN chown -R 1000:1000 /home/pls
USER pls
WORKDIR /home/pls/plexmedia-downloader
ENTRYPOINT ["/bin/bash", "-c", "/home/pls/plexmedia-downloader/get_media_from_library.sh"]



