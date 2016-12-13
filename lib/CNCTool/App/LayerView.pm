package CNCTool::App::LayerView;

use Moose;
use GtkZ::App;
extends 'GtkZ::App::Graphical::Cairo';

has layer => (
    is => 'ro',
    isa => 'ACME::Geo::Layer',
    required => 1,
);

has show_points => (
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

            my $layer = $self->layer;

            PATH: for my $path ( @{ $layer } ) {

                my $bbox = $path->bounding_box;
                my $dx = $bbox->maxx - $bbox->minx;
                my $dy = $bbox->maxy - $bbox->miny;

                if ( $dx == 0 && $dy == 0 ) {
                    next PATH;
                }

                $cr->set_line_width( 2 );
                $cr->set_source_rgb( 0, 1, 0 );

                $self->render_path( $cr, $path );

                if ( $self->show_points ) {
                    $cr->set_line_width( 1 );
                    $cr->set_source_rgb( 1, 0, 0 );

                    for my $line ( @{ $path } ) {
                        my $pop = $self->translate( [ $line->start->X, $line->start->Y ] );
                        my ( $xs, $ys ) = @{ $pop };
                        $cr->rectangle( $xs - 2, $ys - 2, 4, 4 );
                    }
                    $cr->stroke();
                }
            }

            $cr->restore;
        },
    ];
}

sub render_path {
    my ( $self, $cr, $path ) = @_;

    my $R = 1;
    my $G = 0;
    for my $line ( @{ $path } ) {
        $cr->set_source_rgb( $R, $G, 0 );
        $R = $R ? 0 : 1;
        $G = $G ? 0 : 1;
        my $stp = $self->translate( [ $line->start->X, $line->start->Y ] );
        my $enp = $self->translate( [ $line->end->X, $line->end->Y ] );
        my ( $xs, $ys ) = @{ $stp };
        my ( $xe, $ye ) = @{ $enp };
        $cr->move_to( $xs, $ys );
        $cr->line_to( $xe, $ye );
        $cr->stroke();
    }
}

__PACKAGE__->meta->make_immutable;
