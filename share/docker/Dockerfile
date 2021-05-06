FROM perl:latest
WORKDIR /srv/[d2% appname %2d]
COPY . .
RUN cpanm --installdeps --notest --with-feature=accelerate .
EXPOSE 4000
CMD plackup -p 4000 bin/app.psgi
