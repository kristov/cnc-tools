package CNCTool::App::PathView;

use Moose;
use GtkZ::App;
extends 'GtkZ::App::Graphical::Cairo';

has path => (
    is => 'ro',
    isa => 'ACME::Geo::Path',
    required => 1,
);

has parallel => (
    is => 'ro',
    isa => 'Bool',
    required => 0,
    default => 0,
);

has parallel_distance => (
    is => 'ro',
    isa => 'Num',
    required => 0,
    default => 1.5,
);

has xoff => (
    is => 'ro',
    isa => 'Maybe[Num]',
    required => 0,
);

has yoff => (
    is => 'ro',
    isa => 'Maybe[Num]',
    required => 0,
);

has scale => (
    is => 'ro',
    isa => 'Maybe[Num]',
    required => 0,
    default => 0,
);

has show_points => (
    is => 'ro',
    isa => 'Bool',
    required => 0,
    default => 0,
);

has flip_parallel => (
    is => 'ro',
    isa => 'Bool',
    required => 0,
    default => 0,
);

sub calculate_scale {
    my ( $self, $bbox ) = @_;

    my $minx = $bbox->minx;
    my $maxx = $bbox->maxx;
    my $miny = $bbox->miny;
    my $maxy = $bbox->maxy;

    my $width = $self->da_width - 40;
    my $height = $self->da_height - 40;

    my $dx = $maxx - $minx;
    my $dy = $maxy - $miny;

    my $scale = 1;
    if ( $dy > $dx ) {
        $scale = $height / $dy;
    }
    else {
        $scale = $width / $dx;
    }
    return $scale;
}

sub layer_renderers {
    my ( $self ) = @_;
    return [
        sub {
            my ( $self, $cr ) = @_;
            $cr->save;

            my $path = $self->path;
            my $scale = $self->scale // $self->calculate_scale( $path->bounding_box );

            my $R = 0;
            my $G = 1;

            my $bbox = $path->bounding_box;
            my $dx = $bbox->maxx - $bbox->minx;
            my $dy = $bbox->maxy - $bbox->miny;

            if ( $dx == 0 && $dy == 0 ) {
                $self->project->logger->debug( 'not rendering empty path' );
                next PATH;
            }

            my $xoff = $self->xoff // ( 0 - $bbox->minx ) * $scale;
            my $yoff = $self->yoff // ( 0 - $bbox->miny ) * $scale;

            $cr->set_line_width( 2 );
            $cr->set_source_rgb( 0, 1, 0 );
            $self->render_path( $cr, $path, $scale, $xoff, $yoff );

            if ( $self->parallel ) {
                my $parallel = $path->parallel_path( $self->parallel_distance, $self->flip_parallel );
                $cr->set_line_width( 1 );
                $cr->set_source_rgb( 0, 1, 1 );
                $self->render_path( $cr, $parallel, $scale, $xoff, $yoff );
            }

            if ( $self->show_points ) {
                $cr->set_line_width( 1 );
                $cr->set_source_rgb( 1, 0, 0 );

                for my $line ( @{ $path } ) {
                    my $xs = ( $line->start->X * $scale ) + $xoff;
                    my $ys = ( $line->start->Y * $scale ) + $yoff;
                    $cr->rectangle( $xs - 2, $ys - 2, 4, 4 );
                }
                $cr->stroke();
            }

            $cr->restore;
        },
    ];
}

sub render_path {
    my ( $self, $cr, $path, $scale, $xoff, $yoff ) = @_;

    for my $line ( @{ $path } ) {
        my $xs = ( $line->start->X * $scale ) + $xoff;
        my $ys = ( $line->start->Y * $scale ) + $yoff;
        my $xe = ( $line->end->X * $scale ) + $xoff;
        my $ye = ( $line->end->Y * $scale ) + $yoff;
        $cr->move_to( $xs, $ys );
        $cr->line_to( $xe, $ye );
    }
    $cr->stroke();
}

__PACKAGE__->meta->make_immutable;
