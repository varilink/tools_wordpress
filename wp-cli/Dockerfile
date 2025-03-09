# ------------------------------------------------------------------------------
# wp-cli/Dockerfile
# ------------------------------------------------------------------------------

# Implements the WP-CLI command line interface for WordPress within the Varilink
# wordpress tool.

# Note that we don't start with the cli image from wordpress on Docker Hub. It
# is based on BusyBox and I need more shell command capability than that.
ARG PHP_TAG
FROM php:${PHP_TAG}
LABEL maintainer="david.williamson@varilink.co.uk"
# The default UID for the posts user. We use this user when we run wp-cli to
# export posts back to the Docker host so we set it to the UID of the user on
# the host that runs this image. Otherwise we run wp-cli as www-data, since this
# is the user that owns the WordPress files within the container.
ARG UID=1000
ARG PHAR=https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar
ARG PHAR=${PHAR}/wp-cli.phar

RUN                                                                            \
  apt-get update                                                            && \
  apt-get --no-install-recommends --yes install                                \
    ca-certificates                                                            \
    ghostscript                                                                \
    gosu                                                                       \
    gzip                                                                       \
    jq                                                                         \
    less                                                                       \
    libmagickwand-dev                                                          \
    libpng-dev                                                                 \
    mariadb-client                                                             \
    tar                                                                        \
    wget                                                                       \
    zlib1g-dev                                                              && \
  docker-php-ext-install gd mysqli                                          && \
  pecl install imagick                                                      && \
  docker-php-ext-enable imagick                                             && \
  sed -i 's/\
^\(  <policy domain="coder" rights="\)none\(" pattern="PDF" \/>\)$/\
\1read|write\2/' /etc/ImageMagick-6/policy.xml                              && \
  mkdir -p /var/www/.wp-cli                                                 && \
  chown www-data:www-data /var/www/.wp-cli                                  && \
  useradd --create-home --uid ${UID} host_user                              && \
  wget --output-document=/usr/local/bin/wp ${PHAR}                          && \
  chmod +x /usr/local/bin/wp

COPY --chown=www-data:www-data config.yml /var/www/.wp-cli/
COPY docker-entrypoint.sh /

ENTRYPOINT ["bash", "/docker-entrypoint.sh"]
# If no command is supplied then by default just display the wp-cli help.
CMD ["--help"]

# Set the working directory to the path of the WordPress installation. That way
# whenever we run wp-cli we won't have to provide the --path option.
WORKDIR /var/www/html
