#!/usr/bin/perl

## Set operating parameters
use warnings;
use strict;

## Set modules used
use Getopt::Long;
use File::Find;

## Set variables
my $path;
my $user;
my $group = getgrnam('www-data') ? 'www-data' : getgrnam('apache') ? 'apache' : undef;
my $uid;
my $gid;
my $permset;
my $showperms = '';
my %perms = (
    'tight' => {
        'ddir' => '0750', # Drupal Root dirs
        'dfile' => '0640', # Drupal Root files
        'sitesd' => '0750', # Directories in 'sites' dir (e.g. 'all', 'default', 'site.url')
        'filesd' => '0770', # 'files' dirs and dirs in 'files'
        'filesf' => '0660', # files in 'files' dirs 
        'special' => {
            'settings.php' => '0440',
            '.htaccess' => '0440',
        },
    },
    'medium' => {
        'ddir' => '0755',
        'dfile' => '0644',
        'sitesd' => '0755',
        'filesd' => '0775',
        'filesf' => '0664',
        'special' => {
            'settings.php' => '0444',
            '.htaccess' => '0444',
        },
    },
    'loose' => {
        'ddir' => '0775',
        'dfile' => '0664',
        'sitesd' => '0777',
        'filesd' => '0777',
        'filesf' => '0666',
        'special' => {
            'settings.php' => '0666',
            '.htaccess' => '0666',
        },
    },
);
my $permoptions = join(', ', keys %perms);
my $help = "\nHelp: This script is used to fix permissions of a drupal installation
you need to provide the following arguments:
    1) Path to your drupal installation
    2) Username of the user that you want to give files/directories ownership
    3) Permission set to use. Can be 'tight', 'medium', or 'loose'.
Note: \"$group\" is assumed as the group the server is belonging to.
      If this is different you need to specify it manually with '-g' or '--group'.\n";
my $usage = "\nUsage:\n (sudo) (perl) $0 (-p|--path) <drupal_path> (-u|--user) <user_name> (-s|--permset) <permission_set>\n
$0 [OPTIONS]
  -p, --path         The path to the drupal root directory (REQUIRED)
  -u, --user         The user to give ownership to for the entire tree (REQUIRED)
  -g, --group        The group to give ownership to for the entire tree (OPTIONAL)
  -s, --permset,     The permission set to apply to files and folders in the tree.
      --permissions    Options are: $permoptions (REQUIRED)\n
  -d, --display      Display the permission set to be applied. Can also be used
                     without an option, in conjunction with '-s', as '-s tight -d'
  -h, --help         Display this help and usage message.\n";


## Parse the commandline
GetOptions (
    'u|user=s' => \$user,
    'p|path=s' => \$path,
    'g|group=s' => \$group,
    's|permset|permissions=s' => \$permset,
    'd|display:s' => \$showperms,
    'h|help' => sub {print $help; print $usage; exit;},
);

if ($showperms && ($showperms ne '' || ($showperms eq '' && $permset && $permset ne '') ) ) {
    if ( grep { $_ eq $showperms } keys %perms ) {
        &show_permissions($showperms);
    } else {
        print "Please provide a valid permission set. Options are: $permoptions\n";
        print "To see what permissions will be set, use -d <permset> or --display <permset>\n";
        print $help;
        exit;
    }
}

if ( $path && ( ! -e "$path" ) || ( ! -d "${path}/sites" ) || ( ! -f "${path}/modules/system/system.module" ) ) {
    print "Please provide a valid drupal path\n";
    print $help;
    exit;
}

if ( $user && getpwnam $user ) {
    $uid = getpwnam($user);
} else {
    print "Please provide a valid user\n";
    print $help;
    exit;
}

if ( $group && getgrnam $group ) {
    $gid = getgrnam($group);
} elsif ($group) {
    print "Please provide a valid group\n";
    print $help;
    exit;
}

if ( !$permset || ( $permset && ! grep { $_ eq $permset } keys %perms ) ) {
    print "Please provide a valid permission set. Options are: $permoptions\n";
    print "To see what permissions will be set, use -d <permset> or --display <permset>\n";
    print $help;
    exit;
}

$path =~ s/\/?$//;
$path = File::Spec->rel2abs($path) if $path !~ /^\//;

