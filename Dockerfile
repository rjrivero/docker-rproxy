FROM nginx:stable

# Add tini
ENV TINI_VERSION v0.9.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]

# Static content (document root)
VOLUME /opt/www
# Additional proxy rules
VOLUME /etc/nginx/proxy.d

# Add config files and scripts
ADD files/run.sh       /
ADD files/default.conf /etc/nginx/conf.d/

# Expose nginx port
EXPOSE 8080

# Run server
CMD ["/run.sh"]
