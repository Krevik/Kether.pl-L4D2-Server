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

These are versions from the Rocky Linux 8 as of 29 May 2024.
They work fine also with Debian 10.

libgcc_s.so.1 : MD5 04cd2861576e3eee3ec0828e7f8ecb0b
libstdc++.so.6 : MD5 fb319382562423be93c1b94ac03128e3