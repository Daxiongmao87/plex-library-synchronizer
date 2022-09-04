# Plex Library Synchronizer
## Links
- [Plex Library Synchronizer - Dockerfile Repository](https://github.com/Daxiongmao87/plex-library-synchronizer)
- [Plex Library Synchronizer - Dockerhub](https://hub.docker.com/repository/docker/daxiongmao87/plex-library-synchronizer)
- [Plexmedia Downloader - Repository](https://github.com/Daxiongmao87/plexmedia-downloader)
## Description
This is more or less a wrapper around [plexmedia-downloader](https://github.com/Daxiongmao87/plexmedia-downloader), originally authored by [codedninja](https://github.com/codedninja/plexmedia-downloader).

This, however, is __specifically designed as a synchronization tool for plex libraries__.  This will only download whole libraries, and monitor at a user-specified interval.

## Example docker-compose

```yaml
---
version: "2.1"
services:
  plex-media-downloader:
    image: daxiongmao87/plex-library-synchronizer:latest
    container_name: plex-library-synchronizer
    environment:
      - PLS_TOKEN=aAbBcCdDeEfF
      - PLS_LIBRARIES=Shows,Movies
      - PLS_OUTPUTS=/media/shows,/media/movies
      - PLS_INTERVAL=60m
      - PLS_URL=https://127-0-0-1.a1b2c3d4e5f.plex.direct:32400 
    volumes:
      - /mnt/plex/media:/media
    restart: unless-stopped
```

## Environment Variables
| Environment Variable | Details                                                                                                                                                                                                                            |
|----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| PLS_TOKEN            | This is your X-Plex-Token.  This can be found via [this article](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/)                                                                         |
| PLS_LIBRARIES        | This is a list of libraries from the target plex server you wish to download.  Comma delimited                                                                                                                                     |
| PLS_OUTPUTS          | This is a list of output directories your libraries will be downloaded to.  Comma delimited, must match library order                                                                                                              |
| PLS_INTERVAL         | This is the interval between syncs/downloads.  Use [Linux's sleep format](https://man7.org/linux/man-pages/man1/sleep.1.html).  Examples: 30s, 5m, 2h, 1d -- where s is seconds, m is minutes, h is hours, and d is days.                                                                                                                                                                                  |
| PLS_URL              | This is the **plex.direct** url to the target plex server.  This can be found on the [same address bar used to locate your X-Plex-Token](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/) |