sub show_permissions {
    my $set = shift;

    print "\nThese are the permissions that will be set using permset '$set'\n on folders and files in the specified Drupal Root directory:\n\n";
    print "Drupal Core folders and subfolders: $perms{$set}{'ddir'}\t\t(d", &rwx($perms{$set}{'ddir'}), ")\n";
    print "Drupal Core files and files in subfolders: $perms{$set}{'dfile'}\t\t(-", &rwx($perms{$set}{'dfile'}), ")\n";
    print "Folders in 'sites' dir (e.g. 'all', 'default'): $perms{$set}{'sitesd'}\t(d", &rwx($perms{$set}{'sitesd'}), ")\n";
    print "'files' Folders and subfolders: $perms{$set}{'filesd'}\t\t\t(d", &rwx($perms{$set}{'filesd'}), ")\n";
    print "Files in 'files' folder and it's subfolders: $perms{$set}{'filesf'}\t(-", &rwx($perms{$set}{'filesf'}), ")\n";
    print "\nSpecial files (e.g. 'settings.php' and '.htaccess'):\n";
    foreach my $f ( keys %{$perms{$set}{'special'}} ) {
        print "$f => $perms{$set}{'special'}{$f}\t\t\t\t\t( ", &rwx($perms{$set}{'special'}{$f}), ")\n";
    }
    print "\n";
    exit;
}

sub rwx {
    my $p = shift; # assumed to be a string
    my @permstring = qw(--- --x -w- -wx r-- r-x rw- rwx);
    $p = substr($p,1,3) if (length $p == 4);
    my $string = '';
    foreach my $str (split(//,$p)) {
        $string .= $permstring[$str];
    }
    return $string;
}
        

chdir "$path";

print "Changing ownership of all contents of \"$path\" :\n user => \"$user\" \t group => \"$group\"\n";
#chown -R ${user}:${group} .
find ( sub { chown($uid, $gid, $_) or die "Cannot chown $File::Find::name. Try using 'sudo $0'\n"; }, "$path" );

print "Changing permissions of all directories inside \"$path\" to \"$perms{$permset}{'ddir'}\"...\n";
#find . -type d -exec chmod u=rwx,g=rx,o= {} \;
find ( sub { -d && chmod(oct($perms{$permset}{'ddir'}), $_)
            or warn "Cannot chmod $File::Find::name: $!" unless -f; }, "$path");

print "Changing permissions of all files inside \"$path\" to \"$perms{$permset}{'dfile'}\"...\n";
#find . -type f -exec chmod u=rw,g=r,o= {} \;
find ( sub { -f && chmod(oct($perms{$permset}{'dfile'}), $_)
            or warn "Cannot chmod $File::Find::name: $!" unless -d; }, "$path");

chdir "$path/sites";

print "Changing permissions of directories in \"$path/sites\" to \"$perms{$permset}{'sitesd'}\"...\n";
find ( sub { -d && chmod(oct($perms{$permset}{'sitesd'}), $_)
            or warn "Cannot chmod $File::Find::name: $!" unless -f; }, "$path/sites");

print "Changing permissions of \"files\" directories in \"$path/sites\" to \"$perms{$permset}{'filesd'}\"...\n";
#find . -type d -name files -exec chmod ug=rwx,o= '{}' \;
find ( sub { -d && /^files$/ && chmod(oct($perms{$permset}{'filesd'}), $_)
            or warn "Cannot chmod $File::Find::name: $!" unless -f or !/^files/; }, "$path/sites");

print "Changing permissions of all files inside all \"files\" directories in \"$path/sites\" to \"$perms{$permset}{'filesf'}\"...\n";
#find . -type d -name files -exec find '{}' -type f \; | while read FILE; do chmod ug=rw,o= "$FILE"; done
find ( sub { -d && /^files/ && 
        find ( sub { -f && chmod(oct($perms{$permset}{'filesf'}), $_)
                    or warn "Cannot chmod $File::Find::name: $!" unless -d; }, $File::Find::name );
    }, "$path/sites" );

print "Changing permissions of all directories inside all \"files\" directories in \"$path/sites\" to \"$perms{$permset}{'filesd'}\"...\n";
#find . -type d -name files -exec find '{}' -type d \; | while read DIR; do chmod ug=rwx,o= "$DIR"; done
find ( sub { -d && /^files/ && 
        find ( sub { -d && chmod(oct($perms{$permset}{'filesd'}), $_)
                    or warn "Cannot chmod $File::Find::name: $!" unless -f; }, $File::Find::name );
    }, "$path/sites" );

print "Changing permissions of special files...\n";
foreach my $file ( keys %{$perms{$permset}{'special'}} ) {
    find ( sub { /^$file$/ && chmod(oct($perms{$permset}{'special'}{$file}), $_)
            && print "$File::Find::name => $perms{$permset}{'special'}{$file}\n"
                or warn "Cannot chmod $File::Find::name: $!" unless !/^$file$/; }, "$path");
}
