# Personal BC250 image: stock Bazzite (daily updates) + BC250 bits baked in.
# Base = the exact stock image you started on. Swap the tag if you ever change desktop.
FROM ghcr.io/ublue-os/bazzite-deck-gnome:stable

# Copy build script and run it, then finalize the ostree container.
COPY build_files /tmp/build_files
RUN chmod +x /tmp/build_files/build.sh \
 && /tmp/build_files/build.sh \
 && ostree container commit
