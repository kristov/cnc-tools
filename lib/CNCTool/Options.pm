package CNCTool::Options;

use strict;
use warnings;
use Getopt::Long;

sub new {
    my ( $class, @def ) = @_;
    return bless( \@def, $class );
}

sub get_options {
    my ( $self ) = @_;

    my @def = @{ $self };

    my @opts = (
        'help',
    );

    for my $def ( @def ) {
        if ( $def->{type} eq 'bool' ) {
            push @opts, $def->{name};
        }
        else {
            push @opts, $def->{name} . '=s';
        }
    }

    my $args = {};
    GetOptions(
        $args,
        @opts,
    );

    my @required_missing;

    for my $def ( @def ) {
        push @required_missing, $def->{name}
            if $def->{req} && !defined $args->{$def->{name}};
    }

    if ( scalar( keys %{ $args } ) == 1 && $args->{help} ) {
        $self->print_help;
    }
    elsif ( @required_missing ) {
        $self->print_required_missing( @required_missing );
    }
    elsif ( $args->{help} ) {
        $self->print_help;
    }

    return $args;
}

sub print_required_missing {
    my ( $self, @required_missing ) = @_;
    print "The following options are required, but were missing:\n\n";
    print join( "\n", map { "    " . $_ } @required_missing ) . "\n\n";
    $self->print_help;
}

sub print_help {
    my ( $self ) = @_;

    my @def = @{ $self };

    my @short;
    for my $def ( @def ) {
        my $pattern = $def->{req} ? '--%s%s' : '[--%s%s]';
        my $part = sprintf( $pattern, $def->{name}, $def->{type} eq 'bool' ? '' : '=' . $def->{type} );
        push @short, $part;
    }

    my $usage = "Usage: $0 " . join( ' ', @short ) . "\n\n";
    print $usage;
}

1;
