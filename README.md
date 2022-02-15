microconf is a simple tool for building simple configure scripts.


Example
=======

A really simple configure script for microconf could look like this:

```
#!/bin/bash
#
# microconf:begin
# require shlib
# require ppoll
# require libsystemd
# require libselinux
# microconf:end

. microconf/prepare

##################################################################
# Get version from RELEASE file
##################################################################
uc_define_version my_version

##################################################################
# Now run all the checks we've lined up
##################################################################
. microconf/check

##################################################################
# Perform substitution steps
##################################################################
. microconf/subst

##################################################################
# Generate Make.defs from Make.defs.in
##################################################################
uc_subst Make.defs
```

In addition, you need a file called `RELEASE` in your source directory,
containing the version of your project as `VERSION = 1.2.3`.

With this in place, you can invoke microconf:

```
$ microconf
```

This will create the `microconf` subdirectory in your source
directory, and you're all set. Note that from this point on,
microconf is completely self-contained. You could ship the configure
script plus the microconf subdirectory, and your users will be able
to run configure without having the install the microconf package
at all.


Invoking microconf
==================

The configure script your wrote supports a variety of command line
options. Some are always active; some are added by the components
your script requires.

These are the default options supported:

* `--help`: display help message and exit
* `--prefix=/PATH`: works like the autoconf --prefix option, in that it specifies the default prefix directory for standard installation directories
* `--libdir=PATH`: installation location for architecture-independent lib files (default `$prefix/lib`)
* `--arch-libdir=PATH`: installation location for architecture dependent lib file. The(default depends on architecture and OS vendor, usually `$prefix/lib64` or `$prefix/lib`
* `--bindir=PATH`: installation location for executables and scripts (default `$prefix/bin`)
* `--etcdir=PATH`: installation location for executables and scripts (default `$prefix/etc`)
* `--mandir=PATH`: installation location for executables and scripts (default `$prefix/share/man`)
* `--with-platform=NAME`: override platform detection (see below)
* `--enable-manpages`, `--disable-manpages`: Do/Do not install manual pages. See below on how to handle these options in a makefile. Default is "enabled" on most platforms.

In addition, many modules provide one or more command line option that let you control their behavior. If in doubt, check the list of
available command line options with `--help`.


Handling of manpages
--------------------

The manpage feature hinted at above lets the user control whether to install any manpages that come with your package,
or not. This is what the `--enable-manpages` option is for. One rather simple way of handling this conditional
in a Makefile is like this:

```
INSTALL = install-stuff
ifeq (@INSTALL_MANPAGES@,true)
  INSTALL += install-man
endif

install: $(INSTALL)

install-man::
	: do whatever it takes to install your manpages
```

Substituing files
-----------------

As you can see in the configure example above, the last action to perform is to
massage at least one .in file using the `uc_subst` function. You can invoke this
function with one or more file names. For each of these, the function tries to
convert _filename_`.in` to _filename_.

If you have a need to process .in files at a later time (eg because they do not
exist at the time a user typically runs configure), you can do so too. Simply
run the `microconf/subst` with the name of the file to be generated:

```
install-man: foobar.1
	: ...

%.1: %.1.in
	../microconf/subst $@
```

Mode of Operation
=================

Microconf is fashionably modular, and unlike with autoconf, there's
not a lot of magic you can do in the configure script itself.

A microconf "module" is a set of configuration checks, possibly with
command line options that control the behavior of the check.
The `require` statements at the top of the script tell microconf
which modules to enable. 

Each module, when successful, sets a bunch of shell variables that
start with the prefix `uc_`. At the end of the configure script, these
variables are collected into an sed script, which can then be used
to create test files from .in files.

When creating the sed script, the `uc_` prefix is removed from the
variable name, which is then converted to upper case, and enclosed
in a pair of `@` characters. In other words, the value
`uc_my_version` can be referenced as `@MY_VERSION@` in any .in file.

Writing Make.defs.in
====================

In order to use the values microconf detected, you need to create
input files for Makefiles and/or config.h, which then get transformed
with sed.

A typical Makefile.in for the example configure script shown about
could look like this:

```
VERSION = @MY_VERSION@
LIBDIR  = @ARCH_LIBDIR@
BINDIR  = @BINDIR@
INCDIR  = @INCLUDEDIR@
MANDIR  = @MANDIR@
ETCDIR  = @ETCDIR@

WITH_LIBSYSTEMD ?= @WITH_LIBSYSTEMD@
LIBSYSTEMD_CFLAGS = @LIBSYSTEMD_CFLAGS@
LIBSYSTEMD_LIBS  = @LIBSYSTEMD_LIBS@

WITH_LIBSELINUX ?= @WITH_LIBSELINUX@
LIBSELINUX_CFLAGS = @LIBSELINUX_CFLAGS@
LIBSELINUX_LIBS  = @LIBSELINUX_LIBS@
```

The variables defined in this way can then be used in make rules.

Creating a `config.h` file is similar, but slightly different. For example,
given the check for `ppoll` in the example above, you probably want to use
a compile time conditional `HAVE_PPOLL` in your code. To support this use
case, microconf checks that output a true/false value will also define
a variable named `DEFINE_HAVE_$FEATURE` that takes a value `define` or
`undef`, respectively. In our example, the `config.h.in` file might look
like this:

```
#@DEFINE_HAVE_PPOLL@              HAVE_PPOLL
#@DEFINE_HAVE_LIBSELINUX@         HAVE_SELINUX
#define MY_VERSION                "@MY_VERSION@"
#define MY_VERSION_MAJOR          @MY_VERSION_MAJOR@
#define MY_VERSION_MINOR          @MY_VERSION_MINOR@
```


Available Modules
=================

platform
--------

Tries to detect the OS platform, and set `uc_platform`. Platform strings
currently supported:

* linux
* macos
* freebsd

The check also tries to detect the OS vendor, and stores this value in
`uc_os_vendor`. Currently supported values:

* apple
* debian
* fedora
* redhat
* suse
* ubuntu

This module is run by default.

shlib
-----
This module tries to detect the proper extension for shared libraries
(without a dot), and stores it in `uc_shlib_extension`.
For example, on a Linux system, it would set `uc_shlib_extension=so`.

ppoll
-----
This is a classic C compile check that checks for the presence of the
`ppoll` function in libc. It sets the variables `uc_with_ppoll` to
either `true` or `false`, and sets `uc_define_have_ppoll` to either
`define` or `undef`.

This check uses the internal function `uc_try_link`, which tries
to compile and link the provided C code snippet, and sets the above
mentioned variables according to the result.

pkg-config
----------
This checks for the presence of the pkg-config command. If present,
it will set `uc_with_pkg_config` to `yes`; otherwise to `no`.

This module also provides functions for other modules that allow them
to check for packages that provide build information via pkg-config.

The main entry point for other checks is the function `uc_pkg_config_check_package`.
It should be invoked with the name of the package to be inspected.

If the package is not found, it will set `uc_with_${pkgname}=none`,
and `uc_define_have_${pkgname}=undef`

If several versions of the desired package are present, it tries
to find the one with the highest version number, and sets
`uc_with_${pkgname}` to the version number found, and sets
`uc_define_have_${pkgname}=define`

In addition, it will set the following variables from the corresponding
variable setting found in the pkg-config file:

* `uc_${pkgname}_libdir`: contains the libdir setting
* `uc_${pkgname}_incdir`: contains the includedir setting
* `uc_${pkgname}_libs`: contains the libs setting
* `uc_${pkgname}_cflags`: contains the cflags setting

libsystemd
----------
This check is based on pkg-config. It looks for an installed version
of libsystemd. As described above, it will set these variables:

* `uc_with_libsystemd` (version found, or `none`)
* `uc_define_have_libsystemd` (`undef` or `define`)
* `uc_libsystemd_libdir`
* `uc_libsystemd_incdir`
* `uc_libsystemd_libs`
* `uc_libsystemd_cflags`

Using this module also defines two command line options:

* `--without-libsystemd`: do not check for the package, pretend it was not found
* `--with-libsystemd=VERSION`: force a specific version of the package

libselinux
----------
This check is based on pkg-config. It looks for an installed version
of libselinux. As described above, it will set these variables:

* `uc_with_libselinux` (version found, or `none`)
* `uc_define_have_libselinux` (`undef` or `define`)
* `uc_libselinux_libdir`
* `uc_libselinux_incdir`
* `uc_libselinux_libs`
* `uc_libselinux_cflags`

Using this module also defines two command line options:

* `--without-libselinux`: do not check for the package, pretend it was not found
* `--with-libselinux=VERSION`: force a specific version of the package

libaudit
--------
This check is based on pkg-config. It looks for an installed version
of libaudit. As described above, it will set these variables:

* `uc_with_libaudit` (version found, or `none`)
* `uc_define_have_libaudit` (`undef` or `define`)
* `uc_libaudit_libdir`
* `uc_libaudit_incdir`
* `uc_libaudit_libs`
* `uc_libaudit_cflags`

Using this module also defines two command line options:

* `--without-libaudit`: do not check for the package, pretend it was not found
* `--with-libaudit=VERSION`: force a specific version of the package

python3
-------

This check tries to detect the version and configuration of python3.
It outputs the same values as other pkg-config based tests, plus
`uc_python_interp_path` and `uc_python_package_dir`:

* `uc_with_python` (version found, or `none`)
* `uc_define_have_python` (`undef` or `define`)
* `uc_python_libdir`
* `uc_python_incdir`
* `uc_python_libs`
* `uc_python_cflags`
* `uc_python_interp_path`: location of the python interpreter
* `uc_python_package_dir`: location of the corresponding package directory
