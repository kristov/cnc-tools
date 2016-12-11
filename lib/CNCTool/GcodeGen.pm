package CNCTool::GcodeGen;

use Moose;

has gcode => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
);

has work_clearance => (
    is => 'ro',
    isa => 'Num',
    default => 2,
);

sub linerefs_to_gcode {
    my ( $self, $lines, $name, $depth ) = @_;

    my @lines = @{ $lines };

    $depth ||= 1;
    $name ||= 'path of ' . scalar( @{ $lines } ) . ' lines';
    $self->comment( 'BEGIN: ' . $name );

    my $first = $lines[0];

    $self->set_absolute;
    $self->raise_above_work;
    my ( $start, $end ) = @{ $first };
    $self->move_to( $start->[0], $start->[1] );
    $self->move_down_to( 0 - $depth );

    for my $line ( @lines ) {
        my ( $start, $end ) = @{ $line };
        $self->move_to( $end->[0], $end->[1] );
    }
    $self->raise_above_work;
    $self->home;

    $self->comment( 'END: ' . $name );

    return join( "\n", @{ $self->gcode } ) . "\n";
}

sub pointlist_to_drill {
    my ( $self, $pointlist, $depth ) = @_;

    $self->set_absolute;
    $self->raise_above_work;

    for my $point ( @{ $pointlist } ) {
        $self->move_to( $point->[0], $point->[1] );
        $self->move_down_to( 0 - $depth );
        $self->raise_above_work;
    }
    $self->move_to( 0, 0 );
    $self->move_down_to( 0 );

    return join( "\n", @{ $self->gcode } ) . "\n";
}

sub set_absolute {
    my ( $self ) = @_;
    $self->_add( "G90" );
}

sub raise_above_work {
    my ( $self ) = @_;
    $self->_add( "G0 Z%0.2f", $self->work_clearance );
}

sub home {
    my ( $self ) = @_;
    $self->move_to( 0, 0 );
}

sub move_down_to {
    my ( $self, $depth ) = @_;
    $self->_add( "G0 Z%0.2f", $depth );
}

sub cut_down_to {
    my ( $self, $depth ) = @_;
    $self->_add( "G1 Z%0.2f", $depth );
}

sub move_to {
    my ( $self, $x, $y ) = @_;
    $self->_add( "G0 X%0.2f Y%0.2f", $x, $y );
}

sub comment {
    my ( $self, $comment ) = @_;
    $self->_add( "; %s", $comment );
}

sub _add {
    my ( $self, $pattern, @args ) = @_;
    my $code = @args ? sprintf( $pattern, @args ) : $pattern;
    my $gcode = $self->gcode;
    push @{ $gcode }, $code;
}


__PACKAGE__->meta->make_immutable;
