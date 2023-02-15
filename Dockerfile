FROM minamijoyo/tfupdate:0.6.5

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
