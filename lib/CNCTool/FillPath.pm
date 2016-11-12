package CNCTool::FillPath;

use Moose;

has path => (
    is => 'ro',
    isa => 'ACME::Geo::Path',
    required => 1,
);

has spacing => (
    is => 'ro',
    isa => 'Num',
    required => 0,
    default => 1.5,
);

sub generate_fill {
    my ( $self ) = @_;

    my $path = $self->path;
    my $bbox = $path->bounding_box;

    my $startx = $bbox->minx;
    my $endx = $bbox->maxx;

    my $starty = $bbox->miny - 10;
    my $endy = $bbox->maxy + 10;

    my $spacing = $self->spacing;

    my $x = $startx + $spacing;
    my @lines;

    while ( $x < $endx ) {
        my $line = ACME::Geo::Line->new_from_point_refs( [ $x, $starty ], [ $x, $endy ] );
        my @intersects;
        for my $path_line ( @{ $path } ) {
            my $intersect = $line->intersect( $path_line );
            push @intersects, $intersect if $intersect;
        }

        if ( scalar( @intersects ) == 2 ) {
            push @lines, ACME::Geo::Line->new( @intersects );
        }

        $x += $spacing;
    }

    my @path_lines;
    my $at_bottom = 1;
    my $lastx = $path->[-1]->end->X;
    my $lasty = $path->[-1]->end->Y;

    for my $line ( @lines ) {

        if ( $line->start->X != $line->end->X ) {
            use Data::Dumper;
            warn Dumper( $line );
        }

        my $ref_point = ACME::Geo::Point->new( $line->start->X, $starty );
        my $start_distance_bottom   = $line->start->distance( $ref_point );
        my $end_distance_bottom     = $line->end->distance( $ref_point );

        if ( $at_bottom ) {
            if ( $end_distance_bottom < $start_distance_bottom ) {
                $line->flip;
            }
            if ( $lastx && $lasty ) {
                push @path_lines, ACME::Geo::Line->new_from_point_refs( [ $lastx, $lasty ], [ $line->start->X, $line->start->Y ] ); 
            }
            $at_bottom = 0;
        }
        else {
            if ( $start_distance_bottom < $end_distance_bottom ) {
                $line->flip;
            }
            if ( $lastx && $lasty ) {
                push @path_lines, ACME::Geo::Line->new_from_point_refs( [ $lastx, $lasty ], [ $line->start->X, $line->start->Y ] ); 
            }
            $at_bottom = 1;
        }

        $lastx = $line->end->X;
        $lasty = $line->end->Y;
        push @path_lines, $line;
    }

    return ACME::Geo::Path->new( @path_lines );
}

__PACKAGE__->meta->make_immutable;
