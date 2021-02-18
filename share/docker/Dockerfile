FROM perl:latest
WORKDIR /srv/[d2% appname %2d]
COPY . .
RUN cpanm --installdeps --notest --with-feature=accelerate .
EXPOSE 5000
CMD plackup bin/app.psgi
