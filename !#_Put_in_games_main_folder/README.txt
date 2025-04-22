Because L4D2 uses [really] outdated versions
of the 'libgcc_s.so.1' and 'libgcc_s.so.6' libraries,
there are issues loading extensions/plugins that are not
statically compiled with these libraries
(like addons/sourcemod/extensions/cleaner.ext.so).

They require either removing these libraries from 'Left4Dead2/bin/'
(to use OS-provided versions), or to override them by
putting newer versions in 'Left4Dead2/'
(the main game's folder where are also srcds_* files),
or just create symlinks to OS-provided versions.

These are versions from the Rocky Linux 8.8 as of 22 April 2025.
They work fine also with Debian 10.

libgcc_s.so.1 : MD5 a06317cc44bd7e93fb8af1f302b6aa1a
libstdc++.so.6 : MD5 88d7d67fdfa466aa7f319eef370a2234
