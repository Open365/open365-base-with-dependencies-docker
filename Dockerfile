FROM    docker-registry.eyeosbcn.com/open365-base

## Install open365-services
COPY    package.json /root/
RUN     apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            cups \
            cups-pdf \
            davfs2 \
            vim \
            build-essential \
            sudo \
            pyqt5-dev-tools && \
        mkdir -p /code && cd /code && \
        git clone https://github.com/Open365/open365-services.git && \
        cd /code/open365-services && npm install && \
        cd /root && npm install && \
        npm install -g json && \
        /code/open365-services/install.sh && \
        ln -s /usr/bin/env /bin/env && \
        apt-get purge -y build-essential

# locale generation
RUN locale-gen en_US.UTF-8 es_ES.UTF-8

# General stuff
COPY    start.js /root/
COPY    run.sh /root/
COPY    exec.sh /usr/bin/exec.sh
COPY    cups /etc/cups
COPY    system_clipboard.py /usr/bin/system_clipboard.py
COPY    office_clipboard.py /usr/bin/office_clipboard.py
COPY    davfs2.conf /etc/davfs2/davfs2.conf
COPY    bind-mount-libraries /root/

VOLUME  ["/home"]
EXPOSE  5900
CMD     ["node", "/root/start.js"]
