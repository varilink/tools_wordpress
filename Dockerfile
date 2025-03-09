ARG WORDPRESS_TAG
FROM wordpress:${WORDPRESS_TAG}
LABEL maintainer="david.williamson@varilink.co.uk"

RUN                                                                            \
  apt-get update                                                            && \
  apt-get --no-install-recommends --yes install                                \
    ghostscript                                                             && \
  rm -rf /var/lib/apt/lists/*                                               && \
  sed -i 's/\
^\(  <policy domain="coder" rights="\)none\(" pattern="PDF" \/>\)$/\
\1read|write\2/' /etc/ImageMagick-6/policy.xml
