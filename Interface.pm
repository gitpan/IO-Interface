package IO::Interface;

require 5.005;
use strict;
use Carp;
use vars qw(@EXPORT @EXPORT_OK @ISA %EXPORT_TAGS $VERSION $AUTOLOAD);

require Exporter;
require DynaLoader;
use AutoLoader;

my @functions = qw(if_addr if_broadcast if_netmask if_dstaddr if_hwaddr if_flags if_list addr_to_interface);
my @flags     = qw(IFF_ALLMULTI    IFF_AUTOMEDIA  IFF_BROADCAST
		   IFF_DEBUG       IFF_LOOPBACK   IFF_MASTER
		   IFF_MULTICAST   IFF_NOARP      IFF_NOTRAILERS
		   IFF_POINTOPOINT IFF_PORTSEL    IFF_PROMISC
		   IFF_RUNNING     IFF_SLAVE      IFF_UP);
%EXPORT_TAGS = ( 'all'        => [@functions,@flags],
		 'functions'  => \@functions,
		 'flags'      => \@flags,
	       );

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

@EXPORT = qw( );

@ISA = qw(Exporter DynaLoader);
$VERSION = '0.97';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.  If a constant is not found then control is passed
    # to the AUTOLOAD in AutoLoader.

    my $constname;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&constant not defined" if $constname eq 'constant';
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {
	if ($! =~ /Invalid/ || $!{EINVAL}) {
	    $AutoLoader::AUTOLOAD = $AUTOLOAD;
	    goto &AutoLoader::AUTOLOAD;
	}
	else {
	    croak "Your vendor has not defined IO::Interface macro $constname";
	}
    }
    {
      no strict 'refs';
      *$AUTOLOAD = sub { $val };  # *$AUTOLOAD = sub() { $val }; 
    }
    goto &$AUTOLOAD;
}

bootstrap IO::Interface $VERSION;

# copy routines into IO::Socket
{ 
  no strict 'refs';
  *{"IO\:\:Socket\:\:$_"} = \&$_ foreach @functions;
}

# Preloaded methods go here.

sub if_list {
  my %hash = map {$_=>undef} &_if_list;
  sort keys %hash;
}

