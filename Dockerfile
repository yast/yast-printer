FROM registry.opensuse.org/yast/head/containers/yast-ruby:latest
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  xorg-x11-libX11-devel

COPY . /usr/src/app

