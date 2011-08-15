#!/usr/bin/perl
#
# This is a script that generates OpenNMS config files from the MySQL Cacti
# Templates mysql_definitions.pl file and the cacti to mib mapping
#
# Usage:
#   perl cacti2opennms.pl mysql_definitions.pl cacti2MIB.pl
#
#
# This script is loosely based on make-templates.pl written by Baron Schwartz 
# for the MySQL Cacti Templates.
#
# Here is the original file comment
# This is a script that generates Cacti templates from a Perl data structure.
#
# This program is copyright (c) 2009 Brice Figureau. Feedback and improvements
# are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.

# notes:
# data_source_type_id = 1 = "GAUGE"
# data_source_type_id = 2 = "COUNTER"
# data_source_type_id = 3 = "DERIVE"
# data_source_type_id = 4 = "ABSOLUTE"

use Data::Dumper;
use strict;
use warnings FATAL => 'all';
use Getopt::Long qw(:config auto_help auto_version no_ignore_case);
use Pod::Usage;

our $VERSION = '1.0';

use English qw(-no_match_vars);
use List::Util qw(max);

sub VersionMessage {
    print "cacti2opennms.pl $VERSION\n";
}

sub read_hash {
    my $filename = shift;
    open my $fh, '<', $filename or die "Can't open $filename: $OS_ERROR";
    my $code = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh>; };
    close $fh;

    # This should be a hashref now.
    my $t = eval($code);
    if ( $EVAL_ERROR ) {
       die $EVAL_ERROR;
    }
    return $t;
}

my %opt = (
    graph_width => 565,
    graph_height => 200,
    output => "graph"
);

GetOptions(
    \%opt,
    "graph_height|h=i",
    "graph_width|w=i",
    "output|o=s",
    'man',
    'usage',
    "version|V" => sub {VersionMessage(); exit();},
) or pod2usage(-verbose => 0);

pod2usage(-verbose => 0) if $opt{usage};
pod2usage(-verbose => 1) if $opt{help};
pod2usage(-verbose => 2) if $opt{man};

if (scalar(@ARGV) != 2) {
    print "Missing cacti templates definitions file and/or cacti to mib mapping file\n";
    pod2usage(-verbose => 0);
}

# read mysql template
my $t = read_hash(shift @ARGV);

# now read the cacti to MIB translation hash
my $cacti2MIB = read_hash(shift @ARGV);

my @mibKeysInOrder = map { $cacti2MIB->{short_names}->{$_}->{mib} } ( sort { $cacti2MIB->{short_names}->{$a}->{order} <=> $cacti2MIB->{short_names}->{$b}->{order} } keys %{ $cacti2MIB->{short_names} });
my %mibTypes = ();
my %mib2Cacti = ();

foreach my $cactiKey (keys %{ $cacti2MIB->{short_names} }) {
    my $mib = $cacti2MIB->{short_names}->{$cactiKey}->{mib};
    my $type = $cacti2MIB->{short_names}->{$cactiKey}->{type};

    $mibTypes{$mib} = $type;
    $mib2Cacti{$mib} = $cactiKey;
}

# Turn A_string_of_words into A String Of Words.
sub to_words {
   my ( $text ) = @_;
   return join(' ', map { ucfirst } split(/_/, $text));
}

