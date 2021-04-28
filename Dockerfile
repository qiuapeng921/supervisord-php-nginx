FROM php:7.3-fpm-alpine

LABEL Maintainer="qiuapeng@vchangyi.com"

ENV XLSWRITER_VERSION=1.3.7

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && mkdir -p /run/nginx

# update
RUN set -ex \
    && apk update \
    && apk add --no-cache libstdc++ wget openssl bash supervisor nginx \
        libmcrypt-dev libzip-dev libpng-dev libc-dev zlib-dev librdkafka-dev

RUN apk add --no-cache --virtual .build-deps autoconf automake make g++ gcc \
    libtool dpkg-dev dpkg pkgconf file re2c pcre-dev php7-dev php7-pear openssl-dev \
    freetype freetype-dev libjpeg-turbo libjpeg-turbo-dev libpng libpng-dev \

    && docker-php-ext-configure gd --with-gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/ \

    # 安装php常用扩展
    && docker-php-ext-install -j${NPROC} gd bcmath opcache mysqli pdo pdo_mysql sockets zip \

    # Extension redis mcrypt mongodb rdkafka
    && pecl install redis mcrypt mongodb rdkafka \
    && docker-php-ext-enable redis mcrypt mongodb rdkafka \

    # 安装 Composer
    && wget https://mirrors.cloud.tencent.com/composer/composer.phar \
    && mv composer.phar  /usr/local/bin/composer \
    && chmod +x /usr/local/bin/composer \
    && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/ \

    # 安装 Xlswriter
    && wget http://pecl.php.net/get/xlswriter-${XLSWRITER_VERSION}.tgz -O xlswriter.tar.gz \
    && mkdir -p xlswriter \
    && tar -xf xlswriter.tar.gz -C xlswriter --strip-components=1 \
    && rm xlswriter.tar.gz \
    && cd xlswriter \
    && phpize && ./configure --enable-reader && make && make install \
    && docker-php-ext-enable xlswriter \

    # 删除系统扩展
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* /tmp/* /usr/share/man \
    && php -m

RUN wget https://wesociastg.blob.core.chinacloudapi.cn/wesocial-uat/gocron-node-v1.5.3-linux-amd64.tar.gz \
    && tar -zxvf gocron-node-v1.5.3-linux-amd64.tar.gz && rm -rf gocron-node-v1.5.3-linux-amd64.tar.gz \
    && mv gocron-node-linux-amd64/gocron-node /usr/bin/gocron-node && rm -rf gocron-linux-amd64

COPY entrypoint.sh /root/

RUN chmod +x /root/entrypoint.sh

COPY config/supervisord/supervisord.conf /etc/supervisord.conf
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY config/php/php-fpm.conf /usr/local/etc/php-fpm.conf
ADD index.php /usr/share/nginx/html/src/public/

EXPOSE 80 5921

CMD ["supervisord","-c","/etc/supervisord.conf"]