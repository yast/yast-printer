FROM yastdevel/cpp
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  xorg-x11-libX11-devel \
  yast2 \
  yast2-testsuite

COPY . /usr/src/app

