FROM ubuntu:jammy

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]
ENV LANG C.UTF-8
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    dirmngr \
    fonts-noto-cjk \
    gnupg \
    libpq-dev \
    libssl-dev \
    node-less \
    npm \
    python3-cffi \
    python3-dev \
    python3-magic \
    python3-num2words \
    python3-odf \
    python3-pdfminer \
    python3-phonenumbers \
    python3-pip \
    python3-pyldap \
    python3-qrcode \
    python3-renderpm \
    python3-setuptools \
    python3-slugify \
    python3-vobject \
    python3-watchdog \
    python3-xlrd \
    python3-xlwt \
    unzip \
    xz-utils


RUN curl -o /tmp/odoo.zip -sSL https://github.com/odoo/odoo/archive/0b72568bc37a8450277e4fa1ded3b88ddf5266a4.zip && \
    unzip /tmp/odoo.zip -d /tmp/odoo/ && \
    mv /tmp/odoo/odoo-0b72568bc37a8450277e4fa1ded3b88ddf5266a4 /opt/odoo && \
    rm -rf /tmp/odoo.zip /tmp/odoo

RUN sed -i '/python-ldap/d' /opt/odoo/requirements.txt && \
    pip3 install --no-cache-dir -r /opt/odoo/requirements.txt
RUN useradd -ms /bin/bash odoo

EXPOSE 8069
USER odoo
WORKDIR /opt/odoo