# Removes vowels and compacts repeated letters to shorten text.  In this case,
# to 19 characters, which is RRDTool's internal limit.  This lets the data
# source (script) output long variable names, which can then be used as nice
# descriptive labels, while translating them into crunched text when needed for
# an RRA.
sub crunch {
   my $text = shift;
   my $cdef = shift;
   my $len = $cdef ? 18 : 19;

   return $text if $len && length($text) <= $len;
   $text = reverse $text; # work from the end backwards
   1 while ( length($text) > $len && $text =~ s/(?<![_ ])[aeiou]// );
   1 while ( length($text) > $len && $text =~ s/(.)\1+/$1/ );
   $text = reverse $text;
   die "Can't shorten $text enough" if length($text) > $len;
   return $text;
}

sub condense {
    my ( $text ) = @_;
    $text =~ s/ //g;
    $text =~ s/[^a-zA-Z0-9]//g;
    return lc($text);
}

sub emit_report {
    my $g = shift;
    my $rname = shift;
    my $list = shift;

   print <<END;
report.mysql.${rname}.name=$g->{name}
report.mysql.${rname}.columns=$list
report.mysql.${rname}.type=nodeSnmp
report.mysql.${rname}.width=$opt{graph_width}
report.mysql.${rname}.height=$opt{graph_height}
report.mysql.${rname}.command=--title "$g->{title}" \\
 --width $opt{graph_width} \\
 --height $opt{graph_height} \\
END
}

sub emit_defs {
    my $g = shift;
    my $names = shift;

    my $index = 0;
    foreach my $it ( @{ $g->{items} } ) {
        my $rrName = crunch($cacti2MIB->{short_names}->{$it->{item}}->{mib});
        my $varName = crunch($cacti2MIB->{short_names}->{$it->{item}}->{mib});
        $index=$index+1;
        print <<END;
 DEF:$rrName={rrd$index}:$varName:AVERAGE \\
END
    }
}

sub emit_rrd {
    my $name = shift;
    my $type = shift;
    my $color = shift;
    my $text = shift;
    print <<END;
 $type:$name#$color:"$text" \\
END
}

sub emit_cdef {
    my $name = shift;

    print <<END;
 CDEF:${name}c=${name},-1,* \\
END
    return "${name}c";
}

sub emit_gprint {
    my $name = shift;

    print <<END;
 GPRINT:${name}:AVERAGE:"Avg \\\\: %8.2lf %s" \\
 GPRINT:${name}:MIN:"Min \\\\: %8.2lf %s" \\
 GPRINT:${name}:MAX:"Max \\\\: %8.2lf %s\\\\n" \\
END
}

sub emit_last_gprint {
    my $name = shift;

    print <<END;
 GPRINT:${name}:AVERAGE:"Avg \\\\: %8.2lf %s" \\
 GPRINT:${name}:MIN:"Min \\\\: %8.2lf %s" \\
 GPRINT:${name}:MAX:"Max \\\\: %8.2lf %s\\\\n"
END
}

sub emit_datacollection {
    print <<END;
    <!-- MySQL-SERVER MIB -->
        <group name="mysql" ifType="ignore">
END
    my $i = 0;
    foreach my $mib ( @mibKeysInOrder )
    {
        $i++;
        my $name = crunch($mib);
        my $oid = $cacti2MIB->{startoid}.".$i";
        my $type = $mibTypes{$mib};
        print <<END;
            <mibObj oid="$oid" instance="0" alias="$name" type="$type" />
END
    }
    print <<END;
        </group>
END
}

sub emit_report_list {
    my %reports = ();
LOOP:
    foreach my $g ( @{ $t->{graphs} } ) {
        # skip graphs we don't (yet) support
        my $it;
        foreach $it ( @{ $g->{items} } ) {
            unless(defined($cacti2MIB->{short_names}->{$it->{item}})) {
                next LOOP;
            }
            my $rname = condense($g->{name});
            $reports{$rname} = '';
        }
    }
    print join(', ', map { "mysql.".$_ } keys %reports) . " \\\n";
    print "\n\n";
}

sub emit_graphs {
LOOP:
    foreach my $g ( @{ $t->{graphs} } ) {
        # skip graphs we don't (yet) support
        my $it;
        foreach $it ( @{ $g->{items} } ) {
            unless(defined($cacti2MIB->{short_names}->{$it->{item}})) {
                next LOOP;
            }
        }

        # Set the graph's title
        my $name = $g->{name};
        my $rname = condense($g->{name});
        my @res = ();
        $g->{title} = "$g->{name}";

        foreach $it ( @{ $g->{items} } ) {
            push(@res, crunch($cacti2MIB->{short_names}->{$it->{item}}->{mib}));
        }

        emit_report($g, $rname, join(',', @res));
        emit_defs($g);

        my $max = 0;
        foreach $it ( @{ $g->{items} } ) {
            my $text = to_words($it->{item});
            $max = length($text) if (length($text) > $max);
        }

        my $index = 0;
        foreach $it ( @{ $g->{items} } ) {
            unless(defined($cacti2MIB->{short_names}->{$it->{item}})) {
                next;
            }
            my $rrName = crunch($cacti2MIB->{short_names}->{$it->{item}}->{mib}, defined($it->{cdef}));
            my $type = $it->{type} || 'LINE1';
            my $t = to_words($it->{item});
            my $text = $t . (' ' x ($max - length($t)));

            my $rrNamec = defined($it->{cdef}) ? emit_cdef($rrName) : $rrName;
            emit_rrd($rrNamec, $type, $it->{color}, $text);
            if ($index++ < scalar @{ $g->{items}} -1) {
                emit_gprint($rrName);
            } else {
                emit_last_gprint($rrName);
            }
        }
        print "\n\n";
    }
}

sub array_print {
    my $columns = shift;
    my @array = @_;
    my $length = scalar @array;

    my $k = 0;
    while($length > 0) {
        my $str = '';
        my $rest = ($length <= $columns ? $length : $columns);
        for(my $i = 0; $i < $rest; $i++) {
            $str .= "'$array[$k + $i]', ";
        }
        $str .= " # ". ($k+1)." - ". ($k+$rest) ."\n";
        print ' ' x 4 . $str;
        $k += $rest;
        $length -= $rest;
    }
}

my %snmpTypes = (
    'Gauge32' => 'Gauge32',
    'Counter32' => 'Counter32',
    'Counter64' => 'Counter64',
    'Gauge64' => 'Counter64', # there is no gauge64 in SNMP
);

sub emit_agent {
    print "my \@types = (\n";
    array_print(4, map { $snmpTypes{$mibTypes{$_}} } @mibKeysInOrder);
    print ");\n\n";

    print "my \@newkeys = (\n";
    array_print(2, @mibKeysInOrder);
    print ");\n\n";

    print "my \@oldkeys = (\n";
    array_print(2, map { $mib2Cacti{$_} } @mibKeysInOrder);
    print ");\n\n";
}

# Do the work.
# #############################################################################

# Graph templates
if ($opt{output} eq "graph") {
    emit_graphs();
}
elsif ($opt{output} eq "graphlist") {
    emit_report_list();
}
elsif ($opt{output} eq "datacollection") {
    emit_datacollection();
}
elsif ($opt{output} eq "agent") {
    emit_agent();
}
else {
    print "Unknown output format\n";
    pod2usage(-verbose => 0);
}


__END__

=head1 NAME

    cacti2opennsm - create opennms configuration from MySQL Cacti Templates 

=head1 SYNOPSIS

    cacti2opennms [options] mysql_definitions.pl cacti2mib.pl

    -w, --graph_width WIDTH          width of graph in pixel
    -h, --graph_height HEIGHT        height of graph in pixel
    -o format                        which configuration to output
    -?, --help                       display this help and exit
    --usage                          display detailed usage information
    --man                            display program man page
    -V, --version                    output version information and exit

=head1 OPTIONS

=over 8

=item B<-w WIDTH,--graph_width WIDTH>

Graphs will be output with WIDTH pixels. Default value 565 pixels.

=item B<-h HEIGHT,--graph_height HEIGHT>

Graphs will be output with HEIGHT pixels. Default value 200 pixels.

=item B<-o format,--output format>

What kind of opennms configuration file to output.
Possible choices are:
  * graph: outputs the content of the snmp-graph.properties
  * graphlist: outputs the content of the snmp-graph.properties reports key
  * datacollection: outputs the content of the datacollections-config.xml file
  * agent: outputs the needed array for mysql-snmp

=item B<--man>

Prints the manual page and exits.

=item B<--usage>

Prints detailed usage information and exits.

=item B<-?, --help>

Print a brief help message and exits.

=item B<-V, --version>

output version information and exit

=back

=head1 DESCRIPTION

B<mysql-snmp> is a small daemon that connects to a local snmpd daemon
to report statistics on a local or remote MySQL server.

=cut
