FROM rakudo-star:2024.04

RUN apt-get update
RUN apt-get install -y curl git

COPY archiver   /srv/
COPY files      /srv/files/
COPY entrypoint /srv/

RUN git config --global --add safe.directory /srv/repo

RUN chmod +x /srv/entrypoint

WORKDIR /srv
ENTRYPOINT ["/srv/entrypoint"]
