FROM swipl:stable

# Hugging Face Spaces runs as user ID 1000
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR $HOME/app

COPY --chown=user . $HOME/app

# Hugging Face Spaces listens on port 7860
ENV PORT=7860
EXPOSE 7860

CMD ["swipl", "server.pl"]

