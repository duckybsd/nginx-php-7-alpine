FROM wodby/nginx-alpine
MAINTAINER Wodby <hello@wodby.com>

RUN export PHP_ACTIONS_VER="master" && \
    export UPLOADPROGRESS_VER="0.1.0" && \
    export XDEBUG_VER="2.4.0" && \
    export WALTER_VER="1.3.0" && \
    export GO_AWS_S3_VER="v1.0.0" && \

    echo '@testing http://nl.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories && \
    echo '@community http://nl.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories && \

    # Install common packages
    apk add --update \
        git \
        nano \
        grep \
        sed \
        curl \
        wget \
        tar \
        gzip \
        pcre \
        perl \
        openssh \
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
        php7@community \
        php7-fpm@community \
        php7-opcache@community \
        php7-session@community \
        php7-xml@community \
        php7-ctype@community \
        php7-ftp@community \
        php7-gd@community \
        php7-json@community \
        php7-posix@community \
        php7-curl@community \
        php7-dom@community \
        php7-pdo@community \
        php7-pdo_mysql@community \
        php7-sockets@community \
        php7-zlib@community \
        php7-mcrypt@community \
        php7-mysqli@community \
        php7-sqlite3@community \
        php7-bz2@community \
        php7-phar@community \
        php7-openssl@community \
        php7-posix@community \
        php7-zip@community \
        php7-calendar@community \
        php7-iconv@community \
        php7-imap@community \
        php7-soap@community \
        php7-dev@community \
        php7-pear@community \
        php7-redis@testing \
        php7-mbstring@community \
        php7-xdebug@testing \
        php7-exif@community \
        php7-xsl@community \
        php7-ldap@community \
        php7-bcmath@community \
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

    # Purge dev APK packages
    apk del --purge *-dev build-base autoconf libtool && \

    # Cleanup after phpizing
    rm -rf /usr/include/php7 /usr/lib/php7/build /usr/lib/php7/modules/*.a && \

    # Remove redis binaries and config
    ls /usr/bin/redis-* | grep -v redis-cli | xargs rm  && \
    rm -f /etc/redis.conf && \

    # Define Git global config
    git config --global user.name "Administrator" && \
    git config --global user.email "admin@wodby.com" && \
    git config --global push.default current && \

    # Install composer
    curl -sS https://getcomposer.org/installer | php7 -- --install-dir=/usr/local/bin --filename=composer && \

    # Add composer parallel install plugin
    composer global require "hirak/prestissimo:^0.3" && \

    # Install drush
    git clone https://github.com/drush-ops/drush.git /usr/local/src/drush && \
    cd /usr/local/src/drush && \
    ln -sf /usr/local/src/drush/drush /usr/bin/drush && \
    composer install && rm -rf ./.git && \

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

    # Final cleanup
    rm -rf /var/cache/apk/* /tmp/* /usr/share/man

COPY rootfs /