sub addr_to_interface {
  my ($sock,$addr) = @_;
  return "any" if $addr eq '0.0.0.0';
  my @interfaces = $sock->if_list;
  foreach (@interfaces) {
    return $_ if $sock->if_addr($_) eq $addr;
  }
  return;  # couldn't find it
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

IO::Interface - Perl extension for access to network card configuration information

=head1 SYNOPSIS

  use IO::Socket;
  use IO::Interface qw(:flags);

  my $s = IO::Socket::INET->new(Proto => 'udp');
  my @interfaces = $s->if_list;

  for my $f (@interfaces) {
    print "interface = $if\n";
    my $flags = $s->if_flags($if);
    print "addr =      ",$s->if_addr($if),"\n",
          "broadcast = ",$s->if_broadcast($if),"\n",
          "netmask =   ",$s->if_netmask($if),"\n",
          "dstaddr =   ",$s->if_dstaddr($if),"\n",
          "hwaddr =    ",$s->if_hwaddr($if),"\n";

    print "is running\n"     if $flags & IFF_RUNNING;
    print "is broadcast\n"   if $flags & IFF_BROADCAST;
    print "is p-to-p\n"      if $flags & IFF_POINTOPOINT;
    print "is loopback\n"    if $flags & IFF_LOOPBACK;
    print "is promiscuous\n" if $flags & IFF_PROMISC;
    print "is multicast\n"   if $flags & IFF_MULTICAST;
    print "is notrailers\n"  if $flags & IFF_NOTRAILERS;
    print "is noarp\n"       if $flags & IFF_NOARP;
  }
  
  my $interface = $s->addr_to_interface('127.0.0.1');


=head1 DESCRIPTION

IO::Interface adds methods to IO::Socket objects that allows them to
be used to retrieve and change information about the network
interfaces on your system.  In addition to the object-oriented access
methods, you can use a function-oriented style.

=head2 Creating a Socket to Access Interface Information

You must create a socket before you can access interface
information. The socket does not have to be connected to a remote
site, or even used for communication.  The simplest procedure is to
create a UDP protocol socket:

  my $s = IO::Socket::INET->new(Proto => 'udp');

The various IO::Interface functions will now be available as methods
on this socket.

=head2 Methods

=over 4

=item @iflist = $s->if_list

The if_list() method will return a list of active interface names, for
example "eth0" or "tu0".  If no interfaces are configured and running,
returns an empty list.

=item $addr = $s->if_addr($ifname [,$newaddr])

if_addr() gets or sets the interface address.  Call with the interface
name to retrieve the address (in dotted decimal format).  Call with a
new address to set the interface.  In the latter case, the routine
will return a true value if the operation was successful.

  my $oldaddr = $s->if_addr('eth0');
  $s->if_addr('eth0','192.168.8.10') || die "couldn't set address: $!";

Special case: the address of the pseudo-device "any" will return the
IP address "0.0.0.0", which corresponds to the INADDR_ANY constant.

=item $broadcast = $s->if_broadcast($ifname [,$newbroadcast]

Get or set the interface broadcast address.  If the interface does not
have a broadcast address, returns undef.

=item $mask = $s->if_netmask($ifname [,$newmask])

Get or set the interface netmask.

=item $dstaddr = $s->if_dstaddr($ifname [,$newdest])

Get or set the destination address for point-to-point interfaces.

=item $hwaddr = $s->if_hwaddr($ifname [,$newhwaddr])

Get or set the hardware address for the interface. Currently only
ethernet addresses in the form "00:60:2D:2D:51:70" are accepted.

=item $flags = $s->if_flags($ifname [,$newflags])

Get or set the flags for the interface.  The flags are a bitmask
formed from a series of constants.  See L<Exportable constants> below.

=item $ifname = $s->addr_to_interface($ifaddr)

Given an interface address in dotted form, returns the name of the
interface associated with it.  Special case: the INADDR_ANY address,
0.0.0.0 will return a pseudo-interface name of "any".

=back

=head2 EXPORT

IO::Interface exports nothing by default.  However, you can import the
following symbol groups into your namespace:

  :functions   Function-oriented interface (see below)
  :flags       Flag constants (see below)
  :all         All of the above

=head2 Function-Oriented Interface

By importing the ":functions" set, you can access IO::Interface in a
function-oriented manner.  This imports all the methods described
above into your namespace.  Example:

  use IO::Socket;
  use IO::Interface ':functions';

  my $sock = IO::Socket::INET->new(Proto=>'udp');
  my @interfaces = if_list($sock);
  print "address = ",if_addr($sock,$interfaces[0]);

=head2 Exportable constants

The ":flags" constant imports the following constants for use with the
flags returned by if_flags():

  IFF_ALLMULTI
  IFF_AUTOMEDIA
  IFF_BROADCAST
  IFF_DEBUG
  IFF_LOOPBACK
  IFF_MASTER
  IFF_MULTICAST
  IFF_NOARP
  IFF_NOTRAILERS
  IFF_POINTOPOINT
  IFF_PORTSEL
  IFF_PROMISC
  IFF_RUNNING
  IFF_SLAVE
  IFF_UP

This example determines whether interface 'tu0' supports multicasting:

  use IO::Socket;
  use IO::Interface ':flags';
  my $sock = IO::Socket::INET->new(Proto=>'udp');
  print "can multicast!\n" if $sock->if_flags & IFF_MULTICAST.

=head1 AUTHOR

Lincoln Stein E<lt>lstein@cshl.orgE<gt>

This module is distributed under the same license as Perl itself.

=head1 SEE ALSO

perl(1), IO::Socket(3), IO::Multicast(3)

=cut
