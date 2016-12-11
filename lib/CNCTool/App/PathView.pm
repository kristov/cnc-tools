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

has mouse_x => (
    is => 'rw',
    isa => 'Maybe[Num]',
    required => 0,
);

has mouse_y => (
    is => 'rw',
    isa => 'Maybe[Num]',
    required => 0,
);

has scale => (
    is => 'rw',
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
            my $R = 0;
            my $G = 1;

            my $bbox = $path->bounding_box;
            my $dx = $bbox->maxx - $bbox->minx;
            my $dy = $bbox->maxy - $bbox->miny;

            if ( $dx == 0 && $dy == 0 ) {
                $self->project->logger->debug( 'not rendering empty path' );
                next PATH;
            }

            $cr->set_line_width( 2 );
            $self->render_path( $cr, $path );

            if ( $self->parallel ) {
                my $parallel = $path->parallel_path( $self->parallel_distance, $self->flip_parallel );
                $cr->set_line_width( 1 );
                $self->render_path( $cr, $parallel );
            }

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
    #$cr->stroke();
}

sub handle_keypress {
    my ( $self, $da, $event ) = @_;
    if ( $event->keyval == 100 ) {
        $self->{debug_zoom} = 1;
    }
}

__PACKAGE__->meta->make_immutable;
