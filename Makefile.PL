use ExtUtils::MakeMaker;
use Config;

my @libs = ();
push @libs,'-lresolv' unless $Config{d_inetaton};

WriteMakefile(
    'NAME'	=> 'IO::Interface',
    'VERSION_FROM' => 'Interface.pm', # finds $VERSION
    'LIBS'	=> ["@libs"],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> '',     # e.g., '-I/usr/include/other' 
);
