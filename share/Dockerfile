FROM perl
WORKDIR /srv/[d2% appname %2d]
COPY . .
RUN cpanm --installdeps --notest .
EXPOSE 5000
CMD plackup bin/app.psgi
