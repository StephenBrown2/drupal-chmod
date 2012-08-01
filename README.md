drupal-chmod
============

A script to recursively set the proper permissions in a Drupal DocumentRoot

Purpose
-------

The purpose of this script is to fix permissions for an entire Drupal directory structure,
so that it can be served by Apache and still be fairly secure.

The perl script gives three options for the level of security you wish to use, while the
shell script only uses one set of permissions. Executing drupal_chmod.pl -h will give you
all the options and general use cases for the script.

The three options for permissions are 'tight', 'medium', and 'loose',
and the script defaults to medium settings.

Basis
-----

The perl script included is based off the shell script, which was taken from this Drupal.org page:
[Securing file permissions and ownership](http://drupal.org/node/244924). The other options for levels of permission
were gleaned from the many helpful (and some not-so helpful) comments there, so it should be
accurate and easy to use.
