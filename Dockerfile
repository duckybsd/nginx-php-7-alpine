FROM wodby/nginx-alpine
MAINTAINER Wodby <hello@wodby.com>

RUN export PHP_ACTIONS_VER="master" && \
    export UPLOADPROGRESS_VER="0.1.0" && \
    export XDEBUG_VER="2.4.0" && \
    export WALTER_VER="1.3.0" && \
    export GO_AWS_S3_VER="v1.0.0" && \

    echo 'http://alpine.gliderlabs.com/alpine/edge/main' > /etc/apk/repositories && \
    echo 'http://alpine.gliderlabs.com/alpine/edge/community' >> /etc/apk/repositories && \
    echo 'http://alpine.gliderlabs.com/alpine/edge/testing' >> /etc/apk/repositories && \

    # Install common packages
    apk add --update \
        openssh \
        git \
        nano \
        grep \
        pcre \
        perl \
        patch \
        patchutils \
        diffutils \
        && \

    # Add PHP actions
    cd /tmp && \
    git clone https://github.com/Wodby/php-actions-alpine.git && \
    cd php-actions-alpine && \
    git checkout $PHP_ACTIONS_VER && \
    rsync -av rootfs/ / && \

    # Install specific packages
    apk add --update \
        mariadb-client \
        imap \
        redis \
        imagemagick \
        && \

    # Install PHP packages
    apk add --update \
        php7 \
        php7-fpm \
        php7-opcache \
        php7-apcu \
        php7-session \
        php7-xml \
        php7-ctype \
        php7-ftp \
        php7-gd \
        php7-json \
        php7-posix \
        php7-curl \
        php7-dom \
        php7-pdo \
        php7-pdo_mysql \
        php7-sockets \
        php7-zlib \
        php7-mcrypt \
        php7-mysqli \
        php7-sqlite3 \
        php7-bz2 \
        php7-phar \
        php7-openssl \
        php7-posix \
        php7-zip \
        php7-calendar \
        php7-iconv \
        php7-imap \
        php7-soap \
        php7-dev \
        php7-pear \
        php7-redis \
        php7-mbstring \
        php7-xdebug \
        php7-exif \
        php7-xsl \
        php7-ldap \
        php7-bcmath \
        && \

    # Create symlinks PHP -> PHP7
    ln -sf /usr/bin/php7 /usr/bin/php && \
    ln -sf /usr/sbin/php-fpm7 /usr/bin/php-fpm && \

    # Configure php.ini
    sed -i \
        -e "s/^expose_php.*/expose_php = Off/" \
        -e "s/^;date.timezone.*/date.timezone = UTC/" \
        -e "s/^memory_limit.*/memory_limit = -1/" \
        -e "s/^max_execution_time.*/max_execution_time = 300/" \
        -e "s/^post_max_size.*/post_max_size = 512M/" \
        -e "s/^upload_max_filesize.*/upload_max_filesize = 512M/" \
        -e "s@^;sendmail_path.*@sendmail_path = /usr/sbin/sendmail -t -i -S opensmtpd:25@" \
        /etc/php7/php.ini && \

    echo "error_log = \"/var/log/php/error.log\"" | tee -a /etc/php7/php.ini && \

    # Configure php log dir
    rm -rf /var/log/php7 && \
    mkdir /var/log/php && \
    touch /var/log/php/error.log && \
    touch /var/log/php/fpm-error.log && \
    touch /var/log/php/fpm-slow.log && \
    chown -R wodby:wodby /var/log/php && \

    # Install uploadprogess extension
    apk add --update build-base autoconf libtool pcre-dev && \
    wget -qO- https://s3.amazonaws.com/wodby-releases/uploadprogress/v${UPLOADPROGRESS_VER}/php7-uploadprogress.tar.gz | tar xz -C /tmp/ && \
    cd /tmp/uploadprogress-${UPLOADPROGRESS_VER} && \
    phpize7 && \
    ./configure --with-php-config=/usr/bin/php-config7 && \
    make && \
    make install && \
    echo 'extension=uploadprogress.so' > /etc/php7/conf.d/uploadprogress.ini && \

    # Define Git global config
    git config --global user.name "Administrator" && \
    git config --global user.email "admin@wodby.com" && \
    git config --global push.default current && \

    # Disable Xdebug
    rm /etc/php7/conf.d/xdebug.ini && \

    # Install composer
    curl -sS https://getcomposer.org/installer | php7 -- --install-dir=/usr/local/bin --filename=composer && \

    # Add composer parallel install plugin
    composer global require "hirak/prestissimo:^0.3" && \

    # Install drush
    php -r "readfile('https://s3.amazonaws.com/files.drush.org/drush.phar');" > /usr/local/bin/drush && \
    chmod +x /usr/local/bin/drush && \

    # Install Drupal Console
    curl https://drupalconsole.com/installer -o /usr/local/bin/drupal && \
    chmod +x /usr/local/bin/drupal && \

    # Install wp-cli
    composer create-project wp-cli/wp-cli /usr/local/src/wp-cli --no-dev && \
    ln -sf /usr/local/src/wp-cli/bin/wp /usr/bin/wp && \

    # Install Walter tool
    wget -qO- https://s3.amazonaws.com/wodby-releases/walter-cd/v${WALTER_VER}/walter.tar.gz | tar xz -C /tmp/ && \
    mkdir -p /opt/wodby/bin && \
    cp /tmp/walter_linux_amd64/walter /opt/wodby/bin && \

    # Install Wellington tool
    wget -qO- https://s3.amazonaws.com/wodby-releases/wt/1.0.2/wt_v1.0.2_linux_amd64.tar.gz | tar xz -C /tmp/ && \
    cp /tmp/wt /opt/wodby/bin && \

    # Install go-aws-s3
    wget -qO- https://s3.amazonaws.com/wodby-releases/go-aws-s3/${GO_AWS_S3_VER}/go-aws-s3.tar.gz | tar xz -C /tmp/ && \
    cp /tmp/go-aws-s3 /opt/wodby/bin && \

    # Fix permissions
    chmod 755 /root && \

    # Remove redis binaries and config
    ls /usr/bin/redis-* | grep -v redis-cli | xargs rm  && \
    rm -f /etc/redis.conf && \

    # Cleanup
    apk del --purge \
        *-dev \
        build-base \
        autoconf \
        libtool \
        && \

    rm -rf \
        /usr/include/php7 \
        /usr/lib/php7/build \
        /usr/lib/php7/modules/*.a \
        /var/cache/apk/* \
        /usr/share/man \
        /tmp/* \
        /root/.composer

COPY rootfs /